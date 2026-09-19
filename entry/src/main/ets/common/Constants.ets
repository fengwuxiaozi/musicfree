export const APP_NAME: string = 'MusicFree';
export const APP_VERSION: string = '1.0.0';
export const LOCAL_PLATFORM: string = '本地';
export const FAVORITE_SHEET_ID: string = 'favorite';
export const HISTORY_SHEET_ID: string = 'history';
export const LOCAL_SHEET_ID: string = 'local';

export class STORE_KEYS {
  static readonly currentTitle: string = 'currentTitle';
  static readonly currentArtist: string = 'currentArtist';
  static readonly currentArtwork: string = 'currentArtwork';
  static readonly currentAlbum: string = 'currentAlbum';
  static readonly isPlaying: string = 'isPlaying';
  static readonly position: string = 'position';
  static readonly duration: string = 'duration';
  static readonly lyricLine: string = 'lyricLine';
  static readonly hasMusic: string = 'hasMusic';
  static readonly playQuality: string = 'playQuality';
  static readonly playRate: string = 'playRate';
  static readonly themeDark: string = 'themeDark';
  static readonly primary: string = 'primary';
  static readonly pageBackground: string = 'pageBackground';
  static readonly textColor: string = 'textColor';
  static readonly textSecondary: string = 'textSecondary';
  static readonly textHint: string = 'textHint';
  static readonly appBar: string = 'appBar';
  static readonly appBarText: string = 'appBarText';
  static readonly musicBar: string = 'musicBar';
  static readonly musicBarText: string = 'musicBarText';
  static readonly card: string = 'card';
  static readonly placeholder: string = 'placeholder';
  static readonly divider: string = 'divider';
  static readonly mask: string = 'mask';
  static readonly backdrop: string = 'backdrop';
  static readonly danger: string = 'danger';
  static readonly tabBar: string = 'tabBar';
  static readonly toastMsg: string = 'toastMsg';
  static readonly downloadTick: string = 'downloadTick';
  static readonly bgUrl: string = 'bgUrl';
  static readonly bgBlur: string = 'bgBlur';
  static readonly bgOpacity: string = 'bgOpacity';
  static readonly themeRev: string = 'themeRev';
  static readonly localeRev: string = 'localeRev';
  static readonly lyricTick: string = 'lyricTick';
}

export class ROUTES {
  static readonly SEARCH: string = 'search';
  static readonly MUSIC_DETAIL: string = 'music-detail';
  static readonly SHEET_DETAIL: string = 'sheet-detail';
  static readonly SETTING: string = 'setting';
  static readonly PLUGIN: string = 'plugin';
  static readonly THEME: string = 'theme';
  static readonly ABOUT: string = 'about';
  static readonly HISTORY: string = 'history';
  static readonly LOCAL: string = 'local';
  static readonly TOP_LIST: string = 'top-list';
  static readonly TOP_LIST_DETAIL: string = 'top-list-detail';
  static readonly RECOMMEND: string = 'recommend-sheets';
  static readonly PLUGIN_SHEET: string = 'plugin-sheet-detail';
  static readonly ALBUM: string = 'album-detail';
  static readonly ARTIST: string = 'artist-detail';
  static readonly BACKUP: string = 'backup';
  static readonly BASIC: string = 'basic-setting';
  static readonly DOWNLOADING: string = 'downloading';
  static readonly SET_CUSTOM_THEME: string = 'set-custom-theme';
  static readonly PLUGIN_SUBSCRIBE: string = 'plugin-subscribe';
  static readonly PLUGIN_SORT: string = 'plugin-sort';
  static readonly SEARCH_LYRIC: string = 'search-lyric';
  static readonly MUSIC_LIST_EDITOR: string = 'music-list-editor';
  static readonly SEARCH_MUSIC_LIST: string = 'search-music-list';
  static readonly PERMISSIONS: string = 'permissions';
  static readonly MUSIC_COMMENT: string = 'music-comment';
  static readonly IMPORT_SHEET: string = 'import-sheet';
}

export const WEBDAV_DIR: string = '/MusicFree';
export const WEBDAV_FILE: string = '/MusicFree/MusicFreeBackup.json';
export const WEBDAV_FILE_FALLBACK: string = '/MusicFreeBackup.json';

export const QUALITIES: string[] = ['low', 'standard', 'high', 'super'];

export enum RepeatMode {
  QUEUE = 0,
  SINGLE = 1,
  SHUFFLE = 2
}

export enum ResumeMode {
  APPEND = 'append',
  OVERWRITE_DEFAULT = 'overwrite-default',
  OVERWRITE = 'overwrite'
}

export const SEARCH_TYPES: string[] = ['music', 'album', 'artist', 'sheet'];

export const SEARCH_TYPE_LABELS: string[] = ['单曲', '专辑', '作者', '歌单'];
