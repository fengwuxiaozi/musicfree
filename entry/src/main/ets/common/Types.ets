export class MusicItem {
  id: string = '';
  platform: string = '';
  artist: string = '';
  title: string = '';
  album: string = '';
  artwork: string = '';
  duration: number = 0;
  url: string = '';
  rawJson: string = '{}';

  static fromJson(text: string): MusicItem {
    const item = new MusicItem();
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      item.id = str(obj['id']);
      item.platform = str(obj['platform']);
      item.artist = namedText(obj['artist'], ['name', 'title', 'artist']);
      item.title = str(obj['title']);
      item.album = namedText(obj['album'], ['title', 'name', 'album']);
      item.artwork = firstStr(obj, ['artwork', 'coverImg', 'pic', 'picUrl']);
      item.duration = num(obj['duration']);
      item.url = firstStr(obj, ['url', 'soundurl']);
      item.rawJson = pickRawJson(obj, text);
    } catch (_e) {
    }
    return item;
  }

  static fromObj(obj: Record<string, Object>): MusicItem {
    return MusicItem.fromJson(JSON.stringify(obj));
  }

  key(): string {
    return `${this.platform}::${this.id}`;
  }

  sameAs(other: MusicItem | null): boolean {
    if (other === null) {
      return false;
    }
    return this.platform === other.platform && this.id === other.id;
  }

  toPluginJson(): string {
    return this.rawJson && this.rawJson !== '{}' ? this.rawJson : JSON.stringify({
      'id': this.id,
      'platform': this.platform,
      'artist': this.artist,
      'title': this.title,
      'album': this.album,
      'artwork': this.artwork,
      'duration': this.duration,
      'url': this.url
    });
  }
}

export class SheetItem {
  id: string = '';
  platform: string = '';
  title: string = '';
  artist: string = '';
  coverImg: string = '';
  worksNum: number = 0;
  description: string = '';
  kind: string = '';
  rawJson: string = '{}';

  static fromJson(text: string): SheetItem {
    const item = new SheetItem();
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      item.id = str(obj['id']);
      item.platform = str(obj['platform']);
      item.title = str(obj['title']);
      item.artist = namedText(obj['artist'], ['name', 'title', 'artist']);
      item.coverImg = firstStr(obj, ['coverImg', 'artwork', 'pic', 'picUrl']);
      item.worksNum = num(obj['worksNum']) > 0 ? num(obj['worksNum']) : num(obj['playCount']);
      item.description = str(obj['description']);
      item.kind = str(obj['kind']);
      item.rawJson = pickRawJson(obj, text);
    } catch (_e) {
    }
    return item;
  }

  toPluginJson(): string {
    if (this.rawJson.length > 0 && this.rawJson !== '{}') {
      return injectPlatformField(this.rawJson, this.platform, this.id);
    }
    return JSON.stringify({
      'id': this.id,
      'platform': this.platform,
      'title': this.title,
      'artist': this.artist,
      'coverImg': this.coverImg,
      'artwork': this.coverImg,
      'description': this.description,
      'worksNum': this.worksNum
    });
  }
}

export class SheetPageResult {
  musics: MusicItem[] = [];
  isEnd: boolean = true;
  title: string = '';
  coverImg: string = '';
  description: string = '';
  worksNum: number = 0;
}

export class AlbumItem {
  id: string = '';
  platform: string = '';
  title: string = '';
  artist: string = '';
  artwork: string = '';
  rawJson: string = '{}';

  static fromJson(text: string): AlbumItem {
    const item = new AlbumItem();
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      item.id = str(obj['id']);
      item.platform = str(obj['platform']);
      item.title = str(obj['title']);
      item.artist = namedText(obj['artist'], ['name', 'title', 'artist']);
      item.artwork = firstStr(obj, ['artwork', 'coverImg', 'pic']);
      item.rawJson = pickRawJson(obj, text);
    } catch (_e) {
    }
    return item;
  }

  toPluginJson(): string {
    if (this.rawJson.length > 0 && this.rawJson !== '{}') {
      return injectPlatformField(this.rawJson, this.platform, this.id);
    }
    return JSON.stringify({
      'id': this.id,
      'platform': this.platform,
      'title': this.title,
      'artist': this.artist,
      'artwork': this.artwork
    });
  }
}

export class ArtistItem {
  id: string = '';
  platform: string = '';
  name: string = '';
  avatar: string = '';
  worksNum: number = 0;
  rawJson: string = '{}';

  static fromJson(text: string): ArtistItem {
    const item = new ArtistItem();
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      item.id = str(obj['id']);
      item.platform = str(obj['platform']);
      item.name = firstStr(obj, ['name', 'title', 'artist']);
      item.avatar = firstStr(obj, ['avatar', 'artwork', 'pic']);
      item.worksNum = num(obj['worksNum']);
      item.rawJson = pickRawJson(obj, text);
    } catch (_e) {
    }
    return item;
  }

  toPluginJson(): string {
    if (this.rawJson.length > 0 && this.rawJson !== '{}') {
      return injectPlatformField(this.rawJson, this.platform, this.id);
    }
    return JSON.stringify({
      'id': this.id,
      'platform': this.platform,
      'name': this.name,
      'avatar': this.avatar,
      'worksNum': this.worksNum
    });
  }
}

export class PluginUserVar {
  key: string = '';
  name: string = '';
  hint: string = '';
}

export class PluginMeta {
  hash: string = '';
  platform: string = '';
  version: string = '';
  author: string = '';
  srcUrl: string = '';
  path: string = '';
  enabled: boolean = true;
  methods: string[] = [];
  supportedSearchType: string[] = [];
  state: string = 'mounted';
  errorMsg: string = '';
  order: number = 0;
  description: string = '';
  cacheControl: string = '';
  alternativePlugin: string = '';
  userVariables: PluginUserVar[] = [];
  userVariableValues: Record<string, string> = {};
  hintsImportMusic: string = '';
  hintsImportSheet: string = '';
}

export class CommentItem {
  id: string = '';
  nickName: string = '';
  avatar: string = '';
  comment: string = '';
  like: number = 0;
  createAt: number = 0;
  location: string = '';
  replies: CommentItem[] = [];
}

export class RecommendTag {
  id: string = '';
  title: string = '';
  urlSlug: string = '';
}

export class RecommendTagGroup {
  title: string = '';
  data: RecommendTag[] = [];
}

export class RecommendTagsResult {
  pinned: RecommendTag[] = [];
  data: RecommendTagGroup[] = [];
}

export class InstallPluginResult {
  success: boolean = false;
  message: string = '';
  pluginUrl: string = '';
  pluginName: string = '';
}

export class LyricLine {
  time: number = 0;
  text: string = '';
  translation: string = '';
}

export class LyricSource {
  rawLrc: string = '';
  translation: string = '';
}

export class MediaSource {
  url: string = '';
  userAgent: string = '';
  headers: Record<string, string> = {};
}

export class TopListGroup {
  title: string = '';
  data: SheetItem[] = [];
}

function str(v: Object | undefined): string {
  if (v === undefined || v === null) {
    return '';
  }
  return `${v}`;
}

function num(v: Object | undefined): number {
  if (typeof v === 'number') {
    return v as number;
  }
  const n = Number(str(v));
  return Number.isNaN(n) ? 0 : n;
}

function pickRawJson(obj: Record<string, Object>, fallback: string): string {
  const nested = obj['rawJson'];
  if (nested !== undefined && nested !== null) {
    if (typeof nested === 'string') {
      const s = nested as string;
      if (s.length > 2 && s !== '{}') {
        return s;
      }
    } else if (typeof nested === 'object') {
      try {
        return JSON.stringify(nested);
      } catch (_e) {
      }
    }
  }
  return fallback;
}

function injectPlatformField(raw: string, platform: string, id: string): string {
  try {
    const obj = JSON.parse(raw) as Record<string, Object>;
    if (platform.length > 0 && `${obj['platform'] ?? ''}`.length === 0) {
      obj['platform'] = platform as Object;
    }
    if (id.length > 0 && `${obj['id'] ?? ''}`.length === 0) {
      obj['id'] = id as Object;
    }
    return JSON.stringify(obj);
  } catch (_e) {
    return raw;
  }
}

function firstStr(obj: Record<string, Object>, keys: string[]): string {
  for (let i = 0; i < keys.length; i++) {
    const v = obj[keys[i]];
    if (v !== undefined && v !== null && `${v}`.length > 0 && `${v}` !== '[object Object]') {
      return `${v}`;
    }
  }
  return '';
}

function namedText(v: Object | undefined, keys: string[]): string {
  if (v === undefined || v === null) {
    return '';
  }
  if (typeof v === 'object') {
    try {
      return firstStr(v as Record<string, Object>, keys);
    } catch (_e) {
      return '';
    }
  }
  return `${v}`;
}

export function asObjectArray(v: Object | undefined | null): Object[] {
  if (v === undefined || v === null) {
    return [];
  }
  try {
    const text: string = JSON.stringify(v);
    const parsed: Object = JSON.parse(text) as Object;
    if (Array.isArray(parsed)) {
      return parsed as Object[];
    }
  } catch (_e) {
  }
  return [];
}

export function parseMusicList(payload: string): MusicItem[] {
  const list: MusicItem[] = [];
  try {
    const parsed: Object = JSON.parse(payload) as Object;
    const arr = asObjectArray(parsed);
    for (let i = 0; i < arr.length; i++) {
      list.push(MusicItem.fromJson(JSON.stringify(arr[i])));
    }
  } catch (_e) {
  }
  return list;
}

export function serializeMusicList(list: MusicItem[]): string {
  const rows: Record<string, string | number>[] = [];
  for (let i = 0; i < list.length; i++) {
    const m = list[i];
    const row: Record<string, string | number> = {};
    row['id'] = m.id;
    row['platform'] = m.platform;
    row['artist'] = m.artist;
    row['title'] = m.title;
    row['album'] = m.album;
    row['artwork'] = m.artwork;
    row['duration'] = m.duration;
    row['url'] = m.url;
    row['rawJson'] = m.rawJson;
    rows.push(row);
  }
  return JSON.stringify(rows);
}

export function parseSheetList(payload: string): SheetItem[] {
  const list: SheetItem[] = [];
  try {
    const parsed: Object = JSON.parse(payload) as Object;
    const arr = asObjectArray(parsed);
    for (let i = 0; i < arr.length; i++) {
      list.push(SheetItem.fromJson(JSON.stringify(arr[i])));
    }
  } catch (_e) {
  }
  return list;
}
