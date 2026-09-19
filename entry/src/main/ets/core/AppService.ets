import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { MusicItem, AlbumItem, ArtistItem, SheetItem, PluginMeta, parseMusicList, parseSheetList, asObjectArray, serializeMusicList } from '../common/Types';
import { AppStorageUtil } from './AppStorageUtil';
import { initAppStorageDefaults, ThemeManager } from './ThemeManager';
import { PluginManager } from './PluginManager';
import { TrackPlayer } from './TrackPlayer';
import { MusicSheetManager } from './MusicSheetManager';
import { MusicHistory } from './MusicHistory';
import { FAVORITE_SHEET_ID, LOCAL_PLATFORM, ResumeMode, ROUTES } from '../common/Constants';
import { Downloader } from './Downloader';
import { FloatingLyric } from './FloatingLyric';
import { ScheduleClose } from './ScheduleClose';
import { AppConfig, KEYS } from './AppConfig';
import { I18n } from './I18n';
import { UpdateService } from './UpdateService';
import { LyricExtra } from './LyricExtra';
import { fileTitleFromUri } from './HttpUtil';
import { AppChannel } from './AppChannel';

export class NavParams {
  sheetId: string = '';
  sheet: SheetItem | null = null;
  sheetKind: string = 'sheet';
  album: AlbumItem | null = null;
  artist: ArtistItem | null = null;
  settingType: string = '';
  editorSheetId: string = '';
  editorTitle: string = '';
  editorMusics: MusicItem[] = [];
  searchListTitle: string = '';
  searchList: MusicItem[] = [];
  lyricQuery: string = '';
  commentMusic: MusicItem | null = null;
}

export class AppService {
  static context: common.UIAbilityContext | null = null;
  static mainWindow: window.Window | null = null;
  static nav: NavPathStack = new NavPathStack();
  static params: NavParams = new NavParams();
  static theme: ThemeManager = new ThemeManager();
  static plugins: PluginManager = new PluginManager();
  static player: TrackPlayer = new TrackPlayer();
  static sheets: MusicSheetManager = new MusicSheetManager();
  static history: MusicHistory = new MusicHistory();
  static downloader: Downloader = new Downloader();
  static sandboxReady: boolean = false;
  static searchHistory: string[] = [];
  static localMusics: MusicItem[] = [];
  static webdavUrl: string = '';
  static webdavUsername: string = '';
  static webdavPassword: string = '';
  static resumeMode: string = ResumeMode.APPEND;

  static async init(context: common.UIAbilityContext): Promise<void> {
    AppService.context = context;
    initAppStorageDefaults();
    await AppStorageUtil.init(context);
    await AppConfig.load();
    const lyricMigrated = await AppStorageUtil.getString('cfg.lyric.autoSearchLyricMigrated', '');
    if (lyricMigrated !== '1') {
      AppConfig.setBool(KEYS.AUTO_SEARCH_LYRIC, true);
      await AppStorageUtil.setString('cfg.lyric.autoSearchLyricMigrated', '1');
    }
    I18n.load();
    LyricExtra.load();
    await AppService.theme.load();
    AppService.sheets.load();
    AppService.history.load();
    AppService.loadSearchHistory();
    await AppService.loadLocalMusics();
    await AppService.loadBackupConfig();
    AppStorage.setOrCreate('downloadTick', 0);
    AppStorage.setOrCreate('localMusicTick', 0);
    AppStorage.setOrCreate('lyricTick', 0);
    AppStorage.setOrCreate('lyricLoading', false);
    AppStorage.setOrCreate('musicDetailShowTick', 0);
    AppStorage.setOrCreate('playQuality', AppConfig.getString(KEYS.PLAY_QUALITY, 'standard'));
    AppStorage.setOrCreate('playRate', 100);
    AppService.downloader.addLocalHandler = (origin: MusicItem, localPath: string): MusicItem => {
      return AppService.addDownloadedMusic(origin, localPath);
    };
    AppService.downloader.isLocalHandler = (item: MusicItem): boolean => {
      return AppService.isDownloaded(item);
    };
    AppService.downloader.setup(AppService.plugins, context.filesDir);
    await AppService.player.init(context, AppService.plugins);
    AppService.player.resolveLocalUrl = (item: MusicItem, url: string): string => {
      return AppService.resolveLocalPlayUrl(item, url);
    };
    AppService.player.quality = AppConfig.getString(KEYS.PLAY_QUALITY, 'standard');
    AppService.history.maxLength = AppConfig.getNumber(KEYS.MAX_HISTORY, 50);
    AppService.player.setHistoryHandler((item: MusicItem) => {
      AppService.history.add(item);
    });
    AppService.player.favoriteChecker = (item: MusicItem): boolean => {
      return AppService.sheets.isFavorite(item);
    };
    AppService.player.favoriteToggler = (item: MusicItem): void => {
      AppService.sheets.toggleFavorite(item);
    };
    AppService.player.artworkSaver = (item: MusicItem): void => {
      AppService.persistArtwork(item);
    };
    await FloatingLyric.load();
    ScheduleClose.pauseAndExit = (exit: boolean) => {
      AppService.player.pause();
      if (exit) {
        AppService.player.reset().then(() => {
          AppService.context?.terminateSelf();
        });
      }
    };
    ScheduleClose.init();
  }

  static async onSandboxReady(): Promise<void> {
    if (AppService.sandboxReady) {
      return;
    }
    AppService.sandboxReady = true;
    if (AppChannel.isStore()) {
      if (AppConfig.getBool(KEYS.AUTO_PLAY, false) && AppService.history.list.length > 0) {
        AppService.player.playMusic(AppService.history.list[0]);
      }
      return;
    }
    await AppService.plugins.reloadAll();
    if (AppConfig.getBool(KEYS.AUTO_UPDATE_PLUGIN, false)) {
      try {
        await AppService.plugins.updateAll();
      } catch (_e) {
      }
    }
    if (AppConfig.getBool(KEYS.AUTO_PLAY, false) && AppService.history.list.length > 0) {
      AppService.player.playMusic(AppService.history.list[0]);
    }
    UpdateService.showResult(false);
  }

  static push(name: string): void {
    try {
      AppService.nav.pushPathByName(name, null);
    } catch (_e) {
    }
  }

  static goBackground(): void {
    const ctx = AppService.context;
    if (ctx !== null) {
      ctx.moveAbilityToBackground();
    }
  }

  static exitApp(): void {
    AppService.player.reset().then(() => {
      const ctx = AppService.context;
      if (ctx !== null) {
        ctx.terminateSelf();
      }
    });
  }

  static pop(): void {
    AppService.nav.pop();
  }

  static openMusicListEditor(title: string, sheetId: string, musics: MusicItem[]): void {
    AppService.params.editorTitle = title;
    AppService.params.editorSheetId = sheetId;
    AppService.params.editorMusics = musics.slice();
    AppService.push(ROUTES.MUSIC_LIST_EDITOR);
  }

  static openSearchMusicList(title: string, musics: MusicItem[]): void {
    AppService.params.searchListTitle = title;
    AppService.params.searchList = musics.slice();
    AppService.push(ROUTES.SEARCH_MUSIC_LIST);
  }

  static collectSearchableMusics(): MusicItem[] {
    const out: MusicItem[] = [];
    const seen: Record<string, boolean> = {};
    const add = (item: MusicItem): void => {
      const key = `${item.platform}|${item.id}|${item.url}`;
      if (seen[key]) {
        return;
      }
      seen[key] = true;
      out.push(item);
    };
    for (let i = 0; i < AppService.localMusics.length; i++) {
      add(AppService.localMusics[i]);
    }
    const sheets = AppService.sheets.sheets;
    for (let s = 0; s < sheets.length; s++) {
      const musics = AppService.sheets.getMusics(sheets[s].id);
      for (let m = 0; m < musics.length; m++) {
        add(musics[m]);
      }
    }
    for (let h = 0; h < AppService.history.list.length; h++) {
      add(AppService.history.list[h]);
    }
    return out;
  }

  static openSearchLyric(query: string): void {
    AppService.params.lyricQuery = query;
    AppService.push(ROUTES.SEARCH_LYRIC);
  }

  static openComments(item: MusicItem): void {
    AppService.params.commentMusic = item;
    AppService.push(ROUTES.MUSIC_COMMENT);
  }

  static loadSearchHistory(): void {
    const raw = AppStorageUtil.readText(`${AppStorageUtil.filesRoot()}/search_history.json`);
    if (raw.length === 0) {
      return;
    }
    try {
      const arr = JSON.parse(raw) as Object[];
      const list: string[] = [];
      for (let i = 0; i < arr.length; i++) {
        list.push(`${arr[i]}`);
      }
      AppService.searchHistory = list;
    } catch (_e) {
    }
  }

  static addSearchHistory(q: string): void {
    const next: string[] = [q];
    for (let i = 0; i < AppService.searchHistory.length; i++) {
      if (AppService.searchHistory[i] !== q) {
        next.push(AppService.searchHistory[i]);
      }
    }
    AppService.searchHistory = next.slice(0, 20);
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/search_history.json`, JSON.stringify(AppService.searchHistory));
  }

  static clearSearchHistory(): void {
    AppService.searchHistory = [];
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/search_history.json`, '[]');
  }

  static removeSearchHistory(q: string): void {
    const next: string[] = [];
    for (let i = 0; i < AppService.searchHistory.length; i++) {
      if (AppService.searchHistory[i] !== q) {
        next.push(AppService.searchHistory[i]);
      }
    }
    AppService.searchHistory = next;
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/search_history.json`, JSON.stringify(AppService.searchHistory));
  }

  static async loadLocalMusics(): Promise<void> {
    const raw = AppStorageUtil.readText(`${AppStorageUtil.filesRoot()}/local_musics.json`);
    if (raw.length === 0) {
      return;
    }
    try {
      const arr = JSON.parse(raw) as Object[];
      const list: MusicItem[] = [];
      for (let i = 0; i < arr.length; i++) {
        list.push(MusicItem.fromJson(JSON.stringify(arr[i])));
      }
      AppService.localMusics = list;
      let dirty = false;
      for (let i = 0; i < AppService.localMusics.length; i++) {
        const item = AppService.localMusics[i];
        if (item.title.indexOf('%') >= 0) {
          item.title = fileTitleFromUri(item.url.length > 0 ? item.url : item.title);
          dirty = true;
        }
      }
      if (dirty) {
        AppService.saveLocalMusics();
      }
      const uris: string[] = [];
      for (let i = 0; i < AppService.localMusics.length; i++) {
        uris.push(AppService.localMusics[i].url);
      }
      await AppStorageUtil.activatePickerUris(uris);
      AppService.bindExistingLocalCopies();
    } catch (_e) {
    }
  }

  static bindExistingLocalCopies(): void {
    let dirty = false;
    for (let i = 0; i < AppService.localMusics.length; i++) {
      const item = AppService.localMusics[i];
      if (AppStorageUtil.canOpen(item.url)) {
        continue;
      }
      const copied = AppStorageUtil.findCopiedLocal(item.title);
      if (copied.length === 0) {
        continue;
      }
      item.id = copied;
      item.url = copied;
      item.rawJson = JSON.stringify({
        'id': item.id,
        'platform': item.platform,
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'url': item.url
      });
      dirty = true;
    }
    if (dirty) {
      AppService.saveLocalMusics();
    }
  }

  static saveLocalMusics(): void {
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/local_musics.json`, serializeMusicList(AppService.localMusics));
    AppService.notifyLocalMusics();
  }

  static replaceLocalMusics(list: MusicItem[]): void {
    AppService.localMusics = list.slice();
    AppService.saveLocalMusics();
  }

  static persistArtwork(item: MusicItem): void {
    if (item.artwork.length === 0) {
      return;
    }
    let localDirty = false;
    for (let i = 0; i < AppService.localMusics.length; i++) {
      const row = AppService.localMusics[i];
      const same = row.sameAs(item) ||
        (item.url.length > 0 && (row.url === item.url || row.id === item.url || row.url === item.id));
      if (!same) {
        continue;
      }
      row.artwork = item.artwork;
      if (item.artist.length > 0) {
        row.artist = item.artist;
      }
      if (item.album.length > 0) {
        row.album = item.album;
      }
      if (item.title.length > 0) {
        row.title = item.title;
      }
      row.rawJson = JSON.stringify({
        'id': row.id,
        'platform': row.platform,
        'title': row.title,
        'artist': row.artist,
        'album': row.album,
        'artwork': row.artwork,
        'url': row.url
      });
      localDirty = true;
    }
    if (localDirty) {
      AppService.saveLocalMusics();
    }
    AppService.history.patchMeta(item);
    AppService.sheets.patchMeta(item);
  }

  static notifyLocalMusics(): void {
    const cur = AppStorage.get<number>('localMusicTick');
    const tick: number = cur !== undefined && cur !== null ? cur : 0;
    AppStorage.setOrCreate('localMusicTick', tick + 1);
  }

  static async addLocalMusic(title: string, uri: string): Promise<boolean> {
    const display = fileTitleFromUri(title.length > 0 ? title : uri);
    let playUrl = uri;
    if (!AppStorageUtil.isAppLocalFile(uri)) {
      const persisted = await AppStorageUtil.persistPickerUri(uri);
      if (!persisted) {
        try {
          playUrl = AppStorageUtil.importLocalAudio(uri, display);
        } catch (_e) {
          playUrl = '';
        }
        if (playUrl.length === 0 && !AppStorageUtil.canOpen(uri)) {
          return false;
        }
        if (playUrl.length === 0) {
          playUrl = uri;
        }
      }
    }
    for (let i = 0; i < AppService.localMusics.length; i++) {
      const row = AppService.localMusics[i];
      const same = row.url === playUrl || row.id === playUrl || row.id === uri || row.url === uri ||
        (row.platform === LOCAL_PLATFORM && row.title === display);
      if (!same) {
        continue;
      }
      if (row.url !== playUrl || row.id !== playUrl) {
        row.id = playUrl;
        row.url = playUrl;
        row.rawJson = JSON.stringify({
          'id': row.id,
          'platform': row.platform,
          'title': row.title,
          'artist': row.artist,
          'album': row.album,
          'url': row.url
        });
        AppService.saveLocalMusics();
      }
      return true;
    }
    const item = new MusicItem();
    item.id = playUrl;
    item.platform = LOCAL_PLATFORM;
    item.title = display;
    item.artist = I18n.t('common.local');
    item.album = I18n.t('home.localMusic');
    item.url = playUrl;
    item.rawJson = JSON.stringify({
      'id': item.id,
      'platform': item.platform,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'url': item.url
    });
    AppService.localMusics.push(item);
    AppService.saveLocalMusics();
    return true;
  }

  static resolveLocalPlayUrl(item: MusicItem, fallback: string): string {
    const seen: string[] = [];
    const push = (url: string): void => {
      if (url.length > 0 && seen.indexOf(url) < 0) {
        seen.push(url);
      }
    };
    push(fallback);
    push(item.url);
    for (let i = 0; i < AppService.localMusics.length; i++) {
      const row = AppService.localMusics[i];
      if (row.id === item.id || row.url === item.url || row.sameAs(item)) {
        push(row.url);
      }
    }
    for (let i = 0; i < AppService.localMusics.length; i++) {
      const row = AppService.localMusics[i];
      if (row.title === item.title && (row.artist === item.artist || item.platform === LOCAL_PLATFORM)) {
        push(row.url);
      }
    }
    for (let i = 0; i < seen.length; i++) {
      const readable = AppStorageUtil.resolveReadablePath(seen[i]);
      if (readable.length > 0) {
        return readable;
      }
    }
    return fallback;
  }

  static isDownloaded(item: MusicItem): boolean {
    return AppService.findDownloaded(item) !== null || item.platform === LOCAL_PLATFORM;
  }

  static findDownloaded(item: MusicItem): MusicItem | null {
    if (item.platform === LOCAL_PLATFORM) {
      return item;
    }
    const key = item.key();
    for (let i = 0; i < AppService.localMusics.length; i++) {
      if (AppService.localMusics[i].id === key || AppService.localMusics[i].sameAs(item)) {
        return AppService.localMusics[i];
      }
    }
    return null;
  }

  static removeLocalDownload(item: MusicItem): void {
    const local = AppService.findDownloaded(item);
    const next: MusicItem[] = [];
    for (let i = 0; i < AppService.localMusics.length; i++) {
      const row = AppService.localMusics[i];
      if (local !== null && (row.id === local.id || row.sameAs(item))) {
        continue;
      }
      if (item.platform === LOCAL_PLATFORM && row.sameAs(item)) {
        continue;
      }
      next.push(row);
    }
    AppService.localMusics = next;
    AppService.saveLocalMusics();
    const path = local !== null ? local.url : (item.platform === LOCAL_PLATFORM ? item.url : '');
    if (path.length > 0 && path.indexOf('/') === 0) {
      try {
        AppStorageUtil.removeFile(path);
      } catch (_e) {
      }
    }
  }

  static findLocalByPath(path: string): MusicItem | null {
    for (let i = 0; i < AppService.localMusics.length; i++) {
      if (AppService.localMusics[i].url === path) {
        return AppService.localMusics[i];
      }
    }
    return null;
  }

  static addDownloadedMusic(origin: MusicItem, localPath: string): MusicItem {
    const existed = AppService.findLocalByPath(localPath);
    if (existed !== null) {
      return existed;
    }
    const key = origin.key();
    for (let i = 0; i < AppService.localMusics.length; i++) {
      if (AppService.localMusics[i].id === key) {
        AppService.localMusics[i].url = localPath;
        AppService.saveLocalMusics();
        return AppService.localMusics[i];
      }
    }
    const item = new MusicItem();
    item.id = key;
    item.platform = LOCAL_PLATFORM;
    item.title = origin.title;
    item.artist = origin.artist;
    item.album = origin.album;
    item.artwork = origin.artwork;
    item.duration = origin.duration;
    item.url = localPath;
    item.rawJson = JSON.stringify({
      'id': item.id,
      'platform': item.platform,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'artwork': item.artwork,
      'duration': item.duration,
      'url': item.url
    });
    AppService.localMusics.push(item);
    AppService.saveLocalMusics();
    return item;
  }

  static async loadBackupConfig(): Promise<void> {
    AppService.webdavUrl = await AppStorageUtil.getString('webdav.url', '');
    AppService.webdavUsername = await AppStorageUtil.getString('webdav.username', '');
    AppService.webdavPassword = await AppStorageUtil.getString('webdav.password', '');
    const mode = await AppStorageUtil.getString('backup.resumeMode', ResumeMode.APPEND);
    if (mode === ResumeMode.OVERWRITE || mode === ResumeMode.OVERWRITE_DEFAULT) {
      AppService.resumeMode = mode;
    } else {
      AppService.resumeMode = ResumeMode.APPEND;
    }
  }

  static async saveWebdav(url: string, username: string, password: string): Promise<void> {
    AppService.webdavUrl = url;
    AppService.webdavUsername = username;
    AppService.webdavPassword = password;
    await AppStorageUtil.setString('webdav.url', url);
    await AppStorageUtil.setString('webdav.username', username);
    await AppStorageUtil.setString('webdav.password', password);
  }

  static async saveResumeMode(mode: string): Promise<void> {
    if (mode === ResumeMode.OVERWRITE || mode === ResumeMode.OVERWRITE_DEFAULT) {
      AppService.resumeMode = mode;
    } else {
      AppService.resumeMode = ResumeMode.APPEND;
    }
    await AppStorageUtil.setString('backup.resumeMode', AppService.resumeMode);
  }

  static buildBackupJson(): string {
    const file = new BackupFile();
    const sheets = AppService.sheets.sheets;
    for (let i = 0; i < sheets.length; i++) {
      const sheet = sheets[i];
      const row = new BackupSheetRow();
      row.id = sheet.id;
      row.platform = sheet.platform;
      row.title = sheet.title;
      row.artist = sheet.artist;
      row.coverImg = sheet.coverImg;
      row.artwork = sheet.coverImg;
      row.description = sheet.description;
      row.musicList = AppService.sheets.getMusics(sheet.id);
      row.worksNum = row.musicList.length;
      file.musicSheets.push(row);
    }
    const enabled: PluginMeta[] = AppService.plugins.enabledPlugins();
    for (let i = 0; i < enabled.length; i++) {
      if (enabled[i].srcUrl.length > 0) {
        const plugin = new BackupPluginRow();
        plugin.srcUrl = enabled[i].srcUrl;
        plugin.version = enabled[i].version;
        file.plugins.push(plugin);
      }
    }
    file.starred = AppService.sheets.starred;
    file.history = AppService.history.list;
    file.searchHistory = AppService.searchHistory;
    file.localMusics = AppService.localMusics;
    return JSON.stringify(file);
  }

  static async restoreBackup(raw: string): Promise<string> {
    const obj = AppService.parseBackupObject(raw);
    const packs = AppService.collectResumePacks(obj);
    const plugins = asObjectArray(obj['plugins']);
    if (packs.length === 0 && plugins.length === 0 &&
      asObjectArray(obj['starred']).length === 0 &&
      asObjectArray(obj['history']).length === 0 &&
      asObjectArray(obj['localMusics']).length === 0) {
      throw new Error(I18n.t('toast.backupInvalid'));
    }
    if (AppService.resumeMode === ResumeMode.OVERWRITE) {
      AppService.resumeOverwrite(packs);
    } else if (AppService.resumeMode === ResumeMode.OVERWRITE_DEFAULT) {
      AppService.resumeOverwriteDefault(packs);
    } else {
      AppService.resumeAppend(packs);
    }
    const pluginStat = await AppService.restorePlugins(plugins);
    AppService.restoreStarred(obj);
    AppService.restoreHistory(obj);
    AppService.restoreSearchHistory(obj);
    AppService.restoreLocalMusics(obj);
    if (pluginStat.ok > 0 || pluginStat.fail > 0) {
      return `${I18n.t('toast.resumeSuccess')}  ${I18n.t('toast.resumePluginResult').replace('{ok}', `${pluginStat.ok}`).replace('{fail}', `${pluginStat.fail}`)}`;
    }
    return I18n.t('toast.resumeSuccess');
  }

  private static parseBackupObject(raw: string): Record<string, Object> {
    let text = raw.trim();
    if (text.length > 0 && text.charCodeAt(0) === 0xFEFF) {
      text = text.substring(1);
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(text) as Object;
    } catch (_e) {
      throw new Error(I18n.t('toast.backupInvalid'));
    }
    if (typeof parsed === 'string') {
      try {
        parsed = JSON.parse(parsed as string) as Object;
      } catch (_e) {
        throw new Error(I18n.t('toast.backupInvalid'));
      }
    }
    if (parsed === null || typeof parsed !== 'object') {
      throw new Error(I18n.t('toast.backupInvalid'));
    }
    return parsed as Record<string, Object>;
  }

  private static collectResumePacks(obj: Record<string, Object>): ResumePack[] {
    const originSheets = asObjectArray(obj['musicSheets']);
    if (originSheets.length > 0) {
      const packs: ResumePack[] = [];
      for (let i = 0; i < originSheets.length; i++) {
        const row = originSheets[i] as Record<string, Object>;
        const pack = AppService.packFromSheetRow(row);
        if (pack.sheet.id.length === 0 && pack.sheet.title.length === 0 && pack.musics.length === 0) {
          continue;
        }
        packs.push(pack);
      }
      return packs;
    }
    const packs: ResumePack[] = [];
    const byId: Record<string, MusicItem[]> = {};
    const songRows = asObjectArray(obj['sheetSongs']);
    if (songRows.length > 0) {
      for (let i = 0; i < songRows.length; i++) {
        const row = songRows[i] as Record<string, Object>;
        const listVal = row['musics'] !== undefined ? row['musics'] : row['musicList'];
        byId[`${row['id']}`] = parseMusicList(JSON.stringify(asObjectArray(listVal)));
      }
    } else if (obj['sheetSongs'] !== undefined && obj['sheetSongs'] !== null) {
      const map = obj['sheetSongs'] as Record<string, Object>;
      const keys = Object.keys(map);
      for (let i = 0; i < keys.length; i++) {
        byId[keys[i]] = parseMusicList(JSON.stringify(asObjectArray(map[keys[i]])));
      }
    }
    const sheetsVal = asObjectArray(obj['sheets']);
    for (let i = 0; i < sheetsVal.length; i++) {
      const row = sheetsVal[i] as Record<string, Object>;
      const pack = AppService.packFromSheetRow(row);
      if (byId[pack.sheet.id] !== undefined) {
        pack.musics = byId[pack.sheet.id];
      }
      if (pack.sheet.id.length === 0 && pack.sheet.title.length === 0 && pack.musics.length === 0) {
        continue;
      }
      packs.push(pack);
    }
    return packs;
  }

  private static packFromSheetRow(row: Record<string, Object>): ResumePack {
    const pack = new ResumePack();
    pack.sheet = SheetItem.fromJson(JSON.stringify(row));
    const nested = row['musicList'] !== undefined ? row['musicList'] : row['musics'];
    if (nested !== undefined) {
      pack.musics = parseMusicList(JSON.stringify(asObjectArray(nested)));
    }
    return pack;
  }

  private static resumeAppend(packs: ResumePack[]): void {
    for (let i = packs.length - 1; i >= 0; i--) {
      const title = packs[i].sheet.title.length > 0 ? packs[i].sheet.title : I18n.t('common.unnamedSheet');
      const created = AppService.sheets.addSheet(title);
      if (packs[i].musics.length > 0) {
        AppService.sheets.addMusics(created.id, packs[i].musics);
      }
    }
  }

  private static resumeOverwriteDefault(packs: ResumePack[]): void {
    const others: ResumePack[] = [];
    for (let i = 0; i < packs.length; i++) {
      if (packs[i].sheet.id === FAVORITE_SHEET_ID) {
        if (packs[i].musics.length > 0) {
          AppService.sheets.addMusics(FAVORITE_SHEET_ID, packs[i].musics);
        }
      } else {
        others.push(packs[i]);
      }
    }
    AppService.resumeAppend(others);
  }

  private static resumeOverwrite(packs: ResumePack[]): void {
    for (let i = packs.length - 1; i >= 0; i--) {
      const sheet = packs[i].sheet;
      let targetId = '';
      if (sheet.id === FAVORITE_SHEET_ID) {
        targetId = FAVORITE_SHEET_ID;
      } else {
        for (let j = 0; j < AppService.sheets.sheets.length; j++) {
          if (AppService.sheets.sheets[j].title === sheet.title) {
            targetId = AppService.sheets.sheets[j].id;
            break;
          }
        }
      }
      if (targetId.length === 0) {
        const title = sheet.title.length > 0 ? sheet.title : I18n.t('common.unnamedSheet');
        targetId = AppService.sheets.addSheet(title).id;
      }
      if (packs[i].musics.length > 0) {
        AppService.sheets.addMusics(targetId, packs[i].musics);
      }
    }
  }

  private static async restorePlugins(plugins: Object[]): Promise<PluginRestoreStat> {
    const stat = new PluginRestoreStat();
    const skipVer = AppConfig.getBool(KEYS.NOT_CHECK_PLUGIN_VERSION, false);
    for (let i = 0; i < plugins.length; i++) {
      const row = plugins[i] as Record<string, Object>;
      const srcUrl = AppService.pluginResumeUrl(row);
      const code = AppService.pluginResumeCode(row);
      if (srcUrl.length === 0 && code.length === 0) {
        continue;
      }
      const version = row['version'] ? `${row['version']}` : '0.0.1';
      if (srcUrl.length > 0 && !skipVer) {
        const existing = AppService.findPluginBySrcUrl(srcUrl);
        const localVer = existing !== null && existing.version.length > 0 ? existing.version : '0.0.0';
        const backupVer = version.length > 0 ? version : '0.0.1';
        if (existing !== null && UpdateService.compareVersion(localVer, backupVer) >= 0) {
          continue;
        }
      }
      if (srcUrl.length > 0) {
        const result = await AppService.plugins.installFromUrlResult(srcUrl);
        if (result.success) {
          stat.ok += 1;
          continue;
        }
        if (code.length === 0) {
          stat.fail += 1;
          continue;
        }
      }
      try {
        await AppService.plugins.installCode(code, srcUrl);
        stat.ok += 1;
      } catch (_e) {
        stat.fail += 1;
      }
    }
    return stat;
  }

  private static pluginResumeUrl(row: Record<string, Object>): string {
    let srcUrl = `${row['srcUrl'] || ''}`.trim();
    if (srcUrl.length === 0) {
      srcUrl = `${row['url'] || ''}`.trim();
    }
    if (srcUrl.length === 0) {
      srcUrl = `${row['href'] || ''}`.trim();
    }
    return srcUrl;
  }

  private static pluginResumeCode(row: Record<string, Object>): string {
    let code = `${row['code'] || ''}`.trim();
    if (code.length === 0) {
      code = `${row['script'] || ''}`.trim();
    }
    if (code.length === 0) {
      code = `${row['raw'] || ''}`.trim();
    }
    return code;
  }

  private static findPluginBySrcUrl(srcUrl: string): PluginMeta | null {
    return AppService.plugins.findBySrcUrl(srcUrl);
  }

  private static restoreStarred(obj: Record<string, Object>): void {
    const starred = parseSheetList(JSON.stringify(asObjectArray(obj['starred'])));
    for (let i = 0; i < starred.length; i++) {
      AppService.sheets.starSheet(starred[i], true);
    }
  }

  private static restoreHistory(obj: Record<string, Object>): void {
    const incoming = parseMusicList(JSON.stringify(asObjectArray(obj['history'])));
    if (incoming.length === 0) {
      return;
    }
    const merged: MusicItem[] = [];
    AppService.mergeMusicUnique(merged, incoming);
    AppService.mergeMusicUnique(merged, AppService.history.list);
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/history.json`, JSON.stringify(merged));
    AppService.history.load();
  }

  private static restoreSearchHistory(obj: Record<string, Object>): void {
    const arr = asObjectArray(obj['searchHistory']);
    if (arr.length === 0) {
      return;
    }
    const next: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      const q = `${arr[i]}`;
      if (q.length > 0 && next.indexOf(q) < 0) {
        next.push(q);
      }
    }
    for (let i = 0; i < AppService.searchHistory.length; i++) {
      const q = AppService.searchHistory[i];
      if (next.indexOf(q) < 0) {
        next.push(q);
      }
    }
    AppService.searchHistory = next.slice(0, 20);
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/search_history.json`, JSON.stringify(AppService.searchHistory));
  }

  private static restoreLocalMusics(obj: Record<string, Object>): void {
    const incoming = parseMusicList(JSON.stringify(asObjectArray(obj['localMusics'])));
    if (incoming.length === 0) {
      return;
    }
    AppService.mergeMusicUnique(AppService.localMusics, incoming);
    AppService.saveLocalMusics();
  }

  private static mergeMusicUnique(target: MusicItem[], extra: MusicItem[]): void {
    for (let i = 0; i < extra.length; i++) {
      let exists = false;
      for (let j = 0; j < target.length; j++) {
        if (target[j].sameAs(extra[i]) || (target[j].id.length > 0 && target[j].id === extra[i].id && target[j].platform === extra[i].platform)) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        target.push(extra[i]);
      }
    }
  }

  static async importSheetByUrl(url: string): Promise<number> {
    const trimmed = url.trim();
    if (trimmed.length === 0) {
      return 0;
    }
    const list = await AppService.plugins.importMusicSheet(trimmed);
    if (list.length === 0) {
      return 0;
    }
    const sheet = AppService.sheets.addSheet(`导入歌单 ${list.length}首`);
    AppService.sheets.addMusics(sheet.id, list);
    return list.length;
  }
}

class PluginRestoreStat {
  ok: number = 0;
  fail: number = 0;
}

class ResumePack {
  sheet: SheetItem = new SheetItem();
  musics: MusicItem[] = [];
}

class BackupPluginRow {
  srcUrl: string = '';
  version: string = '';
}

class BackupSheetRow {
  id: string = '';
  platform: string = '';
  title: string = '';
  artist: string = '';
  coverImg: string = '';
  artwork: string = '';
  worksNum: number = 0;
  description: string = '';
  musicList: MusicItem[] = [];
}

class BackupFile {
  musicSheets: BackupSheetRow[] = [];
  plugins: BackupPluginRow[] = [];
  starred: SheetItem[] = [];
  history: MusicItem[] = [];
  searchHistory: string[] = [];
  localMusics: MusicItem[] = [];
}
