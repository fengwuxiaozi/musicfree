import { AppStorageUtil } from './AppStorageUtil';

/** 与原版 IAppConfigProperties 对齐的常用键，供页面直接引用。 */
export class KEYS {
  static AUTO_PLAY: string = 'basic.autoPlayWhenAppStart';
  static TRY_CHANGE_SOURCE: string = 'basic.tryChangeSourceWhenPlayFail';
  static PLAY_QUALITY: string = 'basic.defaultPlayQuality';
  static DOWNLOAD_QUALITY: string = 'basic.defaultDownloadQuality';
  static MAX_HISTORY: string = 'basic.maxHistoryLen';
  static AUTO_UPDATE_PLUGIN: string = 'basic.autoUpdatePlugin';
  static MAX_DOWNLOAD: string = 'basic.maxDownload';
  static CLICK_SEARCH: string = 'basic.clickMusicInSearch';
  static AUTO_SEARCH_LYRIC: string = 'lyric.autoSearchLyric';
  static SHOW_STATUS_BAR_LYRIC: string = 'lyric.showStatusBarLyric';
  static DETAIL_FONT_SIZE: string = 'lyric.detailFontSize';
  static LANGUAGE: string = 'basic.language';
  static CLICK_ALBUM: string = 'basic.clickMusicInAlbum';
  static DETAIL_DEFAULT: string = 'basic.musicDetailDefault';
  static AUTO_STOP_ERROR: string = 'basic.autoStopWhenError';
  static MUSIC_DETAIL_AWAKE: string = 'basic.musicDetailAwake';
  static ASSOCIATE_LYRIC_TYPE: string = 'basic.associateLyricType';
  static SHOW_EXIT_NOTIFICATION: string = 'basic.showExitOnNotification';
  static MUSIC_ORDER: string = 'basic.musicOrderInLocalSheet';
  static NOT_CHECK_PLUGIN_VERSION: string = 'basic.notCheckPluginVersion';
  static LAZY_LOAD_PLUGIN: string = 'basic.lazyLoadPlugin';
  static NOT_INTERRUPT: string = 'basic.notInterrupt';
  static TEMP_REMOTE_DUCK: string = 'basic.tempRemoteDuck';
  static TEMP_REMOTE_DUCK_VOLUME: string = 'basic.tempRemoteDuckVolume';
  static PLAY_QUALITY_ORDER: string = 'basic.playQualityOrder';
  static DOWNLOAD_PATH: string = 'basic.downloadPath';
  static DOWNLOAD_QUALITY_ORDER: string = 'basic.downloadQualityOrder';
  static CELLULAR_PLAY: string = 'basic.useCelluarNetworkPlay';
  static CELLULAR_DOWNLOAD: string = 'basic.useCelluarNetworkDownload';
  static MAX_CACHE_SIZE: string = 'basic.maxCacheSize';
  static LYRIC_TOP: string = 'lyric.topPercent';
  static LYRIC_LEFT: string = 'lyric.leftPercent';
  static LYRIC_ALIGN: string = 'lyric.align';
  static LYRIC_COLOR: string = 'lyric.color';
  static LYRIC_BG: string = 'lyric.backgroundColor';
  static LYRIC_WIDTH: string = 'lyric.widthPercent';
  static LYRIC_FONT: string = 'lyric.fontSize';
  static DEBUG_ERROR_LOG: string = 'debug.errorLog';
  static DEBUG_TRACE_LOG: string = 'debug.traceLog';
  static DEBUG_DEV_LOG: string = 'debug.devLog';
}

/**
 * 应用配置。每个键独立持久化到 preferences（cfg.xxx），避免整包 JSON 解析失败。
 * 真正的启动自动播放等行为由 AppService 接线，这里只负责存取。
 */
export class AppConfig {
  private static UNSET: string = '__MF_UNSET__';
  private static cache: Record<string, string> = {};
  private static present: Record<string, boolean> = {};

  static async load(): Promise<void> {
    const keys: string[] = AppConfig.allKeys();
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const raw = await AppStorageUtil.getString(AppConfig.prefKey(key), AppConfig.UNSET);
      if (raw !== AppConfig.UNSET) {
        AppConfig.cache[key] = raw;
        AppConfig.present[key] = true;
      }
    }
  }

  static getBool(key: string, fallback: boolean): boolean {
    if (AppConfig.present[key] !== true) {
      return fallback;
    }
    const v = AppConfig.cache[key];
    if (v === '1' || v === 'true') {
      return true;
    }
    if (v === '0' || v === 'false') {
      return false;
    }
    return fallback;
  }

  static getString(key: string, fallback: string): string {
    if (AppConfig.present[key] !== true) {
      return fallback;
    }
    return AppConfig.cache[key];
  }

  static getNumber(key: string, fallback: number): number {
    if (AppConfig.present[key] !== true) {
      return fallback;
    }
    const n = Number(AppConfig.cache[key]);
    if (Number.isNaN(n)) {
      return fallback;
    }
    return n;
  }

  static setBool(key: string, value: boolean): void {
    AppConfig.setString(key, value ? '1' : '0');
  }

  static setString(key: string, value: string): void {
    AppConfig.cache[key] = value;
    AppConfig.present[key] = true;
    AppStorageUtil.setString(AppConfig.prefKey(key), value);
  }

  static setNumber(key: string, value: number): void {
    AppConfig.setString(key, `${value}`);
  }

  private static prefKey(key: string): string {
    return `cfg.${key}`;
  }

  private static allKeys(): string[] {
    return [
      KEYS.AUTO_PLAY,
      KEYS.TRY_CHANGE_SOURCE,
      KEYS.PLAY_QUALITY,
      KEYS.DOWNLOAD_QUALITY,
      KEYS.MAX_HISTORY,
      KEYS.AUTO_UPDATE_PLUGIN,
      KEYS.MAX_DOWNLOAD,
      KEYS.CLICK_SEARCH,
      KEYS.AUTO_SEARCH_LYRIC,
      KEYS.SHOW_STATUS_BAR_LYRIC,
      KEYS.DETAIL_FONT_SIZE,
      KEYS.LANGUAGE,
      KEYS.CLICK_ALBUM,
      KEYS.DETAIL_DEFAULT,
      KEYS.AUTO_STOP_ERROR,
      KEYS.MUSIC_DETAIL_AWAKE,
      KEYS.ASSOCIATE_LYRIC_TYPE,
      KEYS.SHOW_EXIT_NOTIFICATION,
      KEYS.MUSIC_ORDER,
      KEYS.NOT_CHECK_PLUGIN_VERSION,
      KEYS.LAZY_LOAD_PLUGIN,
      KEYS.NOT_INTERRUPT,
      KEYS.TEMP_REMOTE_DUCK,
      KEYS.TEMP_REMOTE_DUCK_VOLUME,
      KEYS.PLAY_QUALITY_ORDER,
      KEYS.DOWNLOAD_PATH,
      KEYS.DOWNLOAD_QUALITY_ORDER,
      KEYS.CELLULAR_PLAY,
      KEYS.CELLULAR_DOWNLOAD,
      KEYS.MAX_CACHE_SIZE,
      KEYS.LYRIC_TOP,
      KEYS.LYRIC_LEFT,
      KEYS.LYRIC_ALIGN,
      KEYS.LYRIC_COLOR,
      KEYS.LYRIC_BG,
      KEYS.LYRIC_WIDTH,
      KEYS.LYRIC_FONT,
      KEYS.DEBUG_ERROR_LOG,
      KEYS.DEBUG_TRACE_LOG,
      KEYS.DEBUG_DEV_LOG
    ];
  }
}
