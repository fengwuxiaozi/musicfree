import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MusicItem } from '../common/Types';
import { LOCAL_PLATFORM } from '../common/Constants';
import { AppStorageUtil } from './AppStorageUtil';
import { HttpUtil } from './HttpUtil';
import { PluginManager } from './PluginManager';

export class CoverService {
  static async ensure(item: MusicItem, plugins: PluginManager | null): Promise<string> {
    if (CoverService.hasUsable(item.artwork)) {
      return item.artwork;
    }
    CoverService.fillFromName(item);
    const cached = CoverService.cachedPath(item);
    if (AppStorageUtil.exists(cached)) {
      return CoverService.fileUri(cached);
    }
    const embedded = await CoverService.fromFile(item, cached);
    if (embedded.length > 0) {
      hilog.info(0x0000, 'MusicFreeCover', 'embedded %{public}s', item.title);
      return embedded;
    }
    if (plugins !== null) {
      const fromPlugin = await CoverService.fromPluginInfo(item, plugins);
      if (fromPlugin.length > 0) {
        return fromPlugin;
      }
    }
    const queries = CoverService.queries(item);
    for (let i = 0; i < queries.length; i++) {
      const remote = await CoverService.searchRemote(queries[i]);
      if (remote.length > 0) {
        const saved = await CoverService.download(remote, cached);
        if (saved.length > 0) {
          hilog.info(0x0000, 'MusicFreeCover', 'remote %{public}s', item.title);
          return saved;
        }
      }
    }
    if (plugins !== null) {
      const fromSearch = await CoverService.fromPluginSearch(item, plugins, queries);
      if (fromSearch.length > 0) {
        const saved = await CoverService.download(fromSearch, cached);
        if (saved.length > 0) {
          hilog.info(0x0000, 'MusicFreeCover', 'plugin %{public}s', item.title);
          return saved;
        }
      }
    }
    hilog.info(0x0000, 'MusicFreeCover', 'miss %{public}s', item.title);
    return '';
  }

  static hasUsable(artwork: string): boolean {
    const art = artwork.trim();
    if (art.length === 0) {
      return false;
    }
    if (art.indexOf('http://') === 0 || art.indexOf('https://') === 0) {
      return true;
    }
    const path = art.indexOf('file://') === 0 ? art.substring(7) : art;
    return AppStorageUtil.exists(path);
  }

  private static cachedPath(item: MusicItem): string {
    return `${AppStorageUtil.cacheDir('image')}/${CoverService.token(item)}.jpg`;
  }

  private static fileUri(path: string): string {
    if (path.indexOf('file://') === 0) {
      return path;
    }
    return `file://${path}`;
  }

  private static token(item: MusicItem): string {
    const raw = `${item.platform}|${item.id}|${item.url}`;
    let hash = 5381;
    for (let i = 0; i < raw.length; i++) {
      hash = ((hash << 5) + hash + raw.charCodeAt(i)) | 0;
    }
    return `c${hash >>> 0}`;
  }

  static isGenericName(name: string): boolean {
    const n = name.trim();
    if (n.length === 0) {
      return true;
    }
    const lower = n.toLowerCase();
    return n === '本地' || n === '本地音乐' || n === '未知作者' || n === '未知歌手' || n === '未知专辑' ||
      n === '未知歌曲' || lower === 'local' || lower === 'unknown' || lower === 'unknown artist' ||
      lower === 'local music';
  }

  static fillFromName(item: MusicItem): void {
    const cleaned = CoverService.stripIndex(item.title);
    const dash = CoverService.splitDash(cleaned);
    if (CoverService.isGenericName(item.artist) && dash !== null) {
      item.artist = dash[0];
      item.title = dash[1];
    } else if (cleaned !== item.title) {
      item.title = cleaned;
    }
  }

  private static stripIndex(title: string): string {
    let text = title.trim();
    let i = 0;
    while (i < text.length && text.charCodeAt(i) >= 48 && text.charCodeAt(i) <= 57) {
      i += 1;
    }
    if (i > 0 && i < text.length && (text[i] === ' ' || text[i] === '.' || text[i] === '-' || text[i] === '_')) {
      return text.substring(i + 1).trim();
    }
    return text;
  }

  private static splitDash(title: string): string[] | null {
    const marks: string[] = [' - ', '-', '—', '_'];
    for (let i = 0; i < marks.length; i++) {
      const idx = title.indexOf(marks[i]);
      if (idx <= 0) {
        continue;
      }
      const left = title.substring(0, idx).trim();
      const right = title.substring(idx + marks[i].length).trim();
      if (left.length > 0 && right.length > 0) {
        return [left, right];
      }
    }
    return null;
  }

  private static queries(item: MusicItem): string[] {
    const list: string[] = [];
    if (!CoverService.isGenericName(item.artist) && item.title.length > 0) {
      CoverService.pushQuery(list, `${item.artist} ${item.title}`);
    }
    if (!CoverService.isGenericName(item.album) && !CoverService.isGenericName(item.artist)) {
      CoverService.pushQuery(list, `${item.artist} ${item.album}`);
    }
    CoverService.pushQuery(list, item.title);
    return list;
  }

  private static pushQuery(list: string[], text: string): void {
    const q = CoverService.cleanSpaces(text);
    if (q.length === 0) {
      return;
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i] === q) {
        return;
      }
    }
    list.push(q);
  }

  private static cleanSpaces(text: string): string {
    let out = '';
    let space = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
        space = true;
        continue;
      }
      if (out.length > 0 && space) {
        out += ' ';
      }
      out += ch;
      space = false;
    }
    return out;
  }

  private static async fromFile(item: MusicItem, dest: string): Promise<string> {
    const uri = item.url.trim();
    if (uri.length === 0 || uri.indexOf('http://') === 0 || uri.indexOf('https://') === 0) {
      return '';
    }
    let file: fs.File | null = null;
    let extractor: media.AVMetadataExtractor | null = null;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = { fd: file.fd };
      try {
        const meta = await extractor.fetchMetadata();
        CoverService.applyFileMeta(item, meta);
      } catch (_e) {
      }
      try {
        const pixel = await extractor.fetchAlbumCover();
        const packed = await CoverService.packJpeg(pixel);
        pixel.release();
        if (packed !== null && packed.byteLength > 800) {
          AppStorageUtil.writeBuffer(dest, packed);
          return CoverService.fileUri(dest);
        }
      } catch (_e) {
      }
    } catch (_e) {
    } finally {
      if (extractor !== null) {
        try {
          await extractor.release();
        } catch (_e) {
        }
      }
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_e) {
        }
      }
    }
    return '';
  }

  private static applyFileMeta(item: MusicItem, meta: media.AVMetadata): void {
    const title = `${meta.title ?? ''}`.trim();
    const artist = `${meta.artist ?? meta.albumArtist ?? meta.author ?? ''}`.trim();
    const album = `${meta.album ?? ''}`.trim();
    if (title.length > 0 && (CoverService.isGenericName(item.title) || item.title.indexOf(title) >= 0 || title.indexOf(CoverService.stripIndex(item.title)) >= 0)) {
      item.title = title;
    }
    if (artist.length > 0 && CoverService.isGenericName(item.artist)) {
      item.artist = artist;
    }
    if (album.length > 0 && CoverService.isGenericName(item.album)) {
      item.album = album;
    }
  }

  private static async packJpeg(pixel: image.PixelMap): Promise<ArrayBuffer | null> {
    const packer = image.createImagePacker();
    try {
      return await packer.packToData(pixel, { format: 'image/jpeg', quality: 88 });
    } catch (_e) {
      return null;
    } finally {
      try {
        await packer.release();
      } catch (_err) {
      }
    }
  }

  private static async fromPluginInfo(item: MusicItem, plugins: PluginManager): Promise<string> {
    if (item.platform === LOCAL_PLATFORM) {
      return '';
    }
    try {
      const info = await plugins.getMusicInfo(item);
      if (info !== null && CoverService.hasUsable(info.artwork)) {
        return info.artwork;
      }
    } catch (_e) {
    }
    return '';
  }

  private static async fromPluginSearch(item: MusicItem, plugins: PluginManager, queries: string[]): Promise<string> {
    const q = queries.length > 0 ? queries[0] : item.title;
    if (q.length === 0) {
      return '';
    }
    try {
      const raw = await plugins.search(q, 1, 'music');
      const arr = JSON.parse(raw) as Object[];
      if (!Array.isArray(arr)) {
        return '';
      }
      for (let i = 0; i < arr.length && i < 8; i++) {
        const hit = MusicItem.fromJson(JSON.stringify(arr[i]));
        if (CoverService.hasUsable(hit.artwork)) {
          return hit.artwork;
        }
      }
    } catch (_e) {
    }
    return '';
  }

  private static async searchRemote(query: string): Promise<string> {
    const qq = await CoverService.searchQq(query);
    if (qq.length > 0) {
      return qq;
    }
    const apple = await CoverService.searchApple(query);
    if (apple.length > 0) {
      return apple;
    }
    return await CoverService.searchNetease(query);
  }

  private static async searchQq(query: string): Promise<string> {
    try {
      const url = `https://c.y.qq.com/soso/fcgi-bin/client_search_cp?p=1&n=5&w=${encodeURIComponent(query)}&format=json`;
      const text = await HttpUtil.getText(url, { 'Referer': 'https://y.qq.com' }, 8000);
      const obj = JSON.parse(text) as Record<string, Object>;
      const data = obj['data'] as Record<string, Object>;
      if (data === undefined || data === null) {
        return '';
      }
      const song = data['song'] as Record<string, Object>;
      if (song === undefined || song === null) {
        return '';
      }
      const list = song['list'];
      if (!Array.isArray(list) || list.length === 0) {
        return '';
      }
      return CoverService.pickQqCover(list as Object[], query);
    } catch (_e) {
      return '';
    }
  }

  private static async searchApple(query: string): Promise<string> {
    try {
      const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=song&limit=5&country=cn`;
      const text = await HttpUtil.getText(url, {}, 8000);
      const obj = JSON.parse(text) as Record<string, Object>;
      const results = obj['results'];
      if (!Array.isArray(results) || results.length === 0) {
        return '';
      }
      const first = results[0] as Record<string, Object>;
      const art = `${first['artworkUrl100'] ?? ''}`;
      if (art.length === 0) {
        return '';
      }
      return art.replace('100x100bb', '600x600bb').replace('100x100', '600x600');
    } catch (_e) {
      return '';
    }
  }

  private static async searchNetease(query: string): Promise<string> {
    try {
      const url = `https://music.163.com/api/search/get/web?s=${encodeURIComponent(query)}&type=1&offset=0&limit=5`;
      const text = await HttpUtil.getText(url, { 'Referer': 'https://music.163.com/' }, 8000);
      const obj = JSON.parse(text) as Record<string, Object>;
      const result = obj['result'] as Record<string, Object>;
      if (result === undefined || result === null) {
        return '';
      }
      const songs = result['songs'];
      if (!Array.isArray(songs) || songs.length === 0) {
        return '';
      }
      const first = songs[0] as Record<string, Object>;
      const album = first['album'] as Record<string, Object>;
      if (album === undefined || album === null) {
        return '';
      }
      return `${album['picUrl'] ?? album['blurPicUrl'] ?? ''}`;
    } catch (_e) {
      return '';
    }
  }

  private static pickQqCover(list: Object[], query: string): string {
    let fallback = '';
    for (let i = 0; i < list.length && i < 5; i++) {
      const row = list[i] as Record<string, Object>;
      const mid = `${row['albummid'] ?? row['albumMid'] ?? ''}`;
      if (mid.length === 0) {
        continue;
      }
      const url = `https://y.gtimg.cn/music/photo_new/T002R500x500M000${mid}.jpg`;
      if (fallback.length === 0) {
        fallback = url;
      }
      const name = `${row['songname'] ?? ''}`;
      if (CoverService.looseMatch(query, name)) {
        return url;
      }
    }
    return fallback;
  }

  private static looseMatch(query: string, name: string): boolean {
    const q = CoverService.cleanSpaces(query);
    const n = CoverService.cleanSpaces(name);
    if (q.length === 0 || n.length === 0) {
      return false;
    }
    return n.indexOf(q) >= 0 || q.indexOf(n) >= 0;
  }

  private static downloadHeaders(url: string): Record<string, string> {
    const headers: Record<string, string> = {};
    if (url.indexOf('gtimg.cn') >= 0 || url.indexOf('y.qq.com') >= 0) {
      headers['Referer'] = 'https://y.qq.com';
    } else if (url.indexOf('music.163.com') >= 0 || url.indexOf('126.net') >= 0) {
      headers['Referer'] = 'https://music.163.com/';
    }
    return headers;
  }

  private static async download(url: string, dest: string): Promise<string> {
    if (url.length === 0) {
      return '';
    }
    try {
      const buf = await HttpUtil.getBytes(url, CoverService.downloadHeaders(url));
      if (buf.byteLength < 800) {
        return '';
      }
      AppStorageUtil.writeBuffer(dest, buf);
      return CoverService.fileUri(dest);
    } catch (_e) {
      return '';
    }
  }
}
