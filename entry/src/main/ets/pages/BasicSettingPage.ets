import { AppNavBar } from '../components/AppNavBar';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { AppConfig, KEYS } from '../core/AppConfig';
import { AppStorageUtil } from '../core/AppStorageUtil';
import { FloatingLyric } from '../core/FloatingLyric';
import { I18n } from '../core/I18n';
import { MediaCache } from '../core/MediaCache';
import { QUALITIES } from '../common/Constants';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { AppChannel } from '../core/AppChannel';

@Component
export struct BasicSettingPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('divider') divider: string = '#1AFFFFFF';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;
  @State maxHistoryLen: number = 50;
  @State detailDefault: string = 'album';
  @State musicDetailAwake: boolean = false;
  @State associateLyricType: string = 'search';
  @State showExitOnNotification: boolean = false;
  @State clickSearch: string = 'playMusic';
  @State clickAlbum: string = 'playAlbum';
  @State musicOrder: string = 'title';
  @State autoUpdatePlugin: boolean = false;
  @State notCheckPluginVersion: boolean = false;
  @State lazyLoadPlugin: boolean = false;
  @State notInterrupt: boolean = false;
  @State autoPlay: boolean = false;
  @State tryChangeSource: boolean = false;
  @State autoStopError: boolean = false;
  @State tempRemoteDuck: string = 'pause';
  @State tempRemoteDuckVolume: number = 0.5;
  @State playQuality: string = 'standard';
  @State playQualityOrder: string = 'asc';
  @State downloadPath: string = '';
  @State maxDownload: number = 3;
  @State downloadQuality: string = 'standard';
  @State downloadQualityOrder: string = 'asc';
  @State cellularPlay: boolean = false;
  @State cellularDownload: boolean = false;
  @State autoSearchLyric: boolean = true;
  @State desktopLyric: boolean = false;
  @State lyricLeft: number = 0.5;
  @State lyricTop: number = 0;
  @State lyricWidth: number = 0.5;
  @State lyricFont: number = 16;
  @State lyricAlign: number = 1;
  @State lyricColor: string = '#FFE9D2FF';
  @State lyricBg: string = '#84888153';
  @State maxCacheMb: number = 512;
  @State musicCacheSize: string = '0B';
  @State lyricCacheSize: string = '0B';
  @State imageCacheSize: string = '0B';
  @State debugErrorLog: boolean = false;
  @State debugTraceLog: boolean = false;
  @State debugDevLog: boolean = false;
  @State showPicker: boolean = false;
  @State pickerTitle: string = '';
  @State pickerKind: string = '';
  @State pickerValues: string[] = [];
  @State pickerLabels: string[] = [];
  @State pickerCurrent: string = '';
  @State showConfirm: boolean = false;
  @State confirmKind: string = '';
  @State confirmTitle: string = '';
  @State confirmContent: string = '';
  @State showCacheInput: boolean = false;
  @State cacheInput: string = '';
  @State showColor: boolean = false;
  @State colorKind: string = '';
  @State showLog: boolean = false;
  @State logText: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.maxHistoryLen = AppConfig.getNumber(KEYS.MAX_HISTORY, 50);
    this.detailDefault = AppConfig.getString(KEYS.DETAIL_DEFAULT, 'album');
    this.musicDetailAwake = AppConfig.getBool(KEYS.MUSIC_DETAIL_AWAKE, false);
    this.associateLyricType = AppConfig.getString(KEYS.ASSOCIATE_LYRIC_TYPE, 'search');
    this.showExitOnNotification = AppConfig.getBool(KEYS.SHOW_EXIT_NOTIFICATION, false);
    this.clickSearch = AppConfig.getString(KEYS.CLICK_SEARCH, 'playMusic');
    this.clickAlbum = AppConfig.getString(KEYS.CLICK_ALBUM, 'playAlbum');
    this.musicOrder = AppConfig.getString(KEYS.MUSIC_ORDER, 'title');
    this.autoUpdatePlugin = AppConfig.getBool(KEYS.AUTO_UPDATE_PLUGIN, false);
    this.notCheckPluginVersion = AppConfig.getBool(KEYS.NOT_CHECK_PLUGIN_VERSION, false);
    this.lazyLoadPlugin = AppConfig.getBool(KEYS.LAZY_LOAD_PLUGIN, false);
    this.notInterrupt = AppConfig.getBool(KEYS.NOT_INTERRUPT, false);
    this.autoPlay = AppConfig.getBool(KEYS.AUTO_PLAY, false);
    this.tryChangeSource = AppConfig.getBool(KEYS.TRY_CHANGE_SOURCE, false);
    this.autoStopError = AppConfig.getBool(KEYS.AUTO_STOP_ERROR, false);
    this.tempRemoteDuck = AppConfig.getString(KEYS.TEMP_REMOTE_DUCK, 'pause');
    this.tempRemoteDuckVolume = AppConfig.getNumber(KEYS.TEMP_REMOTE_DUCK_VOLUME, 0.5);
    this.playQuality = AppConfig.getString(KEYS.PLAY_QUALITY, 'standard');
    this.playQualityOrder = AppConfig.getString(KEYS.PLAY_QUALITY_ORDER, 'asc');
    this.downloadPath = AppConfig.getString(KEYS.DOWNLOAD_PATH, AppStorageUtil.defaultDownloadDir());
    this.maxDownload = AppConfig.getNumber(KEYS.MAX_DOWNLOAD, 3);
    this.downloadQuality = AppConfig.getString(KEYS.DOWNLOAD_QUALITY, 'standard');
    this.downloadQualityOrder = AppConfig.getString(KEYS.DOWNLOAD_QUALITY_ORDER, 'asc');
    this.cellularPlay = AppConfig.getBool(KEYS.CELLULAR_PLAY, false);
    this.cellularDownload = AppConfig.getBool(KEYS.CELLULAR_DOWNLOAD, false);
    this.autoSearchLyric = AppConfig.getBool(KEYS.AUTO_SEARCH_LYRIC, true);
    this.desktopLyric = FloatingLyric.isEnabled();
    this.lyricLeft = AppConfig.getNumber(KEYS.LYRIC_LEFT, 0.5);
    this.lyricTop = AppConfig.getNumber(KEYS.LYRIC_TOP, 0);
    this.lyricWidth = AppConfig.getNumber(KEYS.LYRIC_WIDTH, 0.5);
    this.lyricFont = AppConfig.getNumber(KEYS.LYRIC_FONT, 16);
    this.lyricAlign = AppConfig.getNumber(KEYS.LYRIC_ALIGN, 1);
    this.lyricColor = AppConfig.getString(KEYS.LYRIC_COLOR, '#FFE9D2FF');
    this.lyricBg = AppConfig.getString(KEYS.LYRIC_BG, '#84888153');
    const cacheBytes = AppConfig.getNumber(KEYS.MAX_CACHE_SIZE, 512 * 1024 * 1024);
    this.maxCacheMb = Math.max(100, Math.floor(cacheBytes / (1024 * 1024)));
    this.debugErrorLog = AppConfig.getBool(KEYS.DEBUG_ERROR_LOG, false);
    this.debugTraceLog = AppConfig.getBool(KEYS.DEBUG_TRACE_LOG, false);
    this.debugDevLog = AppConfig.getBool(KEYS.DEBUG_DEV_LOG, false);
    this.refreshCacheSizes();
    AppService.player.quality = this.playQuality;
    AppService.history.maxLength = this.maxHistoryLen;
    FloatingLyric.publishStyle();
  }

  private refreshCacheSizes(): void {
    this.musicCacheSize = AppStorageUtil.formatBytes(
      AppStorageUtil.dirSize(AppStorageUtil.cacheDir('music')) +
        AppStorageUtil.fileSize(`${AppStorageUtil.filesRoot()}/media_cache.json`)
    );
    this.lyricCacheSize = AppStorageUtil.formatBytes(AppStorageUtil.dirSize(AppStorageUtil.cacheDir('lyric')));
    this.imageCacheSize = AppStorageUtil.formatBytes(AppStorageUtil.dirSize(AppStorageUtil.cacheDir('image')));
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

  private openPicker(kind: string, title: string, values: string[], labels: string[], current: string): void {
    this.pickerKind = kind;
    this.pickerTitle = title;
    this.pickerValues = values;
    this.pickerLabels = labels;
    this.pickerCurrent = current;
    this.showPicker = true;
  }

  private applyPicker(value: string): void {
    this.showPicker = false;
    if (this.pickerKind === 'history') {
      this.maxHistoryLen = Number(value);
      AppConfig.setNumber(KEYS.MAX_HISTORY, this.maxHistoryLen);
      AppService.history.maxLength = this.maxHistoryLen;
    } else if (this.pickerKind === 'detailDefault') {
      this.detailDefault = value;
      AppConfig.setString(KEYS.DETAIL_DEFAULT, value);
    } else if (this.pickerKind === 'associateLyric') {
      this.associateLyricType = value;
      AppConfig.setString(KEYS.ASSOCIATE_LYRIC_TYPE, value);
    } else if (this.pickerKind === 'clickSearch') {
      this.clickSearch = value;
      AppConfig.setString(KEYS.CLICK_SEARCH, value);
    } else if (this.pickerKind === 'clickAlbum') {
      this.clickAlbum = value;
      AppConfig.setString(KEYS.CLICK_ALBUM, value);
    } else if (this.pickerKind === 'musicOrder') {
      this.musicOrder = value;
      AppConfig.setString(KEYS.MUSIC_ORDER, value);
    } else if (this.pickerKind === 'tempRemoteDuck') {
      this.tempRemoteDuck = value;
      AppConfig.setString(KEYS.TEMP_REMOTE_DUCK, value);
    } else if (this.pickerKind === 'duckVolume') {
      this.tempRemoteDuckVolume = Number(value);
      AppConfig.setNumber(KEYS.TEMP_REMOTE_DUCK_VOLUME, this.tempRemoteDuckVolume);
    } else if (this.pickerKind === 'playQuality') {
      this.playQuality = value;
      AppConfig.setString(KEYS.PLAY_QUALITY, value);
      AppService.player.quality = value;
    } else if (this.pickerKind === 'playQualityOrder') {
      this.playQualityOrder = value;
      AppConfig.setString(KEYS.PLAY_QUALITY_ORDER, value);
    } else if (this.pickerKind === 'maxDownload') {
      this.maxDownload = Number(value);
      AppConfig.setNumber(KEYS.MAX_DOWNLOAD, this.maxDownload);
    } else if (this.pickerKind === 'downloadQuality') {
      this.downloadQuality = value;
      AppConfig.setString(KEYS.DOWNLOAD_QUALITY, value);
    } else if (this.pickerKind === 'downloadQualityOrder') {
      this.downloadQualityOrder = value;
      AppConfig.setString(KEYS.DOWNLOAD_QUALITY_ORDER, value);
    } else if (this.pickerKind === 'lyricAlign') {
      this.lyricAlign = Number(value);
      AppConfig.setNumber(KEYS.LYRIC_ALIGN, this.lyricAlign);
      FloatingLyric.publishStyle();
    }
  }

  private openConfirm(kind: string, title: string, content: string): void {
    this.confirmKind = kind;
    this.confirmTitle = title;
    this.confirmContent = content;
    this.showConfirm = true;
  }

  private runConfirm(): void {
    this.showConfirm = false;
    if (this.confirmKind === 'musicCache') {
      AppStorageUtil.clearDir(AppStorageUtil.cacheDir('music'));
      MediaCache.clear();
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.musicCacheCleared'), duration: 1500 });
    } else if (this.confirmKind === 'lyricCache') {
      AppStorageUtil.clearDir(AppStorageUtil.cacheDir('lyric'));
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.lyricCacheCleared'), duration: 1500 });
    } else if (this.confirmKind === 'imageCache') {
      AppStorageUtil.clearDir(AppStorageUtil.cacheDir('image'));
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.imageCacheCleared'), duration: 1500 });
    }
    this.refreshCacheSizes();
  }

  private applyCacheLimit(): void {
    let val = Number(this.cacheInput);
    if (Number.isNaN(val)) {
      return;
    }
    if (val < 100) {
      val = 100;
    } else if (val > 8192) {
      val = 8192;
    }
    this.maxCacheMb = val;
    AppConfig.setNumber(KEYS.MAX_CACHE_SIZE, val * 1024 * 1024);
    this.showCacheInput = false;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.cacheSetSuccess'), duration: 1500 });
  }

  private applyColor(color: string): void {
    this.showColor = false;
    if (this.colorKind === 'text') {
      this.lyricColor = color;
      AppConfig.setString(KEYS.LYRIC_COLOR, color);
    } else {
      this.lyricBg = color;
      AppConfig.setString(KEYS.LYRIC_BG, color);
    }
    FloatingLyric.publishStyle();
  }

  private copyLog(): void {
    const board = pasteboard.getSystemPasteboard();
    board.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.logText));
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.copiedToClipboard'), duration: 1500 });
  }

  private tabTitles(): string[] {
    const titles: string[] = [
      I18n.tx(this.appLocale, 'basicSettings.common'),
      I18n.tx(this.appLocale, 'basicSettings.sheetAndAlbum')
    ];
    if (!AppChannel.isStore()) {
      titles.push(I18n.tx(this.appLocale, 'basicSettings.plugin'));
    }
    titles.push(I18n.tx(this.appLocale, 'basicSettings.playback'));
    if (!AppChannel.isStore()) {
      titles.push(I18n.tx(this.appLocale, 'basicSettings.download'));
    }
    titles.push(I18n.tx(this.appLocale, 'basicSettings.network'));
    titles.push(I18n.tx(this.appLocale, 'basicSettings.lyric'));
    titles.push(I18n.tx(this.appLocale, 'basicSettings.cache'));
    titles.push(I18n.tx(this.appLocale, 'basicSettings.developer'));
    return titles;
  }

  private musicOrderLabel(): string {
    if (this.musicOrder === 'artist') {
      return I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.artist');
    }
    if (this.musicOrder === 'album') {
      return I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.album');
    }
    if (this.musicOrder === 'time') {
      return I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.newest');
    }
    if (this.musicOrder === 'time-rev') {
      return I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.oldest');
    }
    return I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.title');
  }

  private alignLabel(): string {
    if (this.lyricAlign === 0) {
      return I18n.tx(this.appLocale, 'basicSettings.lyric.align.left');
    }
    if (this.lyricAlign === 2) {
      return I18n.tx(this.appLocale, 'basicSettings.lyric.align.right');
    }
    return I18n.tx(this.appLocale, 'basicSettings.lyric.align.center');
  }

  private pickerLabelOf(value: string): string {
    const idx = this.pickerValues.indexOf(value);
    if (idx >= 0 && idx < this.pickerLabels.length) {
      return this.pickerLabels[idx];
    }
    return value;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        AppNavBar({ title: I18n.tx(this.appLocale, 'sidebar.basicSettings'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Row() {
          ForEach(this.tabTitles(), (title: string) => {
            Text(title)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .padding({ left: 12, right: 12 })
          }, (title: string) => `tab-${title}-${this.appLocale}`)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(40)

      Scroll() {
        Column() {
          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.common'))
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.maxHistoryLength'), `${this.maxHistoryLen}`, () => {
            this.openPicker('history', I18n.tx(this.appLocale, 'basicSettings.maxHistoryLength'),
              ['20', '50', '100', '200', '500'], ['20', '50', '100', '200', '500'], `${this.maxHistoryLen}`);
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault'),
            this.detailDefault === 'lyric' ? I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.lyric') : I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.album'),
            () => {
              this.openPicker('detailDefault', I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault'),
                ['album', 'lyric'],
                [I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.album'), I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.lyric')],
                this.detailDefault);
            })
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.musicDetailAwake'), '', this.musicDetailAwake, (on: boolean) => {
            this.musicDetailAwake = on;
            AppConfig.setBool(KEYS.MUSIC_DETAIL_AWAKE, on);
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.associateLyricType'),
            this.associateLyricType === 'input' ? I18n.tx(this.appLocale, 'basicSettings.associateLyricType.input') : I18n.tx(this.appLocale, 'basicSettings.associateLyricType.search'),
            () => {
              this.openPicker('associateLyric', I18n.tx(this.appLocale, 'basicSettings.associateLyricType'),
                ['input', 'search'],
                [I18n.tx(this.appLocale, 'basicSettings.associateLyricType.input'), I18n.tx(this.appLocale, 'basicSettings.associateLyricType.search')],
                this.associateLyricType);
            })
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.showExitOnNotification'), '', this.showExitOnNotification, (on: boolean) => {
            this.showExitOnNotification = on;
            AppConfig.setBool(KEYS.SHOW_EXIT_NOTIFICATION, on);
          })

          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.sheetAndAlbum'))
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.clickMusicInSearch'),
            this.clickSearch === 'playMusicAndReplace' ? I18n.tx(this.appLocale, 'basicSettings.clickMusicInSearch.playMusicAndReplace') : I18n.tx(this.appLocale, 'basicSettings.clickMusicInSearch.playMusic'),
            () => {
              this.openPicker('clickSearch', I18n.tx(this.appLocale, 'basicSettings.clickMusicInSearch'),
                ['playMusic', 'playMusicAndReplace'],
                [I18n.tx(this.appLocale, 'basicSettings.clickMusicInSearch.playMusic'), I18n.tx(this.appLocale, 'basicSettings.clickMusicInSearch.playMusicAndReplace')],
                this.clickSearch);
            })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.clickMusicInAlbum'),
            this.clickAlbum === 'playMusic' ? I18n.tx(this.appLocale, 'basicSettings.clickMusicInAlbum.playMusic') : I18n.tx(this.appLocale, 'basicSettings.clickMusicInAlbum.playAlbum'),
            () => {
              this.openPicker('clickAlbum', I18n.tx(this.appLocale, 'basicSettings.clickMusicInAlbum'),
                ['playMusic', 'playAlbum'],
                [I18n.tx(this.appLocale, 'basicSettings.clickMusicInAlbum.playMusic'), I18n.tx(this.appLocale, 'basicSettings.clickMusicInAlbum.playAlbum')],
                this.clickAlbum);
            })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault'),
            this.detailDefault === 'lyric' ? I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.lyric') : I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.album'),
            () => {
              this.openPicker('detailDefault', I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault'),
                ['album', 'lyric'],
                [I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.album'), I18n.tx(this.appLocale, 'basicSettings.musicDetailDefault.lyric')],
                this.detailDefault);
            })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet'), this.musicOrderLabel(), () => {
            this.openPicker('musicOrder', I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet'),
              ['title', 'artist', 'album', 'time', 'time-rev'],
              [
                I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.title'),
                I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.artist'),
                I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.album'),
                I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.newest'),
                I18n.tx(this.appLocale, 'basicSettings.musicOrderInLocalSheet.oldest')
              ], this.musicOrder);
          })

          if (!AppChannel.isStore()) {
            this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.plugin'))
            this.switchRow(I18n.tx(this.appLocale, 'basicSettings.autoUpdatePlugin'), '', this.autoUpdatePlugin, (on: boolean) => {
              this.autoUpdatePlugin = on;
              AppConfig.setBool(KEYS.AUTO_UPDATE_PLUGIN, on);
            })
            this.switchRow(I18n.tx(this.appLocale, 'basicSettings.notCheckPluginVersion'), '', this.notCheckPluginVersion, (on: boolean) => {
              this.notCheckPluginVersion = on;
              AppConfig.setBool(KEYS.NOT_CHECK_PLUGIN_VERSION, on);
            })
            this.switchRow(I18n.tx(this.appLocale, 'basicSettings.lazyLoadPlugin'), '', this.lazyLoadPlugin, (on: boolean) => {
              this.lazyLoadPlugin = on;
              AppConfig.setBool(KEYS.LAZY_LOAD_PLUGIN, on);
            })
          }

          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.playback'))
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.notInterrupt'), '', this.notInterrupt, (on: boolean) => {
            this.notInterrupt = on;
            AppConfig.setBool(KEYS.NOT_INTERRUPT, on);
          })
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.autoPlayWhenAppStart'), '', this.autoPlay, (on: boolean) => {
            this.autoPlay = on;
            AppConfig.setBool(KEYS.AUTO_PLAY, on);
          })
          if (!AppChannel.isStore()) {
            this.switchRow(I18n.tx(this.appLocale, 'basicSettings.tryChangeSourceWhenPlayFail'), '', this.tryChangeSource, (on: boolean) => {
              this.tryChangeSource = on;
              AppConfig.setBool(KEYS.TRY_CHANGE_SOURCE, on);
            })
          }
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.autoStopWhenError'), '', this.autoStopError, (on: boolean) => {
            this.autoStopError = on;
            AppConfig.setBool(KEYS.AUTO_STOP_ERROR, on);
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck'),
            this.tempRemoteDuck === 'lowerVolume' ? I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck.lowerVolume') : I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck.pause'),
            () => {
              this.openPicker('tempRemoteDuck', I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck'),
                ['pause', 'lowerVolume'],
                [I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck.pause'), I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck.lowerVolume')],
                this.tempRemoteDuck);
            })
          if (this.tempRemoteDuck === 'lowerVolume') {
            this.valueRow(I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck.volumeDecreaseLevel'), `${Math.round(this.tempRemoteDuckVolume * 100)}%`, () => {
              this.openPicker('duckVolume', I18n.tx(this.appLocale, 'basicSettings.tempRemoteDuck.volumeDecreaseLevel'),
                ['0.3', '0.5', '0.8'], ['30%', '50%', '80%'], `${this.tempRemoteDuckVolume}`);
            })
          }
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.defaultPlayQuality'), this.qualityLabel(this.playQuality), () => {
            this.openPicker('playQuality', I18n.tx(this.appLocale, 'basicSettings.defaultPlayQuality'),
              QUALITIES,
              [this.qualityLabel('low'), this.qualityLabel('standard'), this.qualityLabel('high'), this.qualityLabel('super')],
              this.playQuality);
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.playQualityOrder'),
            this.playQualityOrder === 'desc' ? I18n.tx(this.appLocale, 'basicSettings.playQualityOrder.desc') : I18n.tx(this.appLocale, 'basicSettings.playQualityOrder.asc'),
            () => {
              this.openPicker('playQualityOrder', I18n.tx(this.appLocale, 'basicSettings.playQualityOrder'),
                ['asc', 'desc'],
                [I18n.tx(this.appLocale, 'basicSettings.playQualityOrder.asc'), I18n.tx(this.appLocale, 'basicSettings.playQualityOrder.desc')],
                this.playQualityOrder);
            })

          if (!AppChannel.isStore()) {
            this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.download'))
            this.valueRow(I18n.tx(this.appLocale, 'basicSettings.downloadPath'), this.downloadPath, () => {
              promptAction.showToast({ message: this.downloadPath, duration: 2500 });
            })
            this.valueRow(I18n.tx(this.appLocale, 'basicSettings.maxDownload'), `${this.maxDownload}`, () => {
              this.openPicker('maxDownload', I18n.tx(this.appLocale, 'basicSettings.maxDownload'),
                ['1', '3', '5', '7'], ['1', '3', '5', '7'], `${this.maxDownload}`);
            })
            this.valueRow(I18n.tx(this.appLocale, 'basicSettings.defaultDownloadQuality'), this.qualityLabel(this.downloadQuality), () => {
              this.openPicker('downloadQuality', I18n.tx(this.appLocale, 'basicSettings.defaultDownloadQuality'),
                QUALITIES,
                [this.qualityLabel('low'), this.qualityLabel('standard'), this.qualityLabel('high'), this.qualityLabel('super')],
                this.downloadQuality);
            })
            this.valueRow(I18n.tx(this.appLocale, 'basicSettings.downloadQualityOrder'),
              this.downloadQualityOrder === 'desc' ? I18n.tx(this.appLocale, 'basicSettings.downloadQualityOrder.desc') : I18n.tx(this.appLocale, 'basicSettings.downloadQualityOrder.asc'),
              () => {
                this.openPicker('downloadQualityOrder', I18n.tx(this.appLocale, 'basicSettings.downloadQualityOrder'),
                  ['asc', 'desc'],
                  [I18n.tx(this.appLocale, 'basicSettings.downloadQualityOrder.asc'), I18n.tx(this.appLocale, 'basicSettings.downloadQualityOrder.desc')],
                  this.downloadQualityOrder);
              })
          }

          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.network'))
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.useCelluarNetworkPlay'), '', this.cellularPlay, (on: boolean) => {
            this.cellularPlay = on;
            AppConfig.setBool(KEYS.CELLULAR_PLAY, on);
          })
          if (!AppChannel.isStore()) {
            this.switchRow(I18n.tx(this.appLocale, 'basicSettings.useCelluarNetworkDownload'), '', this.cellularDownload, (on: boolean) => {
              this.cellularDownload = on;
              AppConfig.setBool(KEYS.CELLULAR_DOWNLOAD, on);
            })
          }

          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.lyric'))
          if (!AppChannel.isStore()) {
            this.switchRow(I18n.tx(this.appLocale, 'basicSettings.lyric.autoSearchLyric'), '', this.autoSearchLyric, (on: boolean) => {
              this.autoSearchLyric = on;
              AppConfig.setBool(KEYS.AUTO_SEARCH_LYRIC, on);
            })
          }
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.lyric.showStatusBarLyric'), '', this.desktopLyric, (on: boolean) => {
            this.desktopLyric = on;
            FloatingLyric.setEnabled(on);
            AppConfig.setBool(KEYS.SHOW_STATUS_BAR_LYRIC, on);
          })
          this.sliderRow(I18n.tx(this.appLocale, 'basicSettings.lyric.leftRightDistance'), this.lyricLeft, (v: number) => {
            this.lyricLeft = v;
            AppConfig.setNumber(KEYS.LYRIC_LEFT, v);
            FloatingLyric.publishStyle();
          })
          this.sliderRow(I18n.tx(this.appLocale, 'basicSettings.lyric.topBottomDistance'), this.lyricTop, (v: number) => {
            this.lyricTop = v;
            AppConfig.setNumber(KEYS.LYRIC_TOP, v);
            FloatingLyric.publishStyle();
          })
          this.sliderRow(I18n.tx(this.appLocale, 'basicSettings.lyric.width'), this.lyricWidth, (v: number) => {
            this.lyricWidth = v;
            AppConfig.setNumber(KEYS.LYRIC_WIDTH, v);
            FloatingLyric.publishStyle();
          })
          this.sliderRow(I18n.tx(this.appLocale, 'basicSettings.lyric.fontSize'), (this.lyricFont - 12) / 16, (v: number) => {
            this.lyricFont = 12 + v * 16;
            AppConfig.setNumber(KEYS.LYRIC_FONT, this.lyricFont);
            FloatingLyric.publishStyle();
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.lyric.align'), this.alignLabel(), () => {
            this.openPicker('lyricAlign', I18n.tx(this.appLocale, 'basicSettings.lyric.align'),
              ['0', '1', '2'],
              [I18n.tx(this.appLocale, 'basicSettings.lyric.align.left'), I18n.tx(this.appLocale, 'basicSettings.lyric.align.center'), I18n.tx(this.appLocale, 'basicSettings.lyric.align.right')],
              `${this.lyricAlign}`);
          })
          this.colorRow(I18n.tx(this.appLocale, 'basicSettings.lyric.textColor'), this.lyricColor, () => {
            this.colorKind = 'text';
            this.showColor = true;
          })
          this.colorRow(I18n.tx(this.appLocale, 'basicSettings.lyric.backgroundColor'), this.lyricBg, () => {
            this.colorKind = 'bg';
            this.showColor = true;
          })

          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.cache'))
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.cache.musicCacheLimit'), `${this.maxCacheMb}M`, () => {
            this.cacheInput = `${this.maxCacheMb}`;
            this.showCacheInput = true;
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.cache.clearMusicCache'), this.musicCacheSize, () => {
            this.openConfirm('musicCache', I18n.tx(this.appLocale, 'dialog.clearMusicCacheTitle'), I18n.tx(this.appLocale, 'dialog.clearMusicCacheContent'));
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.cache.clearLyricCache'), this.lyricCacheSize, () => {
            this.openConfirm('lyricCache', I18n.tx(this.appLocale, 'dialog.clearLyricCacheTitle'), I18n.tx(this.appLocale, 'dialog.clearLyricCacheContent'));
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.cache.clearImageCache'), this.imageCacheSize, () => {
            this.openConfirm('imageCache', I18n.tx(this.appLocale, 'dialog.clearImageCacheTitle'), I18n.tx(this.appLocale, 'dialog.clearImageCacheContent'));
          })

          this.sectionTitle(I18n.tx(this.appLocale, 'basicSettings.developer'))
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.developer.errorLog'), '', this.debugErrorLog, (on: boolean) => {
            this.debugErrorLog = on;
            AppConfig.setBool(KEYS.DEBUG_ERROR_LOG, on);
          })
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.developer.traceLog'), '', this.debugTraceLog, (on: boolean) => {
            this.debugTraceLog = on;
            AppConfig.setBool(KEYS.DEBUG_TRACE_LOG, on);
          })
          this.switchRow(I18n.tx(this.appLocale, 'basicSettings.developer.devLog'), '', this.debugDevLog, (on: boolean) => {
            this.debugDevLog = on;
            AppConfig.setBool(KEYS.DEBUG_DEV_LOG, on);
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.developer.viewErrorLog'), '', () => {
            this.logText = AppStorageUtil.readErrorLog();
            this.showLog = true;
          })
          this.valueRow(I18n.tx(this.appLocale, 'basicSettings.developer.clearLog'), '', () => {
            AppStorageUtil.clearErrorLog();
            promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.logCleared'), duration: 1500 });
          })
        }
        .width('100%')
        .padding({ bottom: 32 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground)

      if (this.showPicker) {
        this.pickerOverlay()
      }
      if (this.showConfirm) {
        this.confirmOverlay()
      }
      if (this.showCacheInput) {
        this.cacheInputOverlay()
      }
      if (this.showColor) {
        this.colorOverlay()
      }
      if (this.showLog) {
        this.logOverlay()
      }
    }
    .id(`basic-${this.appLocale}`)
    .width('100%')
    .height('100%')
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.textSecondary)
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 4 })
  }

  @Builder
  switchRow(title: string, desc: string, isOn: boolean, onChange: (on: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor(this.textColor)
        if (desc.length > 0) {
          Text(desc).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.primary)
        .onChange(onChange)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  valueRow(title: string, value: string, action: () => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.textColor).layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor(this.textSecondary)
        .maxLines(2)
        .textAlign(TextAlign.End)
        .constraintSize({ maxWidth: '46%' })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(action)
  }

  @Builder
  colorRow(title: string, color: string, action: () => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.textColor).layoutWeight(1)
      Column()
        .width(22)
        .height(22)
        .borderRadius(4)
        .backgroundColor(color)
        .border({ width: 1, color: this.divider })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(action)
  }

  @Builder
  sliderRow(title: string, value: number, onChange: (v: number) => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.textColor).width(88)
      Slider({ value: value, min: 0, max: 1, step: 0.01 })
        .layoutWeight(1)
        .selectedColor(this.primary)
        .trackColor(this.divider)
        .blockColor(this.primary)
        .onChange((v: number) => {
          onChange(v);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  pickerOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showPicker = false;
        })
      Column() {
        Row() {
          Text(this.pickerTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .layoutWeight(1)
          Row() {
            IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showPicker = false;
          })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 8 })
        ForEach(this.pickerValues, (value: string) => {
          Row() {
            Text(this.pickerLabelOf(value))
              .fontSize(15)
              .fontColor(this.textColor)
              .layoutWeight(1)
            if (this.pickerCurrent === value) {
              IconImg({ name: 'check', iconSize: 20, color: this.primary })
            }
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.applyPicker(value);
          })
        }, (value: string) => `pick-${this.pickerKind}-${value}`)
      }
      .width('100%')
      .padding({ bottom: 12 + this.gestureBarHeight })
      .backgroundColor(this.backdrop)
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
    .width('100%')
    .height('100%')
    .zIndex(30)
  }

  @Builder
  confirmOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showConfirm = false;
        })
      Column() {
        Text(this.confirmTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        Text(this.confirmContent)
          .fontSize(14)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 16 })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showConfirm = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.runConfirm();
            })
        }
        .width('100%')
      }
      .width('80%')
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
    .zIndex(30)
  }

  @Builder
  cacheInputOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showCacheInput = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'dialog.setCacheTitle'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ top: 16, bottom: 8 })
        TextInput({ placeholder: I18n.tx(this.appLocale, 'dialog.setCachePlaceholder'), text: this.cacheInput })
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .backgroundColor(this.placeholder)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.cacheInput = v;
          })
          .margin({ left: 16, right: 16, bottom: 12 })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 16 })
            .onClick(() => {
              this.showCacheInput = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 16 })
            .onClick(() => {
              this.applyCacheLimit();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ bottom: this.gestureBarHeight })
      .backgroundColor(this.backdrop)
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
    .width('100%')
    .height('100%')
    .zIndex(30)
  }

  @Builder
  colorOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showColor = false;
        })
      Column() {
        Text(this.colorKind === 'text' ? I18n.tx(this.appLocale, 'basicSettings.lyric.textColor') : I18n.tx(this.appLocale, 'basicSettings.lyric.backgroundColor'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ top: 16, bottom: 12 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['#FFE9D2FF', '#FFFFFFFF', '#FCFCFC', '#333333', '#000000', '#3FA3B5', '#FC5F5F', '#84888153', '#CC111111', '#00000000'], (c: string) => {
            Column()
              .width(36)
              .height(36)
              .margin(8)
              .borderRadius(6)
              .backgroundColor(c)
              .border({ width: 1, color: this.divider })
              .onClick(() => {
                this.applyColor(c);
              })
          }, (c: string) => `color-${c}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      }
      .width('100%')
      .padding({ bottom: this.gestureBarHeight })
      .backgroundColor(this.backdrop)
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
    .width('100%')
    .height('100%')
    .zIndex(30)
  }

  @Builder
  logOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showLog = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'dialog.errorLogTitle'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        Scroll() {
          Text(this.logText.length > 0 ? this.logText : I18n.tx(this.appLocale, 'dialog.errorLogNoRecord'))
            .fontSize(13)
            .fontColor(this.textColor)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 280 })
        .padding({ left: 20, right: 20 })
        Row() {
          Text(I18n.tx(this.appLocale, 'dialog.errorLogKnow'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showLog = false;
            })
          Text(I18n.tx(this.appLocale, 'dialog.errorLogCopy'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.copyLog();
            })
        }
        .width('100%')
      }
      .width('86%')
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
    .zIndex(30)
  }
}
