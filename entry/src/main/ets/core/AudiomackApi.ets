import { HttpUtil, PluginHttpReply } from './HttpUtil';

const PAGE_SIZE = 20;
const CONSUMER_KEY = 'audiomack-js';
const CONSUMER_SECRET = 'f3ac5b086f3eab260520d8e3049561e6';
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36';

export class AudiomackApi {
  static async recommendTags(): Promise<string> {
    const extra: Record<string, string> = {};
    extra['featured'] = 'yes';
    extra['limit'] = `${PAGE_SIZE}`;
    extra['page'] = '1';
    const raw = await AudiomackApi.getJson('/playlist/categories', extra);
    const cats = AudiomackApi.arrayAt(raw, 'results', 'categories');
    const group: Record<string, Object> = {};
    group['data'] = cats;
    const groups: Object[] = [];
    groups.push(group);
    const wrapper: Record<string, Object> = {};
    wrapper['data'] = groups;
    return JSON.stringify(wrapper);
  }

  static async recommendSheets(tagJson: string, page: number): Promise<string> {
    const extra: Record<string, string> = {};
    extra['featured'] = 'yes';
    extra['limit'] = `${PAGE_SIZE}`;
    extra['page'] = `${page > 0 ? page : 1}`;
    extra['slug'] = AudiomackApi.tagSlug(tagJson);
    const raw = await AudiomackApi.getJson('/playlist/categories', extra);
    const playlists = AudiomackApi.arrayAt(raw, 'results', 'playlists');
    const sheets: Object[] = [];
    for (let i = 0; i < playlists.length; i++) {
      sheets.push(AudiomackApi.formatSheet(playlists[i]));
    }
    const wrapper: Record<string, Object> = {};
    wrapper['isEnd'] = playlists.length < PAGE_SIZE;
    wrapper['data'] = sheets;
    return JSON.stringify(wrapper);
  }

  static async sheetInfo(sheetId: string): Promise<string> {
    const id = sheetId.trim();
    const empty: Record<string, Object> = {};
    const emptyList: Object[] = [];
    empty['isEnd'] = true;
    empty['musicList'] = emptyList;
    if (id.length === 0) {
      return JSON.stringify(empty);
    }
    const raw = await AudiomackApi.getJson(`/playlist/${id}`, AudiomackApi.emptyParams());
    const results = AudiomackApi.objectAt(raw, 'results');
    const tracks = AudiomackApi.asArray(results['tracks']);
    const musics: Object[] = [];
    for (let i = 0; i < tracks.length; i++) {
      musics.push(AudiomackApi.formatMusic(tracks[i]));
    }
    const wrapper: Record<string, Object> = {};
    wrapper['isEnd'] = true;
    wrapper['musicList'] = musics;
    wrapper['sheetItem'] = AudiomackApi.formatSheet(results as Object);
    return JSON.stringify(wrapper);
  }

  static tagsEmpty(raw: string): boolean {
    if (raw.length === 0 || raw === 'null' || raw === '{}') {
      return true;
    }
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      const groups = obj['data'];
      if (!Array.isArray(groups) || (groups as Object[]).length === 0) {
        return true;
      }
      const first = (groups as Object[])[0] as Record<string, Object>;
      const tags = first['data'];
      return !Array.isArray(tags) || (tags as Object[]).length === 0;
    } catch (_e) {
      return true;
    }
  }

  private static emptyParams(): Record<string, string> {
    const extra: Record<string, string> = {};
    return extra;
  }

  private static tagSlug(tagJson: string): string {
    try {
      const obj = JSON.parse(tagJson) as Record<string, Object>;
      const slug = obj['url_slug'] ? `${obj['url_slug']}` : '';
      if (slug.length > 0) {
        return slug;
      }
      const id = obj['id'] ? `${obj['id']}` : '';
      if (id.length === 0) {
        return 'whats-new';
      }
    } catch (_e) {
    }
    return 'whats-new';
  }

  private static async getJson(path: string, extra: Record<string, string>): Promise<Record<string, Object>> {
    const params: Record<string, string> = {};
    params['oauth_consumer_key'] = CONSUMER_KEY;
    params['oauth_nonce'] = AudiomackApi.nonce(32);
    params['oauth_signature_method'] = 'HMAC-SHA1';
    params['oauth_timestamp'] = `${Math.round(Date.now() / 1000)}`;
    params['oauth_version'] = '1.0';
    const extraKeys = Object.keys(extra);
    for (let i = 0; i < extraKeys.length; i++) {
      params[extraKeys[i]] = extra[extraKeys[i]];
    }
    params['oauth_signature'] = AudiomackApi.sign('GET', path, params);
    const keys = Object.keys(params);
    const parts: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      parts.push(`${encodeURIComponent(keys[i])}=${encodeURIComponent(params[keys[i]])}`);
    }
    const url = `https://api.audiomack.com/v1${path}?${parts.join('&')}`;
    const headers: Record<string, string> = {};
    headers['user-agent'] = UA;
    headers['origin'] = 'https://audiomack.com';
    const reply = await AudiomackApi.requestOnce(url, headers);
    if (reply.status < 200 || reply.status >= 300 || reply.body.length === 0) {
      return {};
    }
    try {
      return JSON.parse(reply.body) as Record<string, Object>;
    } catch (_e) {
      return {};
    }
  }

  private static requestOnce(url: string, headers: Record<string, string>): Promise<PluginHttpReply> {
    return new Promise<PluginHttpReply>((resolve: (value: PluginHttpReply) => void) => {
      let done = false;
      const timer = setTimeout(() => {
        if (done) {
          return;
        }
        done = true;
        const timeoutReply = new PluginHttpReply();
        timeoutReply.error = 'timeout';
        resolve(timeoutReply);
      }, 20000);
      HttpUtil.pluginRequest('GET', url, headers, '', 18000).then((reply: PluginHttpReply) => {
        if (done) {
          return;
        }
        done = true;
        clearTimeout(timer);
        resolve(reply);
      }).catch((_e: Object) => {
        if (done) {
          return;
        }
        done = true;
        clearTimeout(timer);
        const fail = new PluginHttpReply();
        fail.error = 'fetch fail';
        resolve(fail);
      });
    });
  }

  private static sign(method: string, urlPath: string, params: Record<string, string>): string {
    let path = urlPath.split('?')[0];
    if (path.indexOf('http') !== 0) {
      path = `https://api.audiomack.com/v1${path}`;
    }
    const keys = Object.keys(params);
    const encoded: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      encoded.push(AudiomackApi.oauthEncode(keys[i]));
    }
    encoded.sort();
    const pairs: string[] = [];
    for (let i = 0; i < encoded.length; i++) {
      const rawKey = decodeURIComponent(encoded[i]);
      pairs.push(`${encoded[i]}=${AudiomackApi.oauthEncode(params[rawKey])}`);
    }
    const base = `${AudiomackApi.oauthEncode(method.toUpperCase())}&${AudiomackApi.oauthEncode(path)}&${AudiomackApi.oauthEncode(pairs.join('&'))}`;
    return AudiomackApi.hmacSha1Base64(base, `${CONSUMER_SECRET}&`);
  }

  private static oauthEncode(value: string): string {
    return encodeURIComponent(value)
      .replace(/!/g, '%21')
      .replace(/'/g, '%27')
      .replace(/\(/g, '%28')
      .replace(/\)/g, '%29')
      .replace(/\*/g, '%2A');
  }

  private static nonce(count: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let out = '';
    for (let i = 0; i < count; i++) {
      out += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return out;
  }

  private static formatSheet(raw: Object): Record<string, Object> {
    const obj = raw as Record<string, Object>;
    const artist = AudiomackApi.asObject(obj['artist']);
    const item: Record<string, Object> = {};
    item['worksNum'] = obj['track_count'] ?? 0;
    item['id'] = obj['id'] ?? '';
    item['title'] = obj['title'] ?? '';
    item['artist'] = artist['name'] ?? '';
    item['artwork'] = obj['image'] ?? (obj['image_base'] ?? '');
    const artistItem: Record<string, Object> = {};
    artistItem['id'] = artist['id'] ?? '';
    artistItem['avatar'] = artist['image'] ?? (artist['image_base'] ?? '');
    artistItem['name'] = artist['name'] ?? '';
    artistItem['url_slug'] = artist['url_slug'] ?? '';
    item['artistItem'] = artistItem;
    item['url_slug'] = obj['url_slug'] ?? '';
    return item;
  }

  private static formatMusic(raw: Object): Record<string, Object> {
    const obj = raw as Record<string, Object>;
    const item: Record<string, Object> = {};
    item['id'] = obj['id'] ?? '';
    item['artwork'] = obj['image'] ?? (obj['image_base'] ?? '');
    item['duration'] = Number(`${obj['duration'] ?? 0}`) || 0;
    item['title'] = obj['title'] ?? '';
    item['artist'] = AudiomackApi.named(obj['artist']);
    item['album'] = AudiomackApi.named(obj['album']);
    item['url_slug'] = obj['url_slug'] ?? '';
    return item;
  }

  private static named(value: Object | undefined): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'object') {
      const obj = value as Record<string, Object>;
      if (obj['name'] !== undefined && obj['name'] !== null) {
        return `${obj['name']}`;
      }
      if (obj['title'] !== undefined && obj['title'] !== null) {
        return `${obj['title']}`;
      }
      return '';
    }
    return `${value}`;
  }

  private static objectAt(root: Record<string, Object>, key: string): Record<string, Object> {
    const value = root[key];
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object>;
    }
    return {};
  }

  private static arrayAt(root: Record<string, Object>, parent: string, key: string): Object[] {
    return AudiomackApi.asArray(AudiomackApi.objectAt(root, parent)[key]);
  }

  private static asObject(value: Object | undefined): Record<string, Object> {
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object>;
    }
    return {};
  }

  private static asArray(value: Object | undefined): Object[] {
    if (Array.isArray(value)) {
      return value as Object[];
    }
    return [];
  }

  private static hmacSha1Base64(message: string, key: string): string {
    const block = 64;
    let keyBytes = AudiomackApi.utf8(key);
    if (keyBytes.length > block) {
      keyBytes = AudiomackApi.sha1(keyBytes);
    }
    while (keyBytes.length < block) {
      keyBytes.push(0);
    }
    const oPad: number[] = [];
    const iPad: number[] = [];
    for (let i = 0; i < block; i++) {
      oPad.push(keyBytes[i] ^ 0x5c);
      iPad.push(keyBytes[i] ^ 0x36);
    }
    const inner = AudiomackApi.sha1(iPad.concat(AudiomackApi.utf8(message)));
    return AudiomackApi.base64(AudiomackApi.sha1(oPad.concat(inner)));
  }

  private static sha1(bytes: number[]): number[] {
    const msg = bytes.slice();
    const bitLen = bytes.length * 8;
    msg.push(0x80);
    while ((msg.length % 64) !== 56) {
      msg.push(0);
    }
    msg.push(0, 0, 0, 0);
    msg.push((bitLen >>> 24) & 0xff);
    msg.push((bitLen >>> 16) & 0xff);
    msg.push((bitLen >>> 8) & 0xff);
    msg.push(bitLen & 0xff);
    let h0 = 0x67452301;
    let h1 = 0xEFCDAB89;
    let h2 = 0x98BADCFE;
    let h3 = 0x10325476;
    let h4 = 0xC3D2E1F0;
    const w: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    for (let off = 0; off < msg.length; off += 64) {
      for (let i = 0; i < 16; i++) {
        const j = off + i * 4;
        w[i] = ((msg[j] << 24) | (msg[j + 1] << 16) | (msg[j + 2] << 8) | msg[j + 3]) | 0;
      }
      for (let i = 16; i < 80; i++) {
        w[i] = AudiomackApi.rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      let a = h0;
      let b = h1;
      let c = h2;
      let d = h3;
      let e = h4;
      for (let i = 0; i < 80; i++) {
        let f = 0;
        let k = 0;
        if (i < 20) {
          f = (b & c) | ((~b) & d);
          k = 0x5A827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d;
          k = 0xCA62C1D6;
        }
        const temp = (AudiomackApi.rotl(a, 5) + f + e + k + w[i]) | 0;
        e = d;
        d = c;
        c = AudiomackApi.rotl(b, 30);
        b = a;
        a = temp;
      }
      h0 = (h0 + a) | 0;
      h1 = (h1 + b) | 0;
      h2 = (h2 + c) | 0;
      h3 = (h3 + d) | 0;
      h4 = (h4 + e) | 0;
    }
    return AudiomackApi.wordBytes(h0)
      .concat(AudiomackApi.wordBytes(h1))
      .concat(AudiomackApi.wordBytes(h2))
      .concat(AudiomackApi.wordBytes(h3))
      .concat(AudiomackApi.wordBytes(h4));
  }

  private static rotl(value: number, shift: number): number {
    return ((value << shift) | (value >>> (32 - shift))) | 0;
  }

  private static wordBytes(value: number): number[] {
    return [(value >>> 24) & 0xff, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff];
  }

  private static utf8(text: string): number[] {
    const out: number[] = [];
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      if (code < 0x80) {
        out.push(code);
      } else if (code < 0x800) {
        out.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      } else {
        out.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      }
    }
    return out;
  }

  private static base64(bytes: number[]): string {
    const table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let out = '';
    const len = bytes.length;
    for (let i = 0; i < len; i += 3) {
      const b1 = bytes[i];
      const b2 = i + 1 < len ? bytes[i + 1] : 0;
      const b3 = i + 2 < len ? bytes[i + 2] : 0;
      const triple = (b1 << 16) | (b2 << 8) | b3;
      out += table.charAt((triple >>> 18) & 63);
      out += table.charAt((triple >>> 12) & 63);
      out += i + 1 < len ? table.charAt((triple >>> 6) & 63) : '=';
      out += i + 2 < len ? table.charAt(triple & 63) : '=';
    }
    return out;
  }
}
