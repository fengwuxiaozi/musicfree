import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { WEBDAV_DIR, WEBDAV_FILE, WEBDAV_FILE_FALLBACK, APP_VERSION } from '../common/Constants';

export class WebDavResult {
  code: number = 0;
  body: string = '';
}

export class WebDavService {
  private url: string = '';
  private username: string = '';
  private password: string = '';

  constructor(url: string, username: string, password: string) {
    this.url = url;
    this.username = username;
    this.password = password;
  }

  private basicToken(): string {
    const encoder = new util.TextEncoder();
    const bytes = encoder.encodeInto(`${this.username}:${this.password}`);
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(bytes);
  }

  private headers(extra?: Record<string, string>): Record<string, string> {
    const h: Record<string, string> = {
      'Authorization': `Basic ${this.basicToken()}`,
      'User-Agent': `MusicFree-Harmony/${APP_VERSION}`
    };
    if (extra !== undefined) {
      const keys = Object.keys(extra);
      for (let i = 0; i < keys.length; i++) {
        h[keys[i]] = extra[keys[i]];
      }
    }
    return h;
  }

  private join(path: string): string {
    let base = this.url.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    let p = path;
    if (!p.startsWith('/')) {
      p = `/${p}`;
    }
    const parts = p.split('/');
    const enc: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length === 0) {
        enc.push('');
      } else {
        enc.push(encodeURIComponent(parts[i]));
      }
    }
    return `${base}${enc.join('/')}`;
  }

  private resolveMethod(name: string): http.RequestMethod {
    if (name === 'PUT') {
      return http.RequestMethod.PUT;
    }
    if (name === 'POST') {
      return http.RequestMethod.POST;
    }
    if (name === 'DELETE') {
      return http.RequestMethod.DELETE;
    }
    if (name === 'HEAD') {
      return http.RequestMethod.HEAD;
    }
    if (name === 'OPTIONS') {
      return http.RequestMethod.OPTIONS;
    }
    if (name === 'PROPFIND' || name === 'MKCOL') {
      return name as http.RequestMethod;
    }
    return http.RequestMethod.GET;
  }

  async request(method: string, path: string, body: string = '', extra?: Record<string, string>): Promise<WebDavResult> {
    const out = new WebDavResult();
    const req = http.createHttp();
    try {
      const opt: http.HttpRequestOptions = {
        method: this.resolveMethod(method),
        header: this.headers(extra),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        usingCache: false
      };
      if (body.length > 0) {
        opt.extraData = body;
      }
      const resp = await req.request(this.join(path), opt);
      out.code = resp.responseCode;
      out.body = `${resp.result}`;
      return out;
    } catch (_e) {
      out.code = 0;
      out.body = '';
      return out;
    } finally {
      req.destroy();
    }
  }

  async propfind(path: string): Promise<boolean> {
    const body =
      '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';
    const resp = await this.request('PROPFIND', path, body, {
      'Content-Type': 'application/xml',
      'Depth': '0'
    });
    return resp.code === 207 || (resp.code >= 200 && resp.code < 300);
  }

  async exists(path: string): Promise<boolean> {
    if (await this.propfind(path)) {
      return true;
    }
    const resp = await this.request('GET', path, '');
    return resp.code >= 200 && resp.code < 300;
  }

  async ensureDir(path: string): Promise<void> {
    if (await this.exists(path)) {
      return;
    }
    await this.request('MKCOL', path, '', {
      'Content-Length': '0'
    });
  }

  async putBackup(content: string): Promise<void> {
    const jsonHeader: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    let resp = await this.request('PUT', WEBDAV_FILE, content, jsonHeader);
    if (resp.code >= 200 && resp.code < 300) {
      return;
    }
    await this.ensureDir(WEBDAV_DIR);
    resp = await this.request('PUT', WEBDAV_FILE, content, jsonHeader);
    if (resp.code >= 200 && resp.code < 300) {
      return;
    }
    resp = await this.request('PUT', WEBDAV_FILE_FALLBACK, content, jsonHeader);
    if (resp.code >= 200 && resp.code < 300) {
      return;
    }
    if (resp.code === 401 || resp.code === 403) {
      throw new Error('WebDAV 认证失败');
    }
    if (resp.code === 0) {
      throw new Error('无法连接 WebDAV 服务器');
    }
    throw new Error(`备份到 WebDAV 失败 (${resp.code})`);
  }

  async getBackup(): Promise<string> {
    let resp = await this.request('GET', WEBDAV_FILE, '');
    if (resp.code >= 200 && resp.code < 300 && resp.body.length > 0) {
      return resp.body;
    }
    resp = await this.request('GET', WEBDAV_FILE_FALLBACK, '');
    if (resp.code >= 200 && resp.code < 300 && resp.body.length > 0) {
      return resp.body;
    }
    if (resp.code === 401 || resp.code === 403) {
      throw new Error('WebDAV 认证失败');
    }
    if (resp.code === 404 || resp.code === 0) {
      throw new Error('未找到 WebDAV 备份文件');
    }
    throw new Error(`从 WebDAV 恢复失败 (${resp.code})`);
  }
}
