import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpUtil, PluginHttpReply } from './HttpUtil';
import { APP_VERSION } from '../common/Constants';

class PendingCall {
  id: string = '';
  resolveFn: (value: string) => void = (_v: string) => {
  };
  rejectFn: (reason: Error) => void = (_e: Error) => {
  };
}

export class PluginSandbox {
  private static inst: PluginSandbox = new PluginSandbox();
  private controller: webview.WebviewController | null = null;
  private ready: boolean = false;
  private seq: number = 0;
  private pending: Map<string, PendingCall> = new Map();
  private waiters: Array<() => void> = [];
  private loadPayloads: Map<string, string> = new Map();
  private pollArmed: boolean = false;

  takePayload(id: string): string {
    const value = this.loadPayloads.get(id);
    if (value === undefined) {
      return '';
    }
    this.loadPayloads.delete(id);
    return value;
  }

  static instance(): PluginSandbox {
    return PluginSandbox.inst;
  }

  bind(controller: webview.WebviewController): void {
    this.controller = controller;
  }

  markReady(): void {
    this.ready = true;
    const list = this.waiters.slice();
    this.waiters = [];
    for (let i = 0; i < list.length; i++) {
      list[i]();
    }
  }

  private waitReady(): Promise<void> {
    if (this.ready) {
      return Promise.resolve();
    }
    return new Promise<void>((resolve: () => void, reject: (e: Error) => void) => {
      const timer = setTimeout(() => {
        reject(new Error('插件沙箱未就绪'));
      }, 20000);
      this.waiters.push(() => {
        clearTimeout(timer);
        resolve();
      });
    });
  }

  onNativeResult(id: string, ok: boolean, payload: string): void {
    const call = this.pending.get(id);
    if (call === undefined) {
      return;
    }
    this.pending.delete(id);
    setTimeout((): void => {
      if (ok) {
        call.resolveFn(payload);
      } else {
        call.rejectFn(new Error(payload));
      }
    }, 0);
  }

  async loadPlugin(pluginId: string, code: string, userVariablesJson: string = '{}'): Promise<string> {
    await this.waitReady();
    const payload: Record<string, string> = {};
    payload['code'] = code;
    payload['userVariablesJson'] = userVariablesJson;
    payload['appVersion'] = APP_VERSION;
    payload['os'] = 'android';
    payload['lang'] = 'zh-CN';
    return this.run('load', pluginId, JSON.stringify(payload), 45000);
  }

  async unloadPlugin(pluginId: string): Promise<void> {
    if (!this.ready) {
      return;
    }
    await this.run('unload', pluginId, 'null', 45000);
  }

  async callMethod(pluginId: string, method: string, argsJson: string, timeoutMs: number = 45000): Promise<string> {
    await this.waitReady();
    return this.run(method, pluginId, argsJson, timeoutMs);
  }

  private run(method: string, pluginId: string, argsJson: string, timeoutMs: number): Promise<string> {
    this.seq += 1;
    const id = `c${this.seq}`;
    const waitMs = timeoutMs > 0 ? timeoutMs : 45000;
    return new Promise<string>((resolve: (v: string) => void, reject: (e: Error) => void) => {
      const controller = this.controller;
      if (controller === null) {
        reject(new Error('插件沙箱未就绪'));
        return;
      }
      const item = new PendingCall();
      item.id = id;
      item.resolveFn = resolve;
      item.rejectFn = reject;
      this.pending.set(id, item);
      let js = '';
      if (method === 'load') {
        this.loadPayloads.set(id, argsJson);
        js = `window.__mfInvoke(${JSON.stringify(id)},${JSON.stringify(pluginId)},'load',null)`;
      } else {
        js = `window.__mfInvoke(${JSON.stringify(id)},${JSON.stringify(pluginId)},${JSON.stringify(method)},${argsJson})`;
      }
      controller.runJavaScript(js).then((raw: string) => {
        this.takeJsPayload(id, raw);
        if (this.pending.has(id)) {
          this.armPoll();
        }
      }).catch((e: Error) => {
        this.pending.delete(id);
        reject(e);
      });
      setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error('插件调用超时'));
        }
      }, waitMs);
    });
  }

  private unquoteJs(raw: string): string {
    let text = `${raw}`.trim();
    if (text.startsWith('"') && text.endsWith('"')) {
      try {
        const unquoted = JSON.parse(text) as string;
        text = `${unquoted}`;
      } catch (_e) {
      }
    }
    return text;
  }

  private takeJsPayload(id: string, raw: string): void {
    if (!this.pending.has(id)) {
      return;
    }
    if (raw === undefined || raw === null) {
      return;
    }
    const text = this.unquoteJs(`${raw}`);
    if (text.length === 0 || text === 'pending' || text === 'undefined' || text === 'null') {
      return;
    }
    this.applyPacked(id, text);
  }

  private applyPacked(id: string, text: string): void {
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      if (`${obj['mf']}` !== '1') {
        return;
      }
      const payload = obj['p'] !== undefined && obj['p'] !== null ? `${obj['p']}` : '';
      this.onNativeResult(id, `${obj['ok']}` === '1', payload);
    } catch (_e) {
    }
  }

  private armPoll(): void {
    if (this.pollArmed || this.pending.size === 0) {
      return;
    }
    this.pollArmed = true;
    setTimeout(() => {
      this.flushPoll();
    }, 80);
  }

  private flushPoll(): void {
    this.pollArmed = false;
    if (this.pending.size === 0) {
      return;
    }
    const controller = this.controller;
    if (controller === null) {
      return;
    }
    const ids: string[] = [];
    this.pending.forEach((call: PendingCall) => {
      if (call.id.length > 0) {
        ids.push(call.id);
      }
    });
    if (ids.length === 0) {
      return;
    }
    controller.runJavaScript(`window.__mfTakeMany(${JSON.stringify(ids)})`).then((raw: string) => {
      this.takeMany(raw);
      if (this.pending.size > 0) {
        this.armPoll();
      }
    }).catch((_e: Error) => {
      if (this.pending.size > 0) {
        this.armPoll();
      }
    });
  }

  private takeMany(raw: string): void {
    if (raw === undefined || raw === null) {
      return;
    }
    const text = this.unquoteJs(`${raw}`);
    if (text.length === 0 || text === 'pending' || text === 'undefined' || text === 'null' || text === '{}') {
      return;
    }
    try {
      const map = JSON.parse(text) as Record<string, Object>;
      const keys = Object.keys(map);
      for (let i = 0; i < keys.length; i++) {
        const val = map[keys[i]];
        if (val === undefined || val === null) {
          continue;
        }
        if (typeof val === 'string') {
          this.applyPacked(keys[i], val);
        } else {
          this.applyPacked(keys[i], JSON.stringify(val));
        }
      }
    } catch (_e) {
    }
  }

  log(msg: string): void {
    hilog.info(0x0000, 'MusicFreePlugin', '%{public}s', msg);
  }

  handleHttp(id: string, configJson: string): void {
    this.doHttp(id, configJson).catch((e: Error) => {
      this.replyHttp(id, false, e.message);
    });
  }

  private async doHttp(id: string, configJson: string): Promise<void> {
    let method = 'GET';
    let url = '';
    let body = '';
    let timeout = 20000;
    const headers: Record<string, string> = {};
    try {
      const cfg = JSON.parse(configJson) as Record<string, Object>;
      method = cfg['method'] ? `${cfg['method']}` : 'GET';
      url = cfg['url'] ? `${cfg['url']}` : '';
      body = cfg['body'] !== undefined && cfg['body'] !== null ? `${cfg['body']}` : '';
      const t = Number(`${cfg['timeout'] !== undefined && cfg['timeout'] !== null ? cfg['timeout'] : 0}`);
      if (!Number.isNaN(t) && t > 0) {
        timeout = t;
      }
      const headerVal = cfg['headers'];
      if (headerVal !== undefined && headerVal !== null && typeof headerVal === 'object') {
        const rec = headerVal as Record<string, Object>;
        const keys = Object.keys(rec);
        for (let i = 0; i < keys.length; i++) {
          headers[keys[i]] = `${rec[keys[i]]}`;
        }
      }
    } catch (e) {
      this.replyHttp(id, false, e instanceof Error ? e.message : 'fetch fail');
      return;
    }
    const reply: PluginHttpReply = await HttpUtil.pluginRequest(method, url, headers, body, timeout);
    if (reply.error.length > 0 && reply.status === 0) {
      this.log(`http fail ${method} ${url} ${reply.error}`);
      this.replyHttp(id, false, reply.error);
      return;
    }
    this.replyHttp(id, true, JSON.stringify(reply));
  }

  private replyHttp(id: string, ok: boolean, payload: string): void {
    const controller = this.controller;
    if (controller === null) {
      return;
    }
    const js = `window.__mfHttpResult(${JSON.stringify(id)},${ok ? 1 : 0},${JSON.stringify(payload)})`;
    controller.runJavaScript(js).then(() => {
    }).catch((_e: Error) => {
    });
  }
}

export class PluginJsBridge {
  onResult(id: string, ok: string, payload: string): string {
    PluginSandbox.instance().onNativeResult(id, ok === '1', payload);
    return 'ok';
  }

  onLog(msg: string): string {
    PluginSandbox.instance().log(msg);
    return 'ok';
  }

  http(id: string, configJson: string): string {
    PluginSandbox.instance().handleHttp(id, configJson);
    return 'ok';
  }

  mfHttp(id: string, configJson: string): string {
    PluginSandbox.instance().handleHttp(id, configJson);
    return 'ok';
  }

  takePayload(id: string): string {
    return PluginSandbox.instance().takePayload(id);
  }
}
