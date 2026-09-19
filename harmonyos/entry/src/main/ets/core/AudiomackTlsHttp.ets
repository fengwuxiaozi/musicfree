import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class TlsHttpReply {
  status: number = 0;
  statusText: string = '';
  body: string = '';
  error: string = '';
}

export class AudiomackTlsHttp {
  private static cachedIps: string[] = [];

  static async request(method: string, url: string, headers: Record<string, string>, body: string,
    timeoutMs: number): Promise<TlsHttpReply> {
    const host = AudiomackTlsHttp.hostOf(url);
    const path = AudiomackTlsHttp.pathOf(url);
    const ips = await AudiomackTlsHttp.resolveIps(host);
    const waitMs = timeoutMs > 8000 ? 7000 : (timeoutMs > 4000 ? timeoutMs : 6000);
    hilog.info(0x0000, 'MusicFreePlugin', 'am ips %{public}s', ips.join(','));
    for (let i = 0; i < ips.length; i++) {
      const reply = await AudiomackTlsHttp.requestIp(method, host, path, headers, body, ips[i], waitMs);
      hilog.info(0x0000, 'MusicFreePlugin', 'am tls %{public}s %{public}d %{public}s %{public}d', ips[i],
        reply.status, reply.error, reply.body.length);
      if (reply.status > 0 || reply.body.length > 0) {
        return reply;
      }
    }
    const fail = new TlsHttpReply();
    fail.error = 'fetch fail';
    return fail;
  }

  private static async resolveIps(_host: string): Promise<string[]> {
    if (AudiomackTlsHttp.cachedIps.length > 0) {
      return AudiomackTlsHttp.cachedIps.slice();
    }
    const out: string[] = [];
    out.push('18.155.173.25');
    out.push('18.155.173.29');
    out.push('18.155.173.76');
    out.push('18.155.173.3');
    out.push('65.9.126.81');
    out.push('65.9.126.69');
    AudiomackTlsHttp.cachedIps = out.slice();
    return out;
  }

  private static async lookupA(host: string): Promise<string[]> {
    const servers: string[] = [];
    servers.push('8.8.8.8');
    servers.push('1.1.1.1');
    for (let i = 0; i < servers.length; i++) {
      const ips = await AudiomackTlsHttp.lookupAOnce(host, servers[i]);
      if (ips.length > 0) {
        return ips;
      }
    }
    return [];
  }

  private static lookupAOnce(host: string, dnsIp: string): Promise<string[]> {
    return new Promise<string[]>((resolve: (value: string[]) => void) => {
      let done = false;
      const udp = socket.constructUDPSocketInstance();
      const finish = (ips: string[]): void => {
        if (done) {
          return;
        }
        done = true;
        try {
          udp.close();
        } catch (_e) {
        }
        resolve(ips);
      };
      const timer = setTimeout(() => {
        finish([]);
      }, 2000);
      const onMsg = (info: socket.SocketMessageInfo): void => {
        clearTimeout(timer);
        finish(AudiomackTlsHttp.parseA(info.message));
      };
      const local: socket.NetAddress = {
        address: '0.0.0.0',
        port: 0,
        family: 1
      };
      const remote: socket.NetAddress = {
        address: dnsIp,
        port: 53,
        family: 1
      };
      const sendOpt: socket.UDPSendOptions = {
        data: AudiomackTlsHttp.buildDnsQuery(host),
        address: remote
      };
      udp.on('message', onMsg);
      udp.bind(local).then(() => {
        return udp.send(sendOpt);
      }).catch((_e: Object) => {
        clearTimeout(timer);
        finish([]);
      });
    });
  }

  private static requestIp(method: string, host: string, path: string, headers: Record<string, string>, body: string,
    ip: string, timeoutMs: number): Promise<TlsHttpReply> {
    return new Promise<TlsHttpReply>((resolve: (value: TlsHttpReply) => void) => {
      let done = false;
      let raw = new Uint8Array(0);
      const tcp = socket.constructTCPSocketInstance();
      let live: socket.TLSSocket | null = null;
      const finish = (reply: TlsHttpReply): void => {
        if (done) {
          return;
        }
        done = true;
        resolve(reply);
      };
      const timer = setTimeout(() => {
        const timeoutReply = new TlsHttpReply();
        timeoutReply.error = 'timeout';
        finish(timeoutReply);
      }, timeoutMs);
      const onMsg = (info: socket.SocketMessageInfo): void => {
        raw = AudiomackTlsHttp.concatBytes(raw, new Uint8Array(info.message));
        const parsed = AudiomackTlsHttp.parseHttp(raw);
        if (parsed !== null) {
          clearTimeout(timer);
          finish(parsed);
        }
      };
      const remote: socket.NetAddress = {
        address: ip,
        port: 443,
        family: 1
      };
      const sni: socket.NetAddress = {
        address: host,
        port: 443,
        family: 1
      };
      const secure: socket.TLSSecureOptions = {};
      const conn: socket.TLSConnectOptions = {
        address: sni,
        secureOptions: secure,
        skipRemoteValidation: true
      };
      const tcpOpt: socket.TCPConnectOptions = {
        address: remote,
        timeout: 5000
      };
      tcp.connect(tcpOpt).then(() => {
        const upgraded = socket.constructTLSSocketInstance(tcp);
        live = upgraded;
        upgraded.on('message', onMsg);
        return upgraded.connect(conn);
      }).then(() => {
        if (live === null) {
          throw new Error('tls missing');
        }
        return live.send(AudiomackTlsHttp.buildRequest(method, host, path, headers, body));
      }).catch((e: Object) => {
        const parsed = AudiomackTlsHttp.parseHttp(raw);
        if (parsed !== null) {
          clearTimeout(timer);
          finish(parsed);
          return;
        }
        clearTimeout(timer);
        const fail = new TlsHttpReply();
        fail.error = `${AudiomackTlsHttp.errText(e)} raw=${raw.length}`;
        finish(fail);
      });
    });
  }

  private static buildRequest(method: string, host: string, path: string, headers: Record<string, string>,
    body: string): string {
    const upper = method.toUpperCase();
    let req = `${upper} ${path} HTTP/1.1\r\nHost: ${host}\r\nConnection: keep-alive\r\n`;
    const keys = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const lower = key.toLowerCase();
      if (lower === 'host' || lower === 'connection' || lower === 'content-length') {
        continue;
      }
      req += `${key}: ${headers[key]}\r\n`;
    }
    if (body.length > 0 && upper !== 'GET' && upper !== 'HEAD') {
      req += `Content-Length: ${body.length}\r\n`;
      req += `\r\n${body}`;
    } else {
      req += '\r\n';
    }
    return req;
  }

  private static parseHttp(raw: Uint8Array): TlsHttpReply | null {
    const sep = AudiomackTlsHttp.indexOfHeaderEnd(raw);
    if (sep < 0) {
      return null;
    }
    const headerText = AudiomackTlsHttp.ascii(raw.subarray(0, sep));
    const bodyBytes = raw.subarray(sep + 4);
    const lines = headerText.split('\r\n');
    if (lines.length === 0) {
      return null;
    }
    const statusLine = lines[0];
    const parts = statusLine.split(' ');
    const status = parts.length > 1 ? Number(parts[1]) : 0;
    if (Number.isNaN(status) || status <= 0) {
      return null;
    }
    let contentLength = -1;
    let chunked = false;
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      const colon = line.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      const name = line.substring(0, colon).trim().toLowerCase();
      const value = line.substring(colon + 1).trim();
      if (name === 'content-length') {
        contentLength = Number(value);
      } else if (name === 'transfer-encoding' && value.toLowerCase().indexOf('chunked') >= 0) {
        chunked = true;
      }
    }
    let payload = bodyBytes;
    if (chunked) {
      const decoded = AudiomackTlsHttp.decodeChunked(bodyBytes);
      if (decoded === null) {
        return null;
      }
      payload = decoded;
    } else if (contentLength >= 0 && bodyBytes.length < contentLength) {
      return null;
    } else if (contentLength >= 0) {
      payload = bodyBytes.subarray(0, contentLength);
    }
    const reply = new TlsHttpReply();
    reply.status = status;
    let statusText = '';
    for (let p = 2; p < parts.length; p++) {
      if (statusText.length > 0) {
        statusText += ' ';
      }
      statusText += parts[p];
    }
    reply.statusText = statusText;
    reply.body = AudiomackTlsHttp.utf8(payload);
    return reply;
  }

  private static decodeChunked(raw: Uint8Array): Uint8Array | null {
    const out: number[] = [];
    let i = 0;
    while (i < raw.length) {
      const nl = AudiomackTlsHttp.indexOfCrlf(raw, i);
      if (nl < 0) {
        return null;
      }
      const size = parseInt(AudiomackTlsHttp.ascii(raw.subarray(i, nl)), 16);
      if (Number.isNaN(size)) {
        return null;
      }
      i = nl + 2;
      if (size === 0) {
        const done = new Uint8Array(out.length);
        for (let k = 0; k < out.length; k++) {
          done[k] = out[k];
        }
        return done;
      }
      if (i + size > raw.length) {
        return null;
      }
      for (let j = 0; j < size; j++) {
        out.push(raw[i + j]);
      }
      i += size;
      if (i + 1 < raw.length && raw[i] === 13 && raw[i + 1] === 10) {
        i += 2;
      }
    }
    return null;
  }

  private static buildDnsQuery(host: string): ArrayBuffer {
    const labels = host.split('.');
    let qLen = 0;
    for (let i = 0; i < labels.length; i++) {
      qLen += 1 + labels[i].length;
    }
    const buf = new ArrayBuffer(12 + qLen + 1 + 4);
    const view = new Uint8Array(buf);
    view[0] = 0x12;
    view[1] = 0x34;
    view[2] = 0x01;
    view[3] = 0x00;
    view[4] = 0x00;
    view[5] = 0x01;
    let offset = 12;
    for (let i = 0; i < labels.length; i++) {
      const label = labels[i];
      view[offset] = label.length;
      offset += 1;
      for (let j = 0; j < label.length; j++) {
        view[offset] = label.charCodeAt(j) & 0xff;
        offset += 1;
      }
    }
    view[offset] = 0;
    offset += 1;
    view[offset] = 0x00;
    view[offset + 1] = 0x01;
    view[offset + 2] = 0x00;
    view[offset + 3] = 0x01;
    return buf;
  }

  private static parseA(buf: ArrayBuffer): string[] {
    const view = new Uint8Array(buf);
    const ips: string[] = [];
    if (view.length < 12) {
      return ips;
    }
    const answers = (view[6] << 8) | view[7];
    let i = 12;
    while (i < view.length && view[i] !== 0) {
      i += view[i] + 1;
    }
    i += 5;
    for (let n = 0; n < answers && i + 12 <= view.length; n++) {
      if ((view[i] & 0xc0) === 0xc0) {
        i += 2;
      } else {
        while (i < view.length && view[i] !== 0) {
          i += view[i] + 1;
        }
        i += 1;
      }
      if (i + 10 > view.length) {
        break;
      }
      const type = (view[i] << 8) | view[i + 1];
      const rdlen = (view[i + 8] << 8) | view[i + 9];
      i += 10;
      if (type === 1 && rdlen === 4 && i + 4 <= view.length) {
        ips.push(`${view[i]}.${view[i + 1]}.${view[i + 2]}.${view[i + 3]}`);
      }
      i += rdlen;
    }
    return ips;
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
    const colon = s.indexOf(':');
    if (colon >= 0) {
      s = s.substring(0, colon);
    }
    return s;
  }

  private static pathOf(url: string): string {
    const scheme = url.indexOf('://');
    const start = scheme >= 0 ? url.indexOf('/', scheme + 3) : url.indexOf('/');
    if (start < 0) {
      return '/';
    }
    const path = url.substring(start);
    return path.length > 0 ? path : '/';
  }

  private static indexOfHeaderEnd(raw: Uint8Array): number {
    for (let i = 0; i + 3 < raw.length; i++) {
      if (raw[i] === 13 && raw[i + 1] === 10 && raw[i + 2] === 13 && raw[i + 3] === 10) {
        return i;
      }
    }
    return -1;
  }

  private static indexOfCrlf(raw: Uint8Array, from: number): number {
    for (let i = from; i + 1 < raw.length; i++) {
      if (raw[i] === 13 && raw[i + 1] === 10) {
        return i;
      }
    }
    return -1;
  }

  private static concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
    const out = new Uint8Array(a.length + b.length);
    out.set(a, 0);
    out.set(b, a.length);
    return out;
  }

  private static ascii(bytes: Uint8Array): string {
    let out = '';
    for (let i = 0; i < bytes.length; i++) {
      out += String.fromCharCode(bytes[i]);
    }
    return out;
  }

  private static utf8(bytes: Uint8Array): string {
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  private static errText(e: Object): string {
    if (e instanceof Error && e.message.length > 0) {
      return e.message;
    }
    try {
      const rec = e as Record<string, Object>;
      const code = rec['code'] !== undefined ? `${rec['code']}` : '';
      const msg = rec['message'] !== undefined ? `${rec['message']}` : '';
      if (code.length > 0 || msg.length > 0) {
        return `${code} ${msg}`.trim();
      }
    } catch (_e) {
    }
    try {
      return JSON.stringify(e);
    } catch (_e2) {
    }
    return 'fetch fail';
  }

  private static contains(list: string[], item: string): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i] === item) {
        return true;
      }
    }
    return false;
  }
}
