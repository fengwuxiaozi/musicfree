import { promptAction } from '@kit.ArkUI';
import { APP_VERSION } from '../common/Constants';
import { HttpUtil } from './HttpUtil';
import { I18n } from './I18n';

export class UpdateInfo {
  needUpdate: boolean = false;
  version: string = '';
  changeLog: string = '';
  downloadUrl: string = '';
  failed: boolean = false;
}

/**
 * 检查更新。鸿蒙版没有官方 HAP 商店，发现新版本只提示，不假装能自动安装。
 */
export class UpdateService {
  private static URLS: string[] = [];

  static compareVersion(a: string, b: string): number {
    const pa: string[] = a.split('.');
    const pb: string[] = b.split('.');
    const len: number = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
      const na = i < pa.length ? Number(pa[i]) : 0;
      const nb = i < pb.length ? Number(pb[i]) : 0;
      const va = Number.isNaN(na) ? 0 : na;
      const vb = Number.isNaN(nb) ? 0 : nb;
      if (va > vb) {
        return 1;
      }
      if (va < vb) {
        return -1;
      }
    }
    return 0;
  }

  static async check(): Promise<UpdateInfo> {
    if (UpdateService.URLS.length === 0) {
      const local = new UpdateInfo();
      local.needUpdate = false;
      local.failed = false;
      local.version = APP_VERSION;
      return local;
    }
    let lastOk: UpdateInfo | null = null;
    for (let i = 0; i < UpdateService.URLS.length; i++) {
      try {
        const info = UpdateService.parseRemote(await HttpUtil.getText(UpdateService.URLS[i]));
        if (info.version.length === 0) {
          continue;
        }
        if (UpdateService.compareVersion(info.version, APP_VERSION) > 0) {
          info.needUpdate = true;
          return info;
        }
        info.needUpdate = false;
        lastOk = info;
      } catch (_e) {
      }
    }
    if (lastOk !== null) {
      return lastOk;
    }
    const fail = new UpdateInfo();
    fail.needUpdate = false;
    fail.failed = true;
    fail.version = APP_VERSION;
    fail.changeLog = I18n.t('checkUpdate.fail');
    return fail;
  }

  private static storageColor(key: string, fallback: string): string {
    const stored = AppStorage.get<string>(key);
    if (stored !== undefined && stored.length > 0) {
      return stored;
    }
    return fallback;
  }

  private static dialogPrimary(): string {
    return UpdateService.storageColor('primary', '#3FA3B5');
  }

  private static dialogCancel(): string {
    return UpdateService.storageColor('textColor', '#FCFCFC');
  }

  static async showResult(fromUser: boolean): Promise<void> {
    try {
      const info = await UpdateService.check();
      if (info.needUpdate) {
        const log = info.changeLog.length > 0 ? info.changeLog : I18n.t('checkUpdate.noChangeLog');
        await promptAction.showDialog({
          title: I18n.t('checkUpdate.found').replace('{version}', info.version),
          message: `${log}\n\n${I18n.t('checkUpdate.harmonyHint')}`,
          buttons: [
            { text: I18n.t('common.cancel'), color: UpdateService.dialogCancel() },
            { text: I18n.t('checkUpdate.known'), color: UpdateService.dialogPrimary() }
          ]
        });
        return;
      }
      if (fromUser) {
        const msg = info.failed ? I18n.t('checkUpdate.fail') : I18n.t('checkUpdate.error.latestVersion');
        promptAction.showToast({ message: msg, duration: 2000 });
      }
    } catch (_e) {
      if (fromUser) {
        promptAction.showToast({ message: I18n.t('checkUpdate.fail'), duration: 2000 });
      }
    }
  }

  private static parseRemote(text: string): UpdateInfo {
    const info = new UpdateInfo();
    const obj = JSON.parse(text) as Record<string, Object>;
    info.version = `${obj['version'] || ''}`.trim();
    info.changeLog = UpdateService.parseChangeLog(obj['changeLog']);
    info.downloadUrl = UpdateService.parseDownload(obj['download']);
    return info;
  }

  private static parseChangeLog(raw: Object | undefined): string {
    if (raw === undefined || raw === null) {
      return '';
    }
    const dumped = JSON.stringify(raw);
    if (dumped.startsWith('[')) {
      const arr = JSON.parse(dumped) as Object[];
      const parts: string[] = [];
      for (let i = 0; i < arr.length; i++) {
        parts.push(`${arr[i]}`);
      }
      return parts.join('\n');
    }
    return `${raw}`;
  }

  private static parseDownload(raw: Object | undefined): string {
    if (raw === undefined || raw === null) {
      return '';
    }
    const dumped = JSON.stringify(raw);
    if (dumped.startsWith('[')) {
      const arr = JSON.parse(dumped) as Object[];
      if (arr.length > 0) {
        return `${arr[0]}`;
      }
      return '';
    }
    return `${raw}`;
  }
}
