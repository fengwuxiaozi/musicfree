import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TlsHttpReply } from './AudiomackTlsHttp';

export class AudiomackRcpHttp {
  private static sessionRef: rcp.Session | null = null;

  static async request(method: string, url: string, headers: Record<string, string>, body: string,
    timeoutMs: number): Promise<TlsHttpReply> {
    const reply = new TlsHttpReply();
    try {
      const session = AudiomackRcpHttp.sessionOf(timeoutMs);
      const req = new rcp.Request(url, AudiomackRcpHttp.methodOf(method), AudiomackRcpHttp.toHeaders(headers),
        body.length > 0 ? body : undefined);
      const resp = await session.fetch(req);
      reply.status = resp.statusCode;
      reply.body = AudiomackRcpHttp.bodyText(resp.body);
      hilog.info(0x0000, 'MusicFreePlugin', 'am rcp %{public}d %{public}d', reply.status, reply.body.length);
      return reply;
    } catch (e) {
      reply.error = AudiomackRcpHttp.errText(e);
      hilog.info(0x0000, 'MusicFreePlugin', 'am rcp fail %{public}s', reply.error);
      return reply;
    }
  }

  private static sessionOf(timeoutMs: number): rcp.Session {
    if (AudiomackRcpHttp.sessionRef !== null) {
      return AudiomackRcpHttp.sessionRef;
    }
    const timeout: rcp.Timeout = {};
    timeout.connectMs = 8000;
    timeout.transferMs = timeoutMs > 8000 ? timeoutMs : 12000;
    const transfer: rcp.TransferConfiguration = {};
    transfer.timeout = timeout;
    transfer.autoRedirect = true;
    const security: rcp.SecurityConfiguration = {};
    security.remoteValidation = 'skip';
    const dns: rcp.DnsConfiguration = {};
    dns.dnsRules = AudiomackRcpHttp.dnsRule;
    dns.happyEyeballOnDnsRule = true;
    const cfg: rcp.Configuration = {};
    cfg.transfer = transfer;
    cfg.security = security;
    cfg.dns = dns;
    cfg.proxy = 'no-proxy';
    const sessionCfg: rcp.SessionConfiguration = {};
    sessionCfg.requestConfiguration = cfg;
    const created = rcp.createSession(sessionCfg);
    AudiomackRcpHttp.sessionRef = created;
    return created;
  }

  private static dnsRule(host: string, _port: number): string[] {
    const ips: string[] = [];
    if (host === 'i.audiomack.com') {
      return ips;
    }
    if (host === 'api.audiomack.com' || host === 'audiomack.com' || host === 'www.audiomack.com') {
      ips.push('18.155.173.25');
      ips.push('18.155.173.29');
      ips.push('18.155.173.76');
      ips.push('18.155.173.3');
      ips.push('65.9.126.81');
      ips.push('65.9.126.69');
    }
    return ips;
  }

  private static toHeaders(headers: Record<string, string>): rcp.RequestHeaders {
    const out: rcp.RequestHeaders = {};
    const keys = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      out[keys[i]] = headers[keys[i]];
    }
    return out;
  }

  private static methodOf(name: string): rcp.HttpMethod {
    const m = name.toUpperCase();
    if (m === 'POST') {
      return 'POST';
    }
    if (m === 'PUT') {
      return 'PUT';
    }
    if (m === 'DELETE') {
      return 'DELETE';
    }
    if (m === 'HEAD') {
      return 'HEAD';
    }
    if (m === 'PATCH') {
      return 'PATCH';
    }
    if (m === 'OPTIONS') {
      return 'OPTIONS';
    }
    return 'GET';
  }

  private static bodyText(body: ArrayBuffer | undefined): string {
    if (body === undefined) {
      return '';
    }
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(body));
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
    const text = `${e}`;
    if (text.length > 0 && text !== '[object Object]') {
      return text;
    }
    return 'fetch fail';
  }
}
