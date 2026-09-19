import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyEvent } from '@ohos.multimodalInput.keyEvent';
import { MusicItem, LyricLine, MediaSource, LyricSource } from '../common/Types';
import { RepeatMode, STORE_KEYS, LOCAL_PLATFORM } from '../common/Constants';
import { LyricParser } from './LyricParser';
import { LyricExtra } from './LyricExtra';
import { CoverService } from './CoverService';
import { PluginManager } from './PluginManager';
import { showToast } from './HttpUtil';
import { FloatingLyric } from './FloatingLyric';
import { ScheduleClose } from './ScheduleClose';
import { AppConfig, KEYS } from './AppConfig';
import { I18n } from './I18n';

export class TrackPlayer {
  current: MusicItem | null = null;
  playList: MusicItem[] = [];
  currentIndex: number = -1;
  isPlaying: boolean = false;
  position: number = 0;
  duration: number = 0;
  repeatMode: RepeatMode = RepeatMode.QUEUE;
  quality: string = 'standard';
  rate: number = 100;
  lyrics: LyricLine[] = [];
  lyricIndex: number = -1;
  hasTranslation: boolean = false;
  lyricLoading: boolean = false;
  listeners: Array<() => void> = [];

  private player: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private context: common.UIAbilityContext | null = null;
  private plugins: PluginManager | null = null;
  private historyCb: ((item: MusicItem) => void) | null = null;
  favoriteChecker: (item: MusicItem) => boolean = (_item: MusicItem) => {
    return false;
  };
  favoriteToggler: (item: MusicItem) => void = (_item: MusicItem) => {
  };
  artworkSaver: (item: MusicItem) => void = (_item: MusicItem) => {
  };
  private bgStarted: boolean = false;
  private sessionLaunchSet: boolean = false;
  private playToken: number = 0;
  private lyricToken: number = 0;
  private lyricTriedKey: string = '';
  private lyricLoadAt: number = 0;
  private qualityToken: number = 0;
  private preparing: boolean = false;
  private pendingSeek: number = 0;
  private localFile: fs.File | null = null;
  private lastSessionSync: number = 0;
  private sessionSyncing: boolean = false;
  private sessionSyncQueued: boolean = false;
  resolveLocalUrl: (item: MusicItem, url: string) => string = (_item: MusicItem, url: string) => url;

  onChange(cb: () => void): void {
    this.listeners.push(cb);
  }

  setHistoryHandler(cb: (item: MusicItem) => void): void {
    this.historyCb = cb;
  }

  private emitLyric(): void {
    const tick = AppStorage.get<number>('lyricTick');
    const n: number = tick !== undefined && tick !== null ? tick : 0;
    AppStorage.setOrCreate('lyricTick', n + 1);
    AppStorage.setOrCreate('lyricLoading', this.lyricLoading);
    this.emit();
  }

  async ensureLyric(): Promise<void> {
    if (this.current === null || this.plugins === null) {
      this.emitLyric();
      return;
    }
    if (this.lyrics.length > 0) {
      this.emitLyric();
      return;
    }
    if (this.lyricLoading && Date.now() - this.lyricLoadAt < 18000) {
      this.emitLyric();
      return;
    }
    this.lyricTriedKey = '';
    this.lyricToken += 1;
    await this.loadLyric(this.current, this.lyricToken);
  }

  private emit(): void {
    AppStorage.setOrCreate(STORE_KEYS.hasMusic, this.current !== null);
    AppStorage.setOrCreate(STORE_KEYS.isPlaying, this.isPlaying);
    AppStorage.setOrCreate(STORE_KEYS.position, this.position);
    AppStorage.setOrCreate(STORE_KEYS.duration, this.duration);
    AppStorage.setOrCreate(STORE_KEYS.currentTitle, this.current !== null ? this.current.title : '');
    AppStorage.setOrCreate(STORE_KEYS.currentArtist, this.current !== null ? this.current.artist : '');
    AppStorage.setOrCreate(STORE_KEYS.currentArtwork, this.current !== null ? this.current.artwork : '');
    AppStorage.setOrCreate(STORE_KEYS.currentAlbum, this.current !== null ? this.current.album : '');
    const line = this.currentLyricLine();
    AppStorage.setOrCreate(STORE_KEYS.lyricLine, line);
    AppStorage.setOrCreate(STORE_KEYS.playQuality, this.quality);
    AppStorage.setOrCreate(STORE_KEYS.playRate, this.rate);
    AppStorage.setOrCreate('hasTranslation', this.hasTranslation);
    FloatingLyric.update(line);
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  async init(context: common.UIAbilityContext, plugins: PluginManager): Promise<void> {
    this.context = context;
    this.plugins = plugins;
    this.player = await media.createAVPlayer();
    this.bindPlayer();
    try {
      this.session = await avSession.createAVSession(context, 'MusicFree', 'audio');
      this.bindSession();
      await this.ensureLaunchAbility();
      await this.session.activate();
      await this.applyMediaCenterControls();
      await this.startBackground();
    } catch (e) {
      hilog.error(0x0000, 'MusicFreeSession', 'init fail %{public}s', `${e}`);
    }
  }

  private bindPlayer(): void {
    if (this.player === null) {
      return;
    }
    this.player.on('stateChange', (state: string) => {
      if (state === 'initialized') {
        this.applyAudioUsage();
        this.safePrepare();
      } else if (state === 'prepared') {
        this.preparing = false;
        if (this.pendingSeek > 0) {
          this.seekTo(this.pendingSeek);
          this.pendingSeek = 0;
        }
        this.applyRate();
        try {
          this.player?.play();
        } catch (_e) {
        }
        this.syncSessionState();
      } else if (state === 'playing') {
        this.preparing = false;
        this.isPlaying = true;
        this.emit();
        this.startBackground();
        this.syncSessionState();
      } else if (state === 'paused') {
        this.isPlaying = false;
        this.emit();
        this.syncSessionState();
      } else if (state === 'completed') {
        this.syncSessionState();
        this.onCompleted();
      } else if (state === 'error' || state === 'idle' || state === 'released') {
        this.preparing = false;
        if (state === 'error') {
          this.isPlaying = false;
          this.emit();
          this.syncSessionState();
          showToast(I18n.t('toast.playFail'));
          this.onPlayFail();
        }
      }
    });
    this.player.on('timeUpdate', (time: number) => {
      this.position = time / 1000;
      const nextIdx = LyricParser.findIndex(this.lyrics, this.position);
      if (nextIdx !== this.lyricIndex) {
        this.lyricIndex = nextIdx;
      }
      this.emit();
      this.maybeSyncSession();
    });
    this.player.on('audioInterrupt', (info: audio.InterruptEvent) => {
      this.onAudioInterrupt(info);
    });
    this.player.on('durationUpdate', (d: number) => {
      this.duration = d / 1000;
      this.emit();
      this.updateSession();
    });
  }

  private applyAudioUsage(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      this.player.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
    } catch (_e) {
    }
  }

  private onAudioInterrupt(info: audio.InterruptEvent): void {
    if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
      info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
      this.isPlaying = false;
      this.emit();
      this.syncSessionState();
      return;
    }
    if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
      this.play();
    }
  }

  private bindSession(): void {
    if (this.session === null) {
      return;
    }
    this.session.on('play', () => {
      this.play();
    });
    this.session.on('pause', () => {
      this.pause();
    });
    this.session.on('stop', () => {
      this.pause();
    });
    this.session.on('playNext', () => {
      this.skipToNext();
    });
    this.session.on('playPrevious', () => {
      this.skipToPrevious();
    });
    this.session.on('seek', (timeMs: number) => {
      this.seekTo(timeMs / 1000);
    });
    this.session.on('setSpeed', (speed: number) => {
      const next = Math.round(speed * 100);
      this.setRate(next > 0 ? next : 100);
    });
    this.session.on('setLoopMode', (mode: avSession.LoopMode) => {
      this.applyLoopMode(mode);
    });
    this.session.on('setTargetLoopMode', (mode: avSession.LoopMode) => {
      this.applyLoopMode(mode);
    });
    this.session.on('toggleFavorite', (_assetId: string) => {
      if (this.current !== null) {
        this.favoriteToggler(this.current);
        this.updateSession();
      }
    });
    this.session.on('handleKeyEvent', (event: KeyEvent) => {
      this.onSessionKey(event.action, event.key.code);
    });
  }

  private onSessionKey(action: number, code: number): void {
    if (action !== 1) {
      return;
    }
    if (code === 10 || code === 2630) {
      this.toggle();
      return;
    }
    if (code === 2085) {
      this.play();
      return;
    }
    if (code === 2086 || code === 11) {
      this.pause();
      return;
    }
    if (code === 12) {
      this.skipToNext();
      return;
    }
    if (code === 13) {
      this.skipToPrevious();
    }
  }

  async playMusic(item: MusicItem, list?: MusicItem[]): Promise<void> {
    if (list !== undefined && list.length > 0) {
      this.playList = list.slice();
    } else if (this.playList.length === 0) {
      this.playList = [item];
    }
    this.currentIndex = this.indexOf(item);
    if (this.currentIndex < 0) {
      this.playList.push(item);
      this.currentIndex = this.playList.length - 1;
    }
    await this.startCurrent();
  }

  playListAt(index: number): void {
    if (index < 0 || index >= this.playList.length) {
      return;
    }
    this.currentIndex = index;
    this.startCurrent();
  }

  private async startCurrent(): Promise<void> {
    if (this.currentIndex < 0 || this.currentIndex >= this.playList.length) {
      return;
    }
    const item = this.playList[this.currentIndex];
    this.current = item;
    this.lyrics = [];
    this.lyricIndex = -1;
    this.hasTranslation = false;
    this.lyricLoading = true;
    this.lyricLoadAt = Date.now();
    this.lyricTriedKey = '';
    this.position = 0;
    this.preparing = true;
    this.emitLyric();
    this.startBackground();
    this.updateSession();
    if (this.historyCb) {
      try {
        this.historyCb(item);
      } catch (_e) {
      }
    }
    this.playToken += 1;
    this.lyricToken += 1;
    const token = this.playToken;
    const lyricTok = this.lyricToken;
    showToast(I18n.t('downloading.downloadStatus.preparing'));
    this.loadLyric(item, lyricTok).catch((_e: Error) => {
    });
    this.ensureArtwork(item, token).catch((_e: Error) => {
    });
    setTimeout((): void => {
      this.fetchAndPlay(item, token).catch((_e: Error) => {
      });
    }, 0);
  }

  private async ensureArtwork(item: MusicItem, token: number): Promise<void> {
    const art = await CoverService.ensure(item, this.plugins);
    if (token !== this.playToken || this.current === null || !this.current.sameAs(item)) {
      return;
    }
    if (item.title.length > 0) {
      this.current.title = item.title;
    }
    if (item.artist.length > 0) {
      this.current.artist = item.artist;
    }
    if (item.album.length > 0) {
      this.current.album = item.album;
    }
    if (art.length > 0) {
      this.current.artwork = art;
      item.artwork = art;
    }
    if (this.currentIndex >= 0 && this.currentIndex < this.playList.length) {
      this.playList[this.currentIndex].title = this.current.title;
      this.playList[this.currentIndex].artist = this.current.artist;
      this.playList[this.currentIndex].album = this.current.album;
      this.playList[this.currentIndex].artwork = this.current.artwork;
    }
    this.emit();
    this.updateSession();
    this.artworkSaver(this.current);
  }

  private async fetchAndPlay(item: MusicItem, token: number): Promise<void> {
    this.preparing = true;
    this.syncSessionState();
    if (this.player !== null) {
      try {
        await this.player.reset();
      } catch (_e) {
      }
    }
    try {
      let source = new MediaSource();
      if (this.plugins !== null) {
        source = await this.plugins.getMediaSource(item, this.quality);
      } else {
        source.url = item.url;
      }
      if (token !== this.playToken) {
        return;
      }
      await this.playWithSource(item, source, token);
    } catch (_e) {
      if (token === this.playToken) {
        if (item.platform === LOCAL_PLATFORM) {
          showToast(I18n.t('toast.localFileGone'));
        } else {
          showToast(I18n.t('toast.fetchSourceFail'));
        }
        this.onPlayFail();
      }
    }
  }

  private normalizePlayUrl(url: string): string {
    const text = url.trim();
    if (text.indexOf('//') === 0) {
      return `https:${text}`;
    }
    return text;
  }

  private safePrepare(): void {
    if (this.player === null || this.preparing) {
      return;
    }
    this.preparing = true;
    try {
      const job = this.player.prepare();
      if (job !== undefined && job !== null) {
        job.catch((_e: Error) => {
          this.preparing = false;
        });
      }
    } catch (_e) {
      this.preparing = false;
    }
  }

  private async setSource(source: MediaSource): Promise<void> {
    if (this.player === null) {
      return;
    }
    this.preparing = false;
    try {
      await this.player.reset();
    } catch (_e) {
    }
    const url = source.url;
    if (url.length === 0 || (url.indexOf('http://') !== 0 && url.indexOf('https://') !== 0)) {
      throw new Error('invalid url');
    }
    const headers = this.playHeaders(source);
    try {
      if (Object.keys(headers).length > 0) {
        const mediaSource = media.createMediaSourceWithUrl(url, headers);
        this.player.setMediaSource(mediaSource, { preferredBufferDuration: 2 });
      } else {
        this.player.url = url;
      }
    } catch (_e) {
      this.player.url = url;
    }
  }

  private playHeaders(source: MediaSource): Record<string, string> {
    const headers: Record<string, string> = {};
    const keys = Object.keys(source.headers);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i].trim();
      const value = `${source.headers[keys[i]]}`.trim();
      if (key.length === 0 || value.length === 0) {
        continue;
      }
      headers[key] = value;
    }
    if (source.userAgent.length > 0) {
      headers['User-Agent'] = source.userAgent;
    }
    return headers;
  }

  private closeLocalFile(): void {
    if (this.localFile !== null) {
      try {
        fs.closeSync(this.localFile);
      } catch (_e) {
      }
      this.localFile = null;
    }
  }

  private async setLocalSource(uri: string): Promise<void> {
    if (this.player === null) {
      return;
    }
    this.preparing = false;
    try {
      await this.player.reset();
    } catch (_e) {
    }
    this.closeLocalFile();
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      this.localFile = file;
      this.player.fdSrc = { fd: file.fd };
    } catch (_e) {
      throw new Error('local open fail');
    }
  }

  private currentLyricLine(): string {
    if (this.lyrics.length === 0) {
      return I18n.t('lyric.noLyric');
    }
    let idx = this.lyricIndex;
    if (idx < 0) {
      idx = 0;
    }
    if (idx >= this.lyrics.length) {
      idx = this.lyrics.length - 1;
    }
    const line = this.lyrics[idx];
    if (LyricExtra.isShowTranslation() && line.translation.length > 0) {
      return `${line.text}\n${line.translation}`;
    }
    return line.text.length > 0 ? line.text : I18n.t('lyric.noLyric');
  }

  private async loadLyric(item: MusicItem, token: number): Promise<void> {
    if (this.plugins === null) {
      if (token === this.lyricToken) {
        this.lyricLoading = false;
        this.lyricTriedKey = item.key();
        this.emitLyric();
      }
      return;
    }
    this.lyricLoading = true;
    this.lyricLoadAt = Date.now();
    this.emitLyric();
    try {
      let source = new LyricSource();
      const associated = LyricExtra.getAssociated(item);
      if (associated !== null) {
        source = await this.plugins.getLyric(associated);
      } else {
        source = await this.plugins.getLyric(item);
      }
      if (token !== this.lyricToken) {
        return;
      }
      if (source.rawLrc.length === 0 && AppConfig.getBool(KEYS.AUTO_SEARCH_LYRIC, true)) {
        const found = await this.autoSearchLyric(item, token);
        if (token !== this.lyricToken) {
          return;
        }
        if (found !== null) {
          source = found;
        }
      }
      const offset = LyricExtra.getOffset(item);
      this.lyrics = LyricParser.parseWithTranslation(source.rawLrc, source.translation, offset);
      this.hasTranslation = source.translation.length > 0;
      if (!this.hasTranslation) {
        for (let i = 0; i < this.lyrics.length; i++) {
          if (this.lyrics[i].translation.length > 0) {
            this.hasTranslation = true;
            break;
          }
        }
      }
      this.lyricIndex = LyricParser.findIndex(this.lyrics, this.position);
    } catch (_e) {
      if (token === this.lyricToken) {
        this.lyrics = [];
        this.lyricIndex = -1;
        this.hasTranslation = false;
      }
    } finally {
      if (token === this.lyricToken) {
        this.lyricLoading = false;
        this.lyricTriedKey = item.key();
        this.emitLyric();
      }
    }
  }

  async reloadLyric(): Promise<void> {
    if (this.current === null || this.plugins === null) {
      this.lyrics = [];
      this.lyricIndex = -1;
      this.hasTranslation = false;
      this.lyricLoading = false;
      this.emitLyric();
      return;
    }
    this.lyricTriedKey = '';
    this.lyricToken += 1;
    await this.loadLyric(this.current, this.lyricToken);
  }

  refreshUi(): void {
    this.emit();
  }

  play(): void {
    if (this.current === null) {
      return;
    }
    this.startBackground();
    const p = this.player;
    if (p === null) {
      this.startCurrent();
      return;
    }
    const st: string = `${p.state}`;
    if (st === 'playing') {
      this.preparing = false;
      this.isPlaying = true;
      this.emit();
      this.syncSessionState();
      return;
    }
    this.isPlaying = true;
    this.emit();
    this.syncSessionState();
    if (st === 'paused' || st === 'prepared' || st === 'completed') {
      try {
        p.play();
      } catch (_e) {
        this.startCurrent();
      }
      return;
    }
    this.startCurrent();
  }

  pause(): void {
    this.isPlaying = false;
    this.preparing = false;
    this.emit();
    this.syncSessionState();
    try {
      this.player?.pause();
    } catch (_e) {
    }
  }

  toggle(): void {
    if (this.isPlaying) {
      this.pause();
    } else {
      this.play();
    }
  }

  seekTo(seconds: number): void {
    this.position = seconds;
    if (this.player !== null) {
      this.player.seek(Math.floor(seconds * 1000));
    }
    this.syncSessionState();
  }

  setRate(rate: number): void {
    this.rate = rate;
    this.applyRate();
    this.emit();
    this.syncSessionState();
  }

  changeQuality(quality: string): void {
    const prev = this.quality;
    this.quality = quality;
    this.emit();
    if (this.current === null || this.plugins === null) {
      return;
    }
    const item = this.current;
    if (item.platform === LOCAL_PLATFORM) {
      return;
    }
    this.qualityToken += 1;
    const qTok = this.qualityToken;
    const seekAt = this.position;
    this.plugins.getMediaSource(item, quality, false).then((source: MediaSource) => {
      if (qTok !== this.qualityToken || this.current === null || !this.current.sameAs(item)) {
        return;
      }
      if (!source.url || source.url.length === 0) {
        this.quality = prev;
        this.emit();
        showToast(I18n.t('toast.currentQualityNotAvailableForCurrentMusic'));
        return;
      }
      this.pendingSeek = seekAt;
      this.playToken += 1;
      const token = this.playToken;
      this.playWithSource(item, source, token).catch((_e: Error) => {
        if (qTok === this.qualityToken) {
          this.quality = prev;
          this.emit();
          showToast(I18n.t('toast.currentQualityNotAvailableForCurrentMusic'));
        }
      });
    }).catch((_e: Error) => {
      if (qTok === this.qualityToken) {
        this.quality = prev;
        this.emit();
        showToast(I18n.t('toast.currentQualityNotAvailableForCurrentMusic'));
      }
    });
  }

  private async playWithSource(item: MusicItem, source: MediaSource, token: number): Promise<void> {
    if (token !== this.playToken) {
      return;
    }
    if (!source.url || source.url.length === 0) {
      showToast(I18n.t('toast.noMediaSource'));
      this.onPlayFail();
      return;
    }
    source.url = this.normalizePlayUrl(source.url);
    if (item.platform === LOCAL_PLATFORM || source.url.indexOf('http') !== 0) {
      source.url = this.resolveLocalUrl(item, source.url);
      if (!source.url || source.url.length === 0) {
        showToast(I18n.t('toast.localFileGone'));
        this.onPlayFail();
        return;
      }
      await this.setLocalSource(source.url);
    } else {
      await this.setSource(source);
    }
    if (token === this.playToken) {
      this.updateSession();
    }
  }

  private applyRate(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.setSpeed(this.playbackSpeed());
    } catch (_e) {
    }
  }

  private playbackSpeed(): media.PlaybackSpeed {
    if (this.rate <= 60) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    }
    if (this.rate <= 90) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    }
    if (this.rate <= 110) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    }
    if (this.rate <= 140) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    }
    if (this.rate <= 180) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    }
    return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
  }

  private onPlayFail(): void {
    if (AppConfig.getBool(KEYS.AUTO_STOP_ERROR, false)) {
      this.pause();
      return;
    }
    if (this.repeatMode === RepeatMode.SINGLE) {
      return;
    }
    if (!AppConfig.getBool(KEYS.TRY_CHANGE_SOURCE, false)) {
      return;
    }
    const token = this.playToken;
    setTimeout((): void => {
      if (token === this.playToken) {
        this.skipToNext();
      }
    }, 400);
  }

  private lyricSongName(item: MusicItem): string {
    const title = item.title.trim();
    const dash = title.indexOf('-');
    if (dash > 0 && dash < title.length - 1) {
      return title.substring(dash + 1).trim();
    }
    return title;
  }

  private lyricSearchQuery(item: MusicItem): string {
    const song = this.lyricSongName(item);
    const title = item.title.trim();
    if (song !== title) {
      const artist = title.substring(0, title.indexOf('-')).trim();
      if (artist.length > 0) {
        return `${song} ${artist}`;
      }
    }
    if (item.artist.length > 0 && item.artist !== I18n.t('common.local')) {
      return `${title} ${item.artist}`;
    }
    return song;
  }

  private lyricMatchScore(item: MusicItem, cand: MusicItem): number {
    const song = this.lyricSongName(item).toLowerCase();
    const title = cand.title.toLowerCase();
    const artist = cand.artist.toLowerCase();
    const raw = item.title.toLowerCase();
    let score = 0;
    if (title === song) {
      score += 30;
    } else if (title.indexOf(song) >= 0 || song.indexOf(title) >= 0) {
      score += 16;
    }
    if (raw.indexOf(artist) >= 0 && artist.length > 0) {
      score += 12;
    }
    if (item.artist.length > 0 && item.artist !== I18n.t('common.local') &&
      artist.indexOf(item.artist.toLowerCase()) >= 0) {
      score += 12;
    }
    return score;
  }

  private async autoSearchLyric(item: MusicItem, token: number): Promise<LyricSource | null> {
    if (this.plugins === null) {
      return null;
    }
    const query = this.lyricSearchQuery(item);
    const results = await this.plugins.searchLyric(query, 1);
    if (results.length === 0) {
      return null;
    }
    const ranked: MusicItem[] = results.slice();
    ranked.sort((a: MusicItem, b: MusicItem) => this.lyricMatchScore(item, b) - this.lyricMatchScore(item, a));
    const limit = ranked.length < 3 ? ranked.length : 3;
    for (let i = 0; i < limit; i++) {
      if (token !== this.lyricToken) {
        return null;
      }
      if (ranked[i].sameAs(item)) {
        continue;
      }
      const src = await this.plugins.getLyric(ranked[i]);
      if (src.rawLrc.length > 0) {
        LyricExtra.setAssociated(item, ranked[i]);
        return src;
      }
    }
    return null;
  }

  skipToNext(): void {
    if (this.playList.length === 0) {
      return;
    }
    if (this.repeatMode === RepeatMode.SHUFFLE) {
      this.currentIndex = Math.floor(Math.random() * this.playList.length);
    } else {
      this.currentIndex = (this.currentIndex + 1) % this.playList.length;
    }
    this.startCurrent();
  }

  skipToPrevious(): void {
    if (this.playList.length === 0) {
      return;
    }
    this.currentIndex = (this.currentIndex - 1 + this.playList.length) % this.playList.length;
    this.startCurrent();
  }

  toggleRepeatMode(): void {
    this.repeatMode = (this.repeatMode + 1) % 3 as RepeatMode;
    this.emit();
    this.syncSessionState();
  }

  addNext(item: MusicItem): void {
    const idx = this.indexOf(item);
    if (idx >= 0) {
      this.playList.splice(idx, 1);
      if (idx <= this.currentIndex && this.currentIndex > 0) {
        this.currentIndex -= 1;
      }
    }
    this.playList.splice(this.currentIndex + 1, 0, item);
    this.emit();
    showToast(I18n.t('toast.addToNextPlay'));
  }

  removeAt(index: number): void {
    if (index < 0 || index >= this.playList.length) {
      return;
    }
    this.playList.splice(index, 1);
    if (index < this.currentIndex) {
      this.currentIndex -= 1;
    } else if (index === this.currentIndex) {
      if (this.playList.length === 0) {
        this.reset();
        return;
      }
      this.currentIndex = Math.min(index, this.playList.length - 1);
      this.startCurrent();
      return;
    }
    this.emit();
  }

  clearPlayList(): void {
    this.reset();
  }

  async reset(): Promise<void> {
    this.current = null;
    this.playList = [];
    this.currentIndex = -1;
    this.isPlaying = false;
    this.position = 0;
    this.duration = 0;
    this.lyrics = [];
    this.lyricIndex = -1;
    this.hasTranslation = false;
    this.lyricLoading = false;
    this.lyricTriedKey = '';
    this.lyricToken += 1;
    this.preparing = false;
    try {
      await this.player?.reset();
    } catch (_e) {
    }
    this.emitLyric();
    this.syncSessionState();
  }

  private onCompleted(): void {
    if (ScheduleClose.onPlayEnded()) {
      return;
    }
    if (this.repeatMode === RepeatMode.SINGLE) {
      this.seekTo(0);
      this.play();
      return;
    }
    this.skipToNext();
  }

  private indexOf(item: MusicItem): number {
    for (let i = 0; i < this.playList.length; i++) {
      if (this.playList[i].sameAs(item)) {
        return i;
      }
    }
    return -1;
  }

  private neighbor(offset: number): MusicItem | null {
    if (this.playList.length < 2 || this.currentIndex < 0) {
      return null;
    }
    const idx = (this.currentIndex + offset + this.playList.length) % this.playList.length;
    return this.playList[idx];
  }

  private loopModeOf(): avSession.LoopMode {
    if (this.repeatMode === RepeatMode.SINGLE) {
      return avSession.LoopMode.LOOP_MODE_SINGLE;
    }
    if (this.repeatMode === RepeatMode.SHUFFLE) {
      return avSession.LoopMode.LOOP_MODE_SHUFFLE;
    }
    return avSession.LoopMode.LOOP_MODE_LIST;
  }

  private applyLoopMode(mode: avSession.LoopMode): void {
    if (mode === avSession.LoopMode.LOOP_MODE_SINGLE) {
      this.repeatMode = RepeatMode.SINGLE;
    } else if (mode === avSession.LoopMode.LOOP_MODE_SHUFFLE) {
      this.repeatMode = RepeatMode.SHUFFLE;
    } else {
      this.repeatMode = RepeatMode.QUEUE;
    }
    this.emit();
    this.syncSessionState();
  }

  private sessionPlaybackState(): avSession.PlaybackState {
    if (this.current === null) {
      return avSession.PlaybackState.PLAYBACK_STATE_IDLE;
    }
    if (this.isPlaying) {
      return avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    }
    return avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
  }

  refreshSession(): void {
    this.startBackground();
    this.updateSession();
    if (this.session !== null) {
      this.session.activate().catch((_e: Error) => {
      });
    }
  }

  private maybeSyncSession(): void {
    if (Date.now() - this.lastSessionSync < 1500) {
      return;
    }
    this.syncSessionState();
  }

  private async updateSession(): Promise<void> {
    if (this.session === null) {
      return;
    }
    if (this.current === null) {
      await this.syncSessionState();
      return;
    }
    const prev = this.neighbor(-1);
    const next = this.neighbor(1);
    const meta: avSession.AVMetadata = {
      assetId: this.current.key(),
      title: this.current.title.length > 0 ? this.current.title : 'MusicFree',
      artist: this.current.artist,
      author: this.current.artist,
      album: this.current.album,
      duration: this.duration > 0 ? Math.floor(this.duration * 1000) : 0,
      previousAssetId: prev !== null ? prev.key() : '',
      nextAssetId: next !== null ? next.key() : '',
      singleLyricText: this.sessionLyricText()
    };
    const image = this.sessionArtwork();
    if (image.length > 0) {
      meta.mediaImage = image;
    }
    try {
      await this.session.setAVMetadata(meta);
    } catch (e) {
      hilog.error(0x0000, 'MusicFreeSession', 'meta fail %{public}s', `${e}`);
      try {
        const plain: avSession.AVMetadata = {
          assetId: meta.assetId,
          title: meta.title,
          artist: meta.artist,
          duration: meta.duration
        };
        await this.session.setAVMetadata(plain);
      } catch (e2) {
        hilog.error(0x0000, 'MusicFreeSession', 'meta retry fail %{public}s', `${e2}`);
      }
    }
    await this.syncSessionState();
  }

  private sessionArtwork(): string {
    if (this.current === null) {
      return '';
    }
    const art = this.current.artwork.trim();
    if (art.indexOf('http://') === 0 || art.indexOf('https://') === 0 || art.indexOf('file://') === 0) {
      return art;
    }
    return '';
  }

  private sessionLyricText(): string {
    if (this.lyrics.length === 0) {
      return '';
    }
    let idx = this.lyricIndex;
    if (idx < 0) {
      idx = 0;
    }
    if (idx >= this.lyrics.length) {
      idx = this.lyrics.length - 1;
    }
    return this.lyrics[idx].text;
  }

  private async syncSessionState(): Promise<void> {
    if (this.session === null) {
      return;
    }
    if (this.sessionSyncing) {
      this.sessionSyncQueued = true;
      return;
    }
    this.sessionSyncing = true;
    this.lastSessionSync = Date.now();
    let elapsed = Math.floor(this.position * 1000);
    if (elapsed < 0) {
      elapsed = 0;
    }
    const durationMs = this.duration > 0 ? Math.floor(this.duration * 1000) : 0;
    if (durationMs > 0 && elapsed > durationMs) {
      elapsed = durationMs;
    }
    let speed = this.rate / 100;
    if (speed <= 0) {
      speed = 1;
    }
    try {
      const state: avSession.AVPlaybackState = {
        state: this.sessionPlaybackState(),
        speed: speed,
        position: {
          elapsedTime: elapsed,
          updateTime: Date.now()
        },
        bufferedTime: durationMs,
        duration: durationMs,
        loopMode: this.loopModeOf(),
        isFavorite: this.current !== null && this.favoriteChecker(this.current)
      };
      await this.session.setAVPlaybackState(state);
    } catch (e) {
      hilog.error(0x0000, 'MusicFreeSession', 'state fail %{public}s', `${e}`);
    }
    this.sessionSyncing = false;
    if (this.sessionSyncQueued) {
      this.sessionSyncQueued = false;
      this.syncSessionState();
    }
  }

  private async applyMediaCenterControls(): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      await this.session.setMediaCenterControlType(['playPrevious', 'playNext', 'toggleFavorite']);
    } catch (e) {
      hilog.error(0x0000, 'MusicFreeSession', 'controls fail %{public}s', `${e}`);
    }
  }

  private async ensureLaunchAbility(): Promise<void> {
    if (this.session === null || this.context === null || this.sessionLaunchSet) {
      return;
    }
    try {
      const agent = await this.sessionWantAgent();
      await this.session.setLaunchAbility(agent);
      this.sessionLaunchSet = true;
    } catch (e) {
      hilog.error(0x0000, 'MusicFreeSession', 'launch fail %{public}s', `${e}`);
    }
  }

  private async sessionWantAgent(): Promise<object> {
    const bundle = this.context !== null ? this.context.abilityInfo.bundleName : '';
    const ability = this.context !== null ? this.context.abilityInfo.name : 'EntryAbility';
    const module = this.context !== null ? this.context.abilityInfo.moduleName : 'entry';
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: bundle,
          abilityName: ability,
          moduleName: module
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }

  private async startBackground(): Promise<void> {
    if (this.bgStarted || this.context === null) {
      return;
    }
    try {
      const agent = await this.sessionWantAgent();
      await this.ensureLaunchAbility();
      await backgroundTaskManager.startBackgroundRunning(this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.bgStarted = true;
    } catch (e) {
      hilog.error(0x0000, 'MusicFreeSession', 'bg fail %{public}s', `${e}`);
    }
  }
}
