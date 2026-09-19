import { http, connection } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { I18n } from './I18n';
import { APP_VERSION } from '../common/Constants';
import { AudiomackTlsHttp } from './AudiomackTlsHttp';
import { AudiomackRcpHttp } from './AudiomackRcpHttp';

class CookieItem {
  name: string = '';
  value: string = '';
  domain: string = '';
  path: string = '/';
}

export class PluginHttpReply {
  status: number = 0;
  statusText: string = '';
  body: string = '';
  headersJson: string = '{}';
  error: string = '';
}

export class HttpUtil {
  private static cookies: CookieItem[] = [];
  private static biliWarm: Promise<void> | null = null;
  private static amDnsReady: boolean = false;

  static async getText(url: string, headers?: Record<string, string>, readTimeout: number = 20000): Promise<string> {
    const req = http.createHttp();
    try {
      const merged: Record<string, string> = {};
      merged['Cache-Control'] = 'no-cache';
      merged['Pragma'] = 'no-cache';
      merged['Expires'] = '0';
      merged['User-Agent'] = `Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 MusicFree/${APP_VERSION}`;
      merged['Accept'] = '*/*';
      if (headers !== undefined) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          merged[keys[i]] = headers[keys[i]];
        }
      }
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: merged,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: readTimeout
      });
      const status = Number(`${resp.responseCode}`);
      if (status === 404) {
        throw new Error(I18n.t('toast.pluginNotExist'));
      }
      if (Number.isNaN(status) || status < 200 || status >= 300) {
        throw new Error(`HTTP ${Number.isNaN(status) ? 0 : status}`);
      }
      if (resp.result === undefined || resp.result === null) {
        return '';
      }
      return `${resp.result}`;
    } finally {
      req.destroy();
    }
  }

  static async getBytes(url: string, headers?: Record<string, string>): Promise<ArrayBuffer> {
    const req = http.createHttp();
    try {
      const merged: Record<string, string> = {};
      merged['User-Agent'] = `Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 MusicFree/${APP_VERSION}`;
      merged['Accept'] = 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8';
      if (headers !== undefined) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          merged[keys[i]] = headers[keys[i]];
        }
      }
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: merged,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 12000,
        readTimeout: 20000
      });
      const status = Number(`${resp.responseCode}`);
      if (Number.isNaN(status) || status < 200 || status >= 300) {
        throw new Error(`HTTP ${Number.isNaN(status) ? 0 : status}`);
      }
      if (resp.result === undefined || resp.result === null) {
        throw new Error('empty image');
      }
      return resp.result as ArrayBuffer;
    } finally {
      req.destroy();
    }
  }

  static async pluginRequest(method: string, url: string, headers: Record<string, string>, body: string, timeoutMs: number): Promise<PluginHttpReply> {
    let reply = await HttpUtil.pluginRequestOnce(method, url, headers, body, timeoutMs);
    if (reply.error.length > 0 && reply.status === 0) {
      await HttpUtil.sleep(200);
      reply = await HttpUtil.pluginRequestOnce(method, url, headers, body, timeoutMs);
    }
    return reply;
  }

  private static async pluginRequestOnce(method: string, url: string, headers: Record<string, string>, body: string, timeoutMs: number): Promise<PluginHttpReply> {
    const reply = new PluginHttpReply();
    if (url.length === 0) {
      reply.error = 'fetch fail';
      return reply;
    }
    let waitMs = timeoutMs > 0 ? timeoutMs : 15000;
    if (url.indexOf('audiomack.com') >= 0 && waitMs < 12000) {
      waitMs = 12000;
    }
    if (url.indexOf('api.bilibili.com') >= 0 && url.indexOf('finger/spi') < 0) {
      await HttpUtil.ensureBiliGuest();
    }
    const host = HttpUtil.hostOf(url);
    const requestUrl = url;
    const merged = HttpUtil.mergePluginHeaders(url, headers);
    if (HttpUtil.isAudiomackApiHost(host)) {
      await HttpUtil.ensureAudiomackDns();
      const rcpReply = await AudiomackRcpHttp.request(method, url, merged, body, waitMs);
      if (rcpReply.status > 0 || rcpReply.body.length > 0) {
        reply.status = rcpReply.status;
        reply.statusText = rcpReply.statusText.length > 0 ? rcpReply.statusText : HttpUtil.statusTextOf(rcpReply.status);
        reply.body = rcpReply.body;
        reply.error = rcpReply.error;
        return reply;
      }
    }
    const req = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: HttpUtil.methodOf(method),
        header: merged,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: waitMs > 20000 ? 20000 : waitMs,
        readTimeout: waitMs,
        usingCache: false,
        addressFamily: http.AddressFamily.ONLY_V4
      };
      const upper = method.toUpperCase();
      if (body.length > 0 && upper !== 'GET' && upper !== 'HEAD') {
        options.extraData = body;
      }
      const resp = await req.request(requestUrl, options);
      reply.status = resp.responseCode;
      reply.statusText = HttpUtil.statusTextOf(resp.responseCode);
      reply.body = resp.result !== undefined && resp.result !== null ? `${resp.result}` : '';
      const outHeaders = HttpUtil.headerMap(resp.header);
      const cookieRaw = resp.cookies !== undefined && resp.cookies !== null ? `${resp.cookies}` : '';
      HttpUtil.rememberCookies(url, outHeaders, cookieRaw);
      if (cookieRaw.length > 0 && HttpUtil.headerOf(outHeaders, 'set-cookie').length === 0) {
        outHeaders['set-cookie'] = cookieRaw;
      }
      reply.headersJson = JSON.stringify(outHeaders);
      if (host.endsWith('audiomack.com')) {
        hilog.info(0x0000, 'MusicFreePlugin', 'am http %{public}d %{public}d', reply.status, reply.body.length);
      }
      return reply;
    } catch (e) {
      reply.error = HttpUtil.errorText(e);
      if (HttpUtil.isAudiomackApiHost(host)) {
        hilog.info(0x0000, 'MusicFreePlugin', 'am http fail %{public}s', reply.error);
        const tlsReply = await AudiomackTlsHttp.request(method, url, merged, body, 8000);
        if (tlsReply.status > 0 || tlsReply.body.length > 0) {
          reply.status = tlsReply.status;
          reply.statusText = tlsReply.statusText;
          reply.body = tlsReply.body;
          reply.error = tlsReply.error;
        }
      }
      return reply;
    } finally {
      req.destroy();
    }
  }

  private static async ensureAudiomackDns(): Promise<void> {
    if (HttpUtil.amDnsReady) {
      return;
    }
    const ips: string[] = [];
    ips.push('18.155.173.25');
    ips.push('18.155.173.29');
    ips.push('18.155.173.76');
    ips.push('18.155.173.3');
    ips.push('65.9.126.81');
    ips.push('65.9.126.69');
    const hosts: string[] = [];
    hosts.push('api.audiomack.com');
    hosts.push('audiomack.com');
    hosts.push('www.audiomack.com');
    try {
      for (let i = 0; i < hosts.length; i++) {
        await connection.addCustomDnsRule(hosts[i], ips);
      }
      HttpUtil.amDnsReady = true;
      let resolved = '';
      try {
        const addrs = await connection.getAddressesByName('api.audiomack.com');
        for (let j = 0; j < addrs.length; j++) {
          if (resolved.length > 0) {
            resolved += ',';
          }
          resolved += addrs[j].address;
        }
      } catch (_e2) {
      }
      hilog.info(0x0000, 'MusicFreePlugin', 'am dns ok %{public}s', resolved);
    } catch (e) {
      hilog.info(0x0000, 'MusicFreePlugin', 'am dns fail %{public}s', HttpUtil.errorText(e));
    }
  }

  private static isAudiomackApiHost(host: string): boolean {
    return host === 'api.audiomack.com' || host === 'audiomack.com' || host === 'www.audiomack.com';
  }

  private static methodOf(name: string): http.RequestMethod {
    const m = name.toUpperCase();
    if (m === 'POST') {
      return http.RequestMethod.POST;
    }
    if (m === 'PUT') {
      return http.RequestMethod.PUT;
    }
    if (m === 'DELETE') {
      return http.RequestMethod.DELETE;
    }
    if (m === 'HEAD') {
      return http.RequestMethod.HEAD;
    }
    if (m === 'OPTIONS') {
      return http.RequestMethod.OPTIONS;
    }
    if (m === 'PATCH') {
      return http.RequestMethod.POST;
    }
    return http.RequestMethod.GET;
  }

  private static statusTextOf(code: number): string {
    if (code === 200) {
      return 'OK';
    }
    if (code === 201) {
      return 'Created';
    }
    if (code === 204) {
      return 'No Content';
    }
    if (code === 301) {
      return 'Moved Permanently';
    }
    if (code === 302) {
      return 'Found';
    }
    if (code === 400) {
      return 'Bad Request';
    }
    if (code === 401) {
      return 'Unauthorized';
    }
    if (code === 403) {
      return 'Forbidden';
    }
    if (code === 404) {
      return 'Not Found';
    }
    if (code === 500) {
      return 'Internal Server Error';
    }
    return '';
  }

  private static mergePluginHeaders(url: string, headers: Record<string, string>): Record<string, string> {
    const raw: Record<string, string> = {};
    raw['user-agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    raw['accept'] = '*/*';
    const cookie = HttpUtil.cookieHeader(url);
    if (cookie.length > 0) {
      raw['cookie'] = cookie;
    }
    const keys = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (HttpUtil.shouldDropHeader(key)) {
        continue;
      }
      const lower = key.toLowerCase();
      const value = `${headers[key]}`;
      if (lower === 'cookie' && cookie.length > 0) {
        raw['cookie'] = HttpUtil.mergeCookieHeader(cookie, value);
      } else {
        raw[lower] = value;
      }
    }
    raw['accept-encoding'] = 'identity';
    const merged: Record<string, string> = {};
    const names = Object.keys(raw);
    for (let j = 0; j < names.length; j++) {
      merged[HttpUtil.canonicalHeader(names[j])] = raw[names[j]];
    }
    return merged;
  }

  private static shouldDropHeader(key: string): boolean {
    const lower = key.toLowerCase();
    if (lower.startsWith('sec-') || lower.startsWith(':')) {
      return true;
    }
    return lower === 'host' || lower === 'connection' || lower === 'content-length' ||
      lower === 'transfer-encoding' || lower === 'accept-encoding' || lower === 'keep-alive' ||
      lower === 'te' || lower === 'trailer' || lower === 'upgrade' || lower === 'expect' ||
      lower === 'proxy-connection';
  }

  private static canonicalHeader(key: string): string {
    const lower = key.toLowerCase();
    if (lower === 'user-agent') {
      return 'User-Agent';
    }
    if (lower === 'cookie') {
      return 'Cookie';
    }
    if (lower === 'referer') {
      return 'Referer';
    }
    if (lower === 'origin') {
      return 'Origin';
    }
    if (lower === 'accept') {
      return 'Accept';
    }
    if (lower === 'content-type') {
      return 'Content-Type';
    }
    if (lower === 'accept-language') {
      return 'Accept-Language';
    }
    if (lower === 'authorization') {
      return 'Authorization';
    }
    if (lower === 'range') {
      return 'Range';
    }
    return key;
  }

  private static errorText(e: Object): string {
    try {
      if (e instanceof Error && e.message.length > 0) {
        return e.message;
      }
    } catch (_e) {
    }
    try {
      const rec = e as Record<string, Object>;
      if (rec['message'] !== undefined && rec['message'] !== null && `${rec['message']}`.length > 0) {
        return `${rec['message']}`;
      }
      if (rec['code'] !== undefined && rec['code'] !== null) {
        return `http error ${rec['code']}`;
      }
    } catch (_e2) {
    }
    const text = `${e}`;
    if (text.length > 0 && text !== 'undefined' && text !== 'null' && text !== '[object Object]') {
      return text;
    }
    return 'fetch fail';
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  private static headerMap(header: Object): Record<string, string> {
    const out: Record<string, string> = {};
    if (header === undefined || header === null || typeof header !== 'object') {
      return out;
    }
    const rec = header as Record<string, Object>;
    const keys = Object.keys(rec);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = rec[key];
      if (value === undefined || value === null) {
        continue;
      }
      if (Array.isArray(value)) {
        const arr = value as Object[];
        const parts: string[] = [];
        for (let j = 0; j < arr.length; j++) {
          parts.push(`${arr[j]}`);
        }
        const joined = HttpUtil.headerNameEq(key, 'set-cookie') ? parts.join('\n') : parts.join(', ');
        out[key] = joined;
      } else {
        out[key] = `${value}`;
      }
    }
    return out;
  }

  private static rememberCookies(url: string, headers: Record<string, string>, rawCookies: string): void {
    const host = HttpUtil.hostOf(url);
    const fromHeader = HttpUtil.headerOf(headers, 'set-cookie');
    const chunks: string[] = [];
    if (fromHeader.length > 0) {
      const lines = fromHeader.split('\n');
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim().length > 0) {
          chunks.push(lines[i]);
        }
      }
    }
    if (rawCookies.length > 0) {
      chunks.push(rawCookies);
    }
    for (let i = 0; i < chunks.length; i++) {
      HttpUtil.upsertCookie(host, chunks[i]);
    }
  }

  private static upsertCookie(host: string, raw: string): void {
    const parts = raw.split(';');
    if (parts.length === 0) {
      return;
    }
    const nv = parts[0].trim();
    const eq = nv.indexOf('=');
    if (eq <= 0) {
      return;
    }
    const item = new CookieItem();
    item.name = nv.substring(0, eq).trim();
    item.value = nv.substring(eq + 1).trim();
    item.domain = host;
    item.path = '/';
    let drop = false;
    for (let i = 1; i < parts.length; i++) {
      const seg = parts[i].trim();
      const e = seg.indexOf('=');
      const k = (e >= 0 ? seg.substring(0, e) : seg).trim().toLowerCase();
      const v = e >= 0 ? seg.substring(e + 1).trim() : '';
      if (k === 'domain' && v.length > 0) {
        item.domain = v.replace(/^\./, '').toLowerCase();
      } else if (k === 'path' && v.length > 0) {
        item.path = v;
      } else if (k === 'max-age' && (v === '0' || v === '-1')) {
        drop = true;
      }
    }
    const next: CookieItem[] = [];
    for (let i = 0; i < HttpUtil.cookies.length; i++) {
      const old = HttpUtil.cookies[i];
      if (old.name === item.name && old.domain === item.domain) {
        continue;
      }
      next.push(old);
    }
    if (!drop && item.name.length > 0) {
      next.push(item);
    }
    HttpUtil.cookies = next;
  }

  private static cookieHeader(url: string): string {
    const host = HttpUtil.hostOf(url);
    const parts: string[] = [];
    for (let i = 0; i < HttpUtil.cookies.length; i++) {
      const item = HttpUtil.cookies[i];
      if (HttpUtil.domainMatch(item.domain, host)) {
        parts.push(`${item.name}=${item.value}`);
      }
    }
    return parts.join('; ');
  }

  private static mergeCookieHeader(jar: string, extra: string): string {
    if (extra.length === 0) {
      return jar;
    }
    if (jar.length === 0) {
      return extra;
    }
    return `${jar}; ${extra}`;
  }

  private static async ensureBiliGuest(): Promise<void> {
    if (HttpUtil.hasCookieName('buvid3')) {
      return;
    }
    if (HttpUtil.biliWarm !== null) {
      await HttpUtil.biliWarm;
      return;
    }
    HttpUtil.biliWarm = HttpUtil.fetchBiliGuest();
    try {
      await HttpUtil.biliWarm;
    } finally {
      HttpUtil.biliWarm = null;
    }
  }

  private static async fetchBiliGuest(): Promise<void> {
    const reply = await HttpUtil.pluginRequestOnce('GET', 'https://api.bilibili.com/x/frontend/finger/spi', {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1'
    }, '', 8000);
    if (reply.body.length === 0) {
      return;
    }
    try {
      const obj = JSON.parse(reply.body) as Record<string, Object>;
      const data = obj['data'] as Record<string, Object>;
      if (data === undefined || data === null) {
        return;
      }
      const b3 = data['b_3'] ? `${data['b_3']}` : '';
      const b4 = data['b_4'] ? `${data['b_4']}` : '';
      if (b3.length > 0) {
        HttpUtil.upsertCookie('bilibili.com', `buvid3=${b3}; Domain=.bilibili.com; Path=/`);
      }
      if (b4.length > 0) {
        HttpUtil.upsertCookie('bilibili.com', `buvid4=${b4}; Domain=.bilibili.com; Path=/`);
      }
    } catch (_e) {
    }
  }

  private static hasCookieName(name: string): boolean {
    for (let i = 0; i < HttpUtil.cookies.length; i++) {
      if (HttpUtil.cookies[i].name === name) {
        return true;
      }
    }
    return false;
  }

  private static hostOf(url: string): string {
    let s = url;
    const scheme = s.indexOf('://');
    if (scheme >= 0) {
      s = s.substring(scheme + 3);
    }
    const slash = s.indexOf('/');
    if (slash >= 0) {
      s = s.substring(0, slash);
    }
    const at = s.lastIndexOf('@');
    if (at >= 0) {
      s = s.substring(at + 1);
    }
    if (s[0] === '[') {
      const end = s.indexOf(']');
      if (end > 0) {
        return s.substring(1, end).toLowerCase();
      }
    }
    const colon = s.indexOf(':');
    if (colon >= 0) {
      s = s.substring(0, colon);
    }
    return s.toLowerCase();
  }

  private static domainMatch(domain: string, host: string): boolean {
    if (domain.length === 0 || host.length === 0) {
      return false;
    }
    if (host === domain) {
      return true;
    }
    return host.endsWith(`.${domain}`);
  }

  private static headerOf(headers: Record<string, string>, name: string): string {
    const keys = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      if (HttpUtil.headerNameEq(keys[i], name)) {
        return headers[keys[i]];
      }
    }
    return '';
  }

  private static headerNameEq(a: string, b: string): boolean {
    return a.toLowerCase() === b.toLowerCase();
  }
}

export function simpleHash(text: string): string {
  let h = 0;
  for (let i = 0; i < text.length; i++) {
    h = ((h << 5) - h) + text.charCodeAt(i);
    h |= 0;
  }
  return Math.abs(h).toString(16);
}

export function formatTime(seconds: number): string {
  if (!seconds || seconds < 0 || Number.isNaN(seconds)) {
    return '00:00';
  }
  const s = Math.floor(seconds);
  const m = Math.floor(s / 60);
  const r = s % 60;
  const mm = m < 10 ? `0${m}` : `${m}`;
  const ss = r < 10 ? `0${r}` : `${r}`;
  return `${mm}:${ss}`;
}

export function showToast(msg: string): void {
  AppStorage.setOrCreate('toastMsg', msg);
}

export function decodeUriComponentSafe(text: string): string {
  let out = text;
  for (let i = 0; i < 3; i++) {
    if (out.indexOf('%') < 0) {
      break;
    }
    try {
      const next = decodeURIComponent(out);
      if (next === out) {
        break;
      }
      out = next;
    } catch (_e) {
      break;
    }
  }
  return out;
}

export function fileTitleFromUri(uri: string): string {
  let raw = uri;
  const hash = raw.indexOf('#');
  if (hash >= 0) {
    raw = raw.substring(0, hash);
  }
  const query = raw.indexOf('?');
  if (query >= 0) {
    raw = raw.substring(0, query);
  }
  const slash = raw.lastIndexOf('/');
  if (slash >= 0) {
    raw = raw.substring(slash + 1);
  }
  raw = decodeUriComponentSafe(raw);
  const dot = raw.lastIndexOf('.');
  if (dot > 0) {
    raw = raw.substring(0, dot);
  }
  return raw.length > 0 ? raw : '未知';
}
