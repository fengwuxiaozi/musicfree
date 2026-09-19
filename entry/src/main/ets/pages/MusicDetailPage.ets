import { RepeatMode, QUALITIES } from '../common/Constants';
import { MusicItem, LyricLine } from '../common/Types';
import { IconImg, PlayTapIcon } from '../components/IconImg';
import { MusicOptionsSheet } from '../components/MusicOptionsSheet';
import { ScheduleClosePanel } from '../components/ScheduleClosePanel';
import { AppService } from '../core/AppService';
import { AppConfig, KEYS } from '../core/AppConfig';
import { formatTime, showToast } from '../core/HttpUtil';
import { LyricExtra } from '../core/LyricExtra';
import { FloatingLyric } from '../core/FloatingLyric';
import { I18n } from '../core/I18n';
import { AppChannel } from '../core/AppChannel';
import { pasteboard } from '@kit.BasicServicesKit';

@Component
export struct MusicDetailPage {
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('currentTitle') currentTitle: string = '';
  @StorageLink('currentArtist') currentArtist: string = '';
  @StorageLink('currentArtwork') currentArtwork: string = '';
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('position') playPosition: number = 0;
  @StorageLink('duration') duration: number = 0;
  @StorageLink('lyricLine') lyricLine: string = I18n.t('lyric.noLyric');
  @StorageLink('hasTranslation') hasTranslation: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;
  @StorageLink('lyricTick') @Watch('onLyricTick') lyricTick: number = 0;
  @StorageLink('lyricLoading') lyricLoading: boolean = false;
  @StorageLink('musicDetailShowTick') @Watch('onDetailShown') musicDetailShowTick: number = 0;
  @StorageLink('playQuality') quality: string = 'standard';
  @StorageLink('playRate') rate: number = 100;
  @StorageLink('downloadTick') @Watch('onDownloadTick') downloadTick: number = 0;
  @State showLyric: boolean = false;
  @State detailTab: number = 0;
  @State lyricPageRev: number = 0;
  @State showList: boolean = false;
  @State listItems: MusicItem[] = [];
  @State showMore: boolean = false;
  @State showSchedule: boolean = false;
  @State moreItem: MusicItem = new MusicItem();
  @State loved: boolean = false;
  @State downloaded: boolean = false;
  @State supportComment: boolean = false;
  @State platform: string = '';
  @State repeat: RepeatMode = RepeatMode.QUEUE;
  @State lyrics: LyricLine[] = [];
  @State lyricIndex: number = -1;
  @State lyricFontSize: number = 16;
  @State showTranslation: boolean = false;
  @State hasAssociated: boolean = false;
  @State showOffset: boolean = false;
  @State offsetDraft: number = 0;
  private detailText: string = '#FCFCFC';
  private detailSecondary: string = '#B3FCFCFC';
  private detailSheetBg: string = '#303030';
  private timer: number = -1;
  private lyricScroller: Scroller = new Scroller();
  private lastLyricScroll: number = -2;
  private lyricHeights: number[] = [];
  @State lyricViewportH: number = 0;
  private lyricHoldUntil: number = 0;
  private lastLyricRefresh: number = 0;

  aboutToAppear(): void {
    this.setShowLyric(AppConfig.getString(KEYS.DETAIL_DEFAULT, 'album') === 'lyric');
    this.sync(true);
    this.startTimer();
    AppService.player.ensureLyric();
  }

  onPageShow(): void {
    this.refreshLyricPage();
  }

  onPageHide(): void {
    this.stopTimer();
  }

  onLyricTick(): void {
    this.sync();
  }

  onDetailShown(): void {
    this.refreshLyricPage();
  }

  onDownloadTick(): void {
    const current = AppService.player.current;
    this.downloaded = current !== null && AppService.isDownloaded(current);
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private refreshLyricPage(): void {
    const now = Date.now();
    if (now - this.lastLyricRefresh > 400) {
      this.lastLyricRefresh = now;
      this.lyricPageRev++;
    }
    this.sync(true);
    this.startTimer();
    AppService.player.ensureLyric();
  }

  private startTimer(): void {
    if (this.timer >= 0) {
      return;
    }
    this.timer = setInterval(() => {
      this.sync();
    }, 400);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private sync(force: boolean = false): void {
    const next = AppService.player.lyrics;
    if (force || this.lyrics !== next) {
      this.lyrics = next;
      this.lyricHeights = [];
      this.lastLyricScroll = -2;
    }
    this.lyricIndex = AppService.player.lyricIndex;
    if (this.showLyric && this.lyricIndex >= 0 && this.lyricIndex !== this.lastLyricScroll &&
      Date.now() >= this.lyricHoldUntil) {
      this.lastLyricScroll = this.lyricIndex;
      this.scrollLyricToCurrent();
    }
    this.repeat = AppService.player.repeatMode;
    this.lyricFontSize = LyricExtra.getFontSize();
    this.showTranslation = LyricExtra.isShowTranslation();
    this.hasTranslation = AppService.player.hasTranslation;
    const current = AppService.player.current;
    this.hasAssociated = current !== null && LyricExtra.getAssociated(current) !== null;
    FloatingLyric.update(this.lyricLine);
    if (current !== null) {
      this.loved = AppService.sheets.isFavorite(current);
      this.downloaded = AppService.isDownloaded(current);
      this.platform = current.platform;
      this.supportComment = this.hasCommentMethod(current);
    } else {
      this.loved = false;
      this.downloaded = false;
      this.platform = '';
      this.supportComment = false;
    }
  }

  private lyricPadHeight(): number {
    if (this.lyricViewportH > 80) {
      return this.lyricViewportH / 2;
    }
    return 220;
  }

  private estimateLineHeight(): number {
    let h = this.lyricFontSize + 20;
    if (this.showTranslation) {
      h += this.translationFontSize() + 8;
    }
    return h;
  }

  private rememberLyricHeight(index: number, height: number): void {
    if (Number.isNaN(height) || height <= 0) {
      return;
    }
    while (this.lyricHeights.length <= index) {
      this.lyricHeights.push(0);
    }
    this.lyricHeights[index] = height;
  }

  private scrollLyricToCurrent(): void {
    if (this.lyricIndex < 0) {
      return;
    }
    let y = 0;
    for (let i = 0; i < this.lyricIndex; i++) {
      if (i < this.lyricHeights.length && this.lyricHeights[i] > 0) {
        y += this.lyricHeights[i];
      } else {
        y += this.estimateLineHeight();
      }
    }
    let cur = this.estimateLineHeight();
    if (this.lyricIndex < this.lyricHeights.length && this.lyricHeights[this.lyricIndex] > 0) {
      cur = this.lyricHeights[this.lyricIndex];
    }
    const target = y + cur / 2;
    const opt: ScrollOptions = {
      xOffset: 0,
      yOffset: target > 0 ? target : 0
    };
    opt.animation = true;
    try {
      this.lyricScroller.scrollTo(opt);
    } catch (_e) {
    }
  }

  private setShowLyric(next: boolean): void {
    const tab = next ? 1 : 0;
    if (this.showLyric === next && this.detailTab === tab) {
      return;
    }
    this.showLyric = next;
    this.detailTab = tab;
    if (next) {
      this.lastLyricScroll = -2;
    }
  }

  private onContentSwipe(dx: number, dy: number): void {
    if (Number.isNaN(dx) || Number.isNaN(dy)) {
      return;
    }
    if (Math.abs(dx) < 48 || Math.abs(dx) <= Math.abs(dy)) {
      return;
    }
    this.setShowLyric(!this.showLyric);
  }

  private hasCommentMethod(current: MusicItem): boolean {
    const plugin = AppService.plugins.findByPlatform(current.platform);
    if (plugin === null) {
      return false;
    }
    return AppService.plugins.hasMethod(plugin, 'getMusicComments');
  }

  private repeatIcon(): string {
    if (this.repeat === RepeatMode.SINGLE) {
      return 'repeat-song';
    }
    if (this.repeat === RepeatMode.SHUFFLE) {
      return 'shuffle';
    }
    return 'repeat-song-1';
  }

  private repeatLabel(): string {
    if (this.repeat === RepeatMode.SINGLE) {
      return I18n.tx(this.appLocale, 'repeatMode.SINGLE');
    }
    if (this.repeat === RepeatMode.SHUFFLE) {
      return I18n.tx(this.appLocale, 'repeatMode.SHUFFLE');
    }
    return I18n.tx(this.appLocale, 'repeatMode.QUEUE');
  }

  private openPlayList(): void {
    this.listItems = AppService.player.playList.slice();
    this.showList = true;
  }

  private translationFontSize(): number {
    const size = this.lyricFontSize - 2;
    return size < 12 ? 12 : size;
  }

  private cycleFont(): void {
    const cur = LyricExtra.getFontSize();
    let next = 16;
    if (cur <= 14) {
      next = 16;
    } else if (cur <= 16) {
      next = 18;
    } else {
      next = 14;
    }
    LyricExtra.setFontSize(next);
    this.lyricFontSize = next;
  }

  private openOffset(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    this.offsetDraft = LyricExtra.getOffset(current);
    this.showOffset = true;
  }

  private applyOffset(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    LyricExtra.setOffset(current, this.offsetDraft);
    AppService.player.reloadLyric();
    this.showOffset = false;
    showToast(I18n.tx(this.appLocale, 'lyric.offsetUpdated'));
  }

  private offsetLabel(): string {
    if (this.offsetDraft === 0) {
      return I18n.tx(this.appLocale, 'panel.setLyricOffset.normal');
    }
    if (this.offsetDraft > 0) {
      return I18n.tx(this.appLocale, 'lyric.offsetAdvance').replace('{time}', this.offsetDraft.toFixed(1));
    }
    return I18n.tx(this.appLocale, 'lyric.offsetDelay').replace('{time}', (-this.offsetDraft).toFixed(1));
  }

  private searchLyric(): void {
    if (AppChannel.isStore()) {
      return;
    }
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    AppService.openSearchLyric(current.title);
  }

  private toggleTranslation(): void {
    if (!this.hasTranslation) {
      showToast(I18n.tx(this.appLocale, 'lyric.noTranslation'));
      return;
    }
    const next = !LyricExtra.isShowTranslation();
    LyricExtra.setShowTranslation(next);
    this.showTranslation = next;
    AppService.player.refreshUi();
  }

  private clearAssociatedLyric(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    LyricExtra.clearAssociated(current);
    this.hasAssociated = false;
    AppService.player.reloadLyric();
    showToast(I18n.tx(this.appLocale, 'panel.musicItemOptions.unassociateLyricSuccess'));
  }

  private qualityLabel(q: string): string {
    if (q === 'low') {
      return I18n.tx(this.appLocale, 'musicQuality.low');
    }
    if (q === 'high') {
      return I18n.tx(this.appLocale, 'musicQuality.high');
    }
    if (q === 'super') {
      return I18n.tx(this.appLocale, 'musicQuality.super');
    }
    return I18n.tx(this.appLocale, 'musicQuality.standard');
  }

  private rateLabel(): string {
    if (this.rate % 100 === 0) {
      return `${(this.rate / 100).toFixed(1)}x`;
    }
    return `${this.rate / 100}x`;
  }

  private copyText(text: string): void {
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      board.setData(data);
      showToast(I18n.tx(this.appLocale, 'toast.copiedToClipboard'));
    } catch (_e) {
      showToast(I18n.tx(this.appLocale, 'toast.copiedToClipboardFailed'));
    }
  }

  private shareCurrent(): void {
    this.copyText(`${this.currentTitle} - ${this.currentArtist}`);
  }

  private toggleLoved(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    AppService.sheets.toggleFavorite(current);
    this.loved = AppService.sheets.isFavorite(current);
    AppService.player.refreshSession();
  }

  private cycleQuality(): void {
    const idx = QUALITIES.indexOf(this.quality);
    const start = idx < 0 ? 0 : idx;
    const next = QUALITIES[(start + 1) % QUALITIES.length];
    AppService.player.changeQuality(next);
    showToast(I18n.tx(this.appLocale, 'basicSettings.qualityToast').replace('{quality}', this.qualityLabel(next)));
  }

  private downloadCurrent(): void {
    if (AppChannel.isStore()) {
      return;
    }
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    if (this.downloaded) {
      showToast(I18n.tx(this.appLocale, 'toast.alreadyDownloaded'));
      return;
    }
    AppService.downloader.download(current);
  }

  private cycleRate(): void {
    const list: number[] = [50, 75, 100, 125, 150, 200];
    let idx = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i] === this.rate) {
        idx = i;
        break;
      }
    }
    const next = list[(idx + 1) % list.length];
    AppService.player.setRate(next);
    showToast(next % 100 === 0 ? `${(next / 100).toFixed(1)}x` : `${next / 100}x`);
  }

  private openComments(): void {
    const current = AppService.player.current;
    if (current === null || !this.hasCommentMethod(current)) {
      showToast(I18n.tx(this.appLocale, 'toast.commmentNotAvaliableForCurrentMusic'));
      return;
    }
    AppService.openComments(current);
  }

  private openMore(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    this.moreItem = current;
    this.showMore = true;
  }

  build() {
    Column() {
      Column() {
        Column() {
          Column() {
      Row() {
        Row() {
          IconImg({ name: 'arrow-left', iconSize: 22, color: this.detailText })
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          AppService.pop();
        })
        Column() {
          Text(this.currentTitle.length > 0 ? this.currentTitle : I18n.tx(this.appLocale, 'musicDetail.notPlaying'))
            .fontSize(16)
            .fontColor(this.detailText)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            Text(this.currentArtist)
              .fontSize(12)
              .fontColor(this.detailText)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.platform.length > 0) {
              Text(this.platform)
                .fontSize(10)
                .fontColor('#FFFFFF')
                .backgroundColor('#33FFFFFF')
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .margin({ left: 6 })
                .maxLines(1)
            }
          }
          .margin({ top: 2 })
          .justifyContent(FlexAlign.Center)
          .constraintSize({ maxWidth: '100%' })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 8, right: 8 })
        Row() {
          IconImg({ name: 'share', iconSize: 22, color: this.detailText })
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.shareCurrent();
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .margin({ top: this.statusBarHeight })
      .alignItems(VerticalAlign.Center)

      Swiper() {
        Column() {
          Column() {
            if (this.currentArtwork.length > 0) {
              Image(this.currentArtwork)
                .width(240)
                .height(240)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
                .margin({ top: 16 })
            } else {
              Image($r('app.media.album_default'))
                .width(240)
                .height(240)
                .borderRadius(12)
                .margin({ top: 16 })
            }
            this.coverLyricPreview()
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.setShowLyric(true);
          })
          .priorityGesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 48 })
              .onActionEnd((event: GestureEvent) => {
                this.onContentSwipe(event.offsetX, event.offsetY);
              })
          )
        }
        .width('100%')
        .height('100%')
        .id(`cover-${this.currentTitle}-${this.currentArtwork}`)

        Column() {
          this.lyricView()
        }
        .width('100%')
        .height('100%')
        .priorityGesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 48 })
            .onActionEnd((event: GestureEvent) => {
              this.onContentSwipe(event.offsetX, event.offsetY);
            })
        )
        .id(`lyric-page-${this.lyricPageRev}`)
      }
      .index($$this.detailTab)
      .indicator(false)
      .loop(false)
      .duration(280)
      .disableSwipe(true)
      .onChange((index: number) => {
        this.setShowLyric(index === 1);
      })
      .cachedCount(2)
      .layoutWeight(1)
      .width('100%')
      .id(`detail-swiper-${this.lyricPageRev}`)

      if (this.showLyric) {
        this.lyricOps()
      } else {
        this.coverOps()
      }

      Slider({
        value: this.duration > 0 ? this.playPosition : 0,
        min: 0,
        max: this.duration > 0 ? this.duration : 1,
        step: 0.5,
        style: SliderStyle.OutSet
      })
        .blockColor(this.detailText)
        .trackColor('#33FFFFFF')
        .selectedColor(this.primary)
        .showTips(false)
        .onChange((v: number) => {
          AppService.player.seekTo(v);
        })
        .width('88%')
        .margin({ top: 8 })

      Row() {
        Text(formatTime(this.playPosition)).fontSize(11).fontColor(this.detailSecondary)
        Blank()
        Text(formatTime(this.duration)).fontSize(11).fontColor(this.detailSecondary)
      }
      .width('88%')
      .margin({ bottom: 8 })

      Row() {
        Column() {
          PlayTapIcon({
            name: this.repeatIcon(),
            iconSize: 28,
            iconColor: this.detailText,
            label: this.repeatLabel(),
            onAction: () => {
              AppService.player.toggleRepeatMode();
              this.repeat = AppService.player.repeatMode;
              showToast(this.repeatLabel());
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          AppService.player.toggleRepeatMode();
          this.repeat = AppService.player.repeatMode;
          showToast(this.repeatLabel());
        })
        Column() {
          PlayTapIcon({
            name: 'skip-left',
            iconSize: 28,
            iconColor: this.detailText,
            label: '上一首',
            onAction: () => {
              AppService.player.skipToPrevious();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          AppService.player.skipToPrevious();
        })
        Column() {
          PlayTapIcon({
            name: this.isPlaying ? 'pause' : 'play',
            iconSize: 48,
            iconColor: this.detailText,
            label: this.isPlaying ? '暂停' : '播放',
            onAction: () => {
              AppService.player.toggle();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          AppService.player.toggle();
        })
        Column() {
          PlayTapIcon({
            name: 'skip-right',
            iconSize: 28,
            iconColor: this.detailText,
            label: '下一首',
            onAction: () => {
              AppService.player.skipToNext();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          AppService.player.skipToNext();
        })
        Column() {
          PlayTapIcon({
            name: 'playlist',
            iconSize: 28,
            iconColor: this.detailText,
            label: I18n.tx(this.appLocale, 'panel.playList.title'),
            onAction: () => {
              this.openPlayList();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          this.openPlayList();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 28, top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#141414')
    .bindSheet($$this.showOffset, this.offsetBuilder(), {
      height: 260,
      showClose: false,
      backgroundColor: this.detailSheetBg,
      blurStyle: BlurStyle.NONE
    })
        }
        .width('100%')
        .height('100%')
        .bindSheet($$this.showList, this.playListBuilder(), {
          height: SheetSize.MEDIUM,
          showClose: false,
          backgroundColor: this.detailSheetBg,
          blurStyle: BlurStyle.NONE
        })
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.showMore, this.moreBuilder(), {
        height: SheetSize.LARGE,
        showClose: false,
        backgroundColor: this.detailSheetBg,
        blurStyle: BlurStyle.NONE
      })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showSchedule, this.scheduleBuilder(), {
      height: 400,
      showClose: false,
      backgroundColor: this.detailSheetBg,
      blurStyle: BlurStyle.NONE
    })
  }

  private coverLyricIndex(): number {
    if (this.lyrics.length === 0) {
      return -1;
    }
    if (this.lyricIndex < 0) {
      return 0;
    }
    if (this.lyricIndex >= this.lyrics.length) {
      return this.lyrics.length - 1;
    }
    return this.lyricIndex;
  }

  private coverLyricText(offset: number): string {
    const idx = this.coverLyricIndex() + offset;
    if (idx < 0 || idx >= this.lyrics.length) {
      return '';
    }
    return this.lyrics[idx].text;
  }

  private coverLyricTranslation(): string {
    const idx = this.coverLyricIndex();
    if (idx < 0 || !this.showTranslation) {
      return '';
    }
    return this.lyrics[idx].translation;
  }

  @Builder
  coverLyricPreview() {
    Column() {
      if (this.lyrics.length === 0) {
        Text(this.lyricLoading ? I18n.tx(this.appLocale, 'lyric.searching') : I18n.tx(this.appLocale, 'lyric.noLyric'))
          .fontSize(15)
          .fontColor(this.detailSecondary)
          .margin({ top: 28 })
        if (!AppChannel.isStore()) {
          Text(I18n.tx(this.appLocale, 'lyric.searchLyric'))
            .fontSize(15)
            .fontColor('#66EEFF')
            .decoration({ type: TextDecorationType.Underline })
            .margin({ top: 10 })
            .onClick(() => {
              this.searchLyric();
            })
        }
      } else {
        Text(this.coverLyricText(-1))
          .fontSize(13)
          .fontColor('#66FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 22 })
          .constraintSize({ minHeight: 20 })
        Text(this.coverLyricText(0))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 8 })
        if (this.coverLyricTranslation().length > 0) {
          Text(this.coverLyricTranslation())
            .fontSize(13)
            .fontColor(this.detailSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 4 })
        }
        Text(this.coverLyricText(1))
          .fontSize(13)
          .fontColor('#66FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 8 })
          .constraintSize({ minHeight: 20 })
      }
    }
    .width('100%')
    .padding({ left: 28, right: 28 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  coverOps() {
    Row() {
      Column() {
        PlayTapIcon({
          name: this.loved ? 'heart' : 'heart-outline',
          iconSize: 22,
          iconColor: this.loved ? '#FC5F5F' : this.detailText,
          label: '收藏',
          onAction: () => {
            this.toggleLoved();
          }
        })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#00000000')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        this.toggleLoved();
      })
      Column() {
        Text(this.qualityLabel(this.quality))
          .fontSize(12)
          .fontColor(this.detailText)
          .maxLines(1)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.cycleQuality();
      })
      if (!AppChannel.isStore()) {
        Column() {
          PlayTapIcon({
            name: this.downloaded ? 'check-circle-outline' : 'arrow-down-tray',
            iconSize: 22,
            iconColor: this.detailText,
            label: '下载',
            onAction: () => {
              this.downloadCurrent();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          this.downloadCurrent();
        })
      }
      Column() {
        Text(this.rateLabel())
          .fontSize(12)
          .fontColor(this.detailText)
          .maxLines(1)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.cycleRate();
      })
      Column() {
        PlayTapIcon({
          name: 'chat-bubble-oval-left-ellipsis',
          iconSize: 22,
          iconColor: this.supportComment ? this.detailText : '#66FFFFFF',
          label: '评论',
          onAction: () => {
            this.openComments();
          }
        })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#00000000')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        this.openComments();
      })
      Column() {
        PlayTapIcon({
          name: 'ellipsis-vertical',
          iconSize: 22,
          iconColor: this.detailText,
          label: '更多',
          onAction: () => {
            this.openMore();
          }
        })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#00000000')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        this.openMore();
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
    .margin({ top: 4, bottom: 4 })
  }

  @Builder
  lyricView() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.lyrics.length > 0) {
        Scroll(this.lyricScroller) {
          Column() {
            Blank().width('100%').height(this.lyricPadHeight())
            ForEach(this.lyrics, (line: LyricLine, index: number) => {
              Column() {
                Text(line.text)
                  .fontSize(this.lyricIndex === index ? this.lyricFontSize + 2 : this.lyricFontSize)
                  .fontColor(this.lyricIndex === index ? this.primary : this.detailSecondary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.showTranslation && line.translation.length > 0) {
                  Text(line.translation)
                    .fontSize(this.translationFontSize())
                    .fontColor(this.detailSecondary)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .margin({ top: 4 })
                }
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .onAreaChange((_old: Area, area: Area) => {
                this.rememberLyricHeight(index, Number(`${area.height}`));
              })
              .onClick(() => {
                AppService.player.seekTo(line.time);
              })
            }, (line: LyricLine, index: number) => `${index}-${line.time}-${line.text}`)
            Blank().width('100%').height(this.lyricPadHeight())
          }
          .width('100%')
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)
        .width('100%')
        .height('100%')
        .padding({ left: 24, right: 24 })
        .onAreaChange((_old: Area, area: Area) => {
          this.lyricViewportH = Number(`${area.height}`);
        })
        .onScrollStart(() => {
          this.lyricHoldUntil = Date.now() + 2000;
        })
      }
      Column() {
        if (this.lyricLoading) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.primary)
            .margin({ bottom: 16 })
        }
        Text(this.lyricLoading ? I18n.tx(this.appLocale, 'lyric.searching') : I18n.tx(this.appLocale, 'lyric.noLyric'))
          .fontSize(this.lyricFontSize)
          .fontColor(this.detailSecondary)
          .onClick(() => {
            this.setShowLyric(false);
          })
        if (!AppChannel.isStore()) {
          Text(I18n.tx(this.appLocale, 'lyric.searchLyric'))
            .fontSize(this.lyricFontSize)
            .fontColor('#66EEFF')
            .decoration({ type: TextDecorationType.Underline })
            .margin({ top: 14 })
            .padding({ top: 8, bottom: 8, left: 16, right: 16 })
            .onClick(() => {
              this.searchLyric();
            })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 80 })
      .visibility(this.lyrics.length === 0 ? Visibility.Visible : Visibility.Hidden)
      .hitTestBehavior(this.lyrics.length === 0 ? HitTestMode.Default : HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .id(`lyric-stack-${this.lyricPageRev}-${this.lyrics.length}`)
  }

  @Builder
  lyricOps() {
    Row() {
      Column() {
        PlayTapIcon({
          name: 'font-size',
          iconSize: 22,
          iconColor: this.detailText,
          label: '字号',
          onAction: () => {
            this.cycleFont();
          }
        })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#00000000')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        this.cycleFont();
      })
      Column() {
        PlayTapIcon({
          name: 'arrows-left-right',
          iconSize: 22,
          iconColor: this.detailText,
          label: '偏移',
          onAction: () => {
            this.openOffset();
          }
        })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#00000000')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        this.openOffset();
      })
      if (!AppChannel.isStore()) {
        Column() {
          PlayTapIcon({
            name: 'magnifying-glass',
            iconSize: 22,
            iconColor: this.detailText,
            label: I18n.tx(this.appLocale, 'lyric.searchLyric'),
            onAction: () => {
              this.searchLyric();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          this.searchLyric();
        })
      }
      Column() {
        PlayTapIcon({
          name: 'translation',
          iconSize: 22,
          iconColor: this.showTranslation && this.hasTranslation ? this.primary : this.detailText,
          label: '翻译',
          onAction: () => {
            this.toggleTranslation();
          }
        })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#00000000')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        this.toggleTranslation();
      })
      if (this.hasAssociated) {
        Column() {
          PlayTapIcon({
            name: 'link-slash',
            iconSize: 22,
            iconColor: this.detailText,
            label: '取消关联',
            onAction: () => {
              this.clearAssociatedLyric();
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          this.clearAssociatedLyric();
        })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
    .margin({ top: 4, bottom: 4 })
  }

  @Builder
  offsetBuilder() {
    Column() {
      Row() {
        Text(I18n.tx(this.appLocale, 'lyric.offsetTitle'))
          .fontSize(16)
          .fontColor(this.detailText)
          .layoutWeight(1)
          .maxLines(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.detailText })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showOffset = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })
      .alignItems(VerticalAlign.Center)
      Text(this.offsetLabel())
        .fontSize(16)
        .fontColor(this.detailText)
        .margin({ top: 12, bottom: 8 })
      Slider({
        value: this.offsetDraft,
        min: -10,
        max: 10,
        step: 0.5,
        style: SliderStyle.OutSet
      })
        .blockColor(this.detailText)
        .trackColor('#33FFFFFF')
        .selectedColor(this.primary)
        .width('88%')
        .onChange((v: number) => {
          this.offsetDraft = v;
        })
      Button(I18n.tx(this.appLocale, 'common.confirm'))
        .width('88%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .onClick(() => {
          this.applyOffset();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.detailSheetBg)
  }

  @Builder
  playListBuilder() {
    Column() {
      Row() {
        Text(I18n.tx(this.appLocale, 'panel.playList.title'))
          .fontSize(16)
          .fontColor(this.detailText)
          .layoutWeight(1)
          .maxLines(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.detailText })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showList = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })
      .alignItems(VerticalAlign.Center)
      List() {
        ForEach(this.listItems, (item: MusicItem, index: number) => {
          ListItem() {
            Row() {
              Text(`${index + 1}`)
                .width(28)
                .fontSize(12)
                .fontColor(this.detailSecondary)
              Column() {
                Text(item.title)
                  .fontSize(14)
                  .fontColor(this.detailText)
                  .maxLines(1)
                Text(item.artist)
                  .fontSize(12)
                  .fontColor(this.detailSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .onClick(() => {
              AppService.player.playListAt(index);
              this.showList = false;
            })
          }
        }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.detailSheetBg)
  }

  @Builder
  moreBuilder() {
    MusicOptionsSheet({
      item: this.moreItem,
      fromDetail: true,
      onClose: () => {
        this.showMore = false;
      },
      onTimingClose: () => {
        this.showMore = false;
        this.showSchedule = true;
      }
    })
  }

  @Builder
  scheduleBuilder() {
    ScheduleClosePanel({
      onDismiss: () => {
        this.showSchedule = false;
      }
    })
  }
}
