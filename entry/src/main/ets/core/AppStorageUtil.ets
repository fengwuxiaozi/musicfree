import { preferences } from '@kit.ArkData';
import { fileIo as fs, fileShare } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

export class AppStorageUtil {
  private static pref: preferences.Preferences | null = null;
  private static filesDir: string = '';

  static async init(context: common.UIAbilityContext): Promise<void> {
    AppStorageUtil.filesDir = context.filesDir;
    AppStorageUtil.pref = await preferences.getPreferences(context, 'musicfree');
    const dirs: string[] = [
      `${context.filesDir}/plugins`,
      `${context.filesDir}/sheets`,
      `${context.filesDir}/cache`,
      `${context.filesDir}/cache/music`,
      `${context.filesDir}/cache/lyric`,
      `${context.filesDir}/cache/image`,
      `${context.filesDir}/downloads`,
      `${context.filesDir}/local`,
      `${context.filesDir}/logs`,
      `${context.filesDir}/theme-bg`
    ];
    for (let i = 0; i < dirs.length; i++) {
      if (!fs.accessSync(dirs[i])) {
        fs.mkdirSync(dirs[i], true);
      }
    }
  }

  static async getString(key: string, fallback: string = ''): Promise<string> {
    if (AppStorageUtil.pref === null) {
      return fallback;
    }
    const v = await AppStorageUtil.pref.get(key, fallback);
    return `${v}`;
  }

  static async setString(key: string, value: string): Promise<void> {
    if (AppStorageUtil.pref === null) {
      return;
    }
    await AppStorageUtil.pref.put(key, value);
    await AppStorageUtil.pref.flush();
  }

  static async getBool(key: string, fallback: boolean = false): Promise<boolean> {
    const v = await AppStorageUtil.getString(key, fallback ? '1' : '0');
    return v === '1' || v === 'true';
  }

  static async setBool(key: string, value: boolean): Promise<void> {
    await AppStorageUtil.setString(key, value ? '1' : '0');
  }

  static pluginDir(): string {
    return `${AppStorageUtil.filesDir}/plugins`;
  }

  static sheetDir(): string {
    return `${AppStorageUtil.filesDir}/sheets`;
  }

  static filesRoot(): string {
    return AppStorageUtil.filesDir;
  }

  static themeBgDir(): string {
    return `${AppStorageUtil.filesDir}/theme-bg`;
  }

  static exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (_e) {
      return false;
    }
  }

  static copyUri(srcUri: string, destPath: string): void {
    const parent = destPath.substring(0, destPath.lastIndexOf('/'));
    if (!fs.accessSync(parent)) {
      fs.mkdirSync(parent, true);
    }
    if (fs.accessSync(destPath)) {
      fs.unlinkSync(destPath);
    }
    try {
      fs.copyFileSync(srcUri, destPath);
      return;
    } catch (_e) {
    }
    const src = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(src.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(src.fd, buf);
      const dest = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(dest.fd, buf);
      } finally {
        fs.closeSync(dest);
      }
    } finally {
      fs.closeSync(src);
    }
  }

  static readText(path: string): string {
    if (!fs.accessSync(path)) {
      return '';
    }
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      const decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf));
    } finally {
      fs.closeSync(file);
    }
  }

  static writeText(path: string, content: string): void {
    const parent = path.substring(0, path.lastIndexOf('/'));
    if (!fs.accessSync(parent)) {
      fs.mkdirSync(parent, true);
    }
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(content);
      fs.writeSync(file.fd, data.buffer);
    } finally {
      fs.closeSync(file);
    }
  }

  static writeBuffer(path: string, data: ArrayBuffer): void {
    const parent = path.substring(0, path.lastIndexOf('/'));
    if (!fs.accessSync(parent)) {
      fs.mkdirSync(parent, true);
    }
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, data);
    } finally {
      fs.closeSync(file);
    }
  }

  static removeFile(path: string): void {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  }

  static listFiles(dir: string): string[] {
    if (!fs.accessSync(dir)) {
      return [];
    }
    return fs.listFileSync(dir);
  }

  static cacheDir(kind: string): string {
    return `${AppStorageUtil.filesDir}/cache/${kind}`;
  }

  static defaultDownloadDir(): string {
    return `${AppStorageUtil.filesDir}/downloads`;
  }

  static localMusicDir(): string {
    return `${AppStorageUtil.filesDir}/local`;
  }

  static canPersistPickerUri(): boolean {
    return canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization');
  }

  static async persistPickerUri(uri: string): Promise<boolean> {
    if (uri.indexOf('file://') !== 0) {
      return false;
    }
    try {
      const policy: fileShare.PolicyInfo = {
        uri: uri,
        operationMode: fileShare.OperationMode.READ_MODE
      };
      const policies: Array<fileShare.PolicyInfo> = [policy];
      await fileShare.persistPermission(policies);
      await fileShare.activatePermission(policies);
      return AppStorageUtil.tryOpen(uri);
    } catch (e) {
      try {
        const path = AppStorageUtil.errorLogPath();
        const prev = AppStorageUtil.readText(path);
        AppStorageUtil.writeText(path, `${prev}persist fail ${uri} ${JSON.stringify(e)}\n`);
      } catch (_ignore) {
      }
      return false;
    }
  }

  static async activatePickerUris(uris: string[]): Promise<void> {
    if (uris.length === 0) {
      return;
    }
    const policies: Array<fileShare.PolicyInfo> = [];
    for (let i = 0; i < uris.length; i++) {
      if (uris[i].indexOf('file://') === 0) {
        const policy: fileShare.PolicyInfo = {
          uri: uris[i],
          operationMode: fileShare.OperationMode.READ_MODE
        };
        policies.push(policy);
      }
    }
    if (policies.length === 0) {
      return;
    }
    try {
      const checked = await fileShare.checkPersistentPermission(policies);
      const enable: Array<fileShare.PolicyInfo> = [];
      for (let i = 0; i < policies.length; i++) {
        if (i < checked.length && checked[i]) {
          enable.push(policies[i]);
        }
      }
      if (enable.length > 0) {
        await fileShare.activatePermission(enable);
      }
    } catch (_e) {
    }
  }

  static findCopiedLocal(title: string): string {
    const dir = AppStorageUtil.localMusicDir();
    if (!fs.accessSync(dir)) {
      return '';
    }
    const names = fs.listFileSync(dir);
    const base = AppStorageUtil.safeLocalName(title);
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      const dest = `${dir}/${name}`;
      if (name.indexOf(base) === 0 && AppStorageUtil.tryOpen(dest)) {
        return dest;
      }
    }
    return '';
  }

  static isAppLocalFile(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    if (AppStorageUtil.filesDir.length > 0 && path.indexOf(AppStorageUtil.filesDir) === 0) {
      return AppStorageUtil.canOpen(path);
    }
    if (path.indexOf('/data/storage') === 0) {
      return AppStorageUtil.canOpen(path);
    }
    return false;
  }

  static canOpen(path: string): boolean {
    return AppStorageUtil.resolveReadablePath(path).length > 0;
  }

  static resolveReadablePath(path: string): string {
    if (path.length === 0) {
      return '';
    }
    const candidates = AppStorageUtil.expandLocalCandidates(path);
    for (let i = 0; i < candidates.length; i++) {
      if (AppStorageUtil.tryOpen(candidates[i])) {
        return candidates[i];
      }
    }
    return '';
  }

  static expandLocalCandidates(path: string): string[] {
    const out: string[] = [];
    const add = (p: string): void => {
      if (p.length > 0 && out.indexOf(p) < 0) {
        out.push(p);
      }
    };
    add(path);
    const decoded = AppStorageUtil.decodePath(path);
    add(decoded);
    const docsPrefix = 'file://docs/storage/Users/currentUser/';
    if (decoded.indexOf(docsPrefix) === 0) {
      const rest = decoded.substring(docsPrefix.length);
      add(`/storage/media/100/local/files/Docs/${rest}`);
      add(`/storage/Users/currentUser/${rest}`);
    }
    if (decoded.indexOf('file://docs/') === 0) {
      const rest = decoded.substring('file://docs'.length);
      add(`/storage/media/100/local/files${rest}`);
    }
    return out;
  }

  private static decodePath(path: string): string {
    let out = path;
    for (let i = 0; i < 3; i++) {
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

  private static tryOpen(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try {
        return fs.statSync(file.fd).size > 0;
      } finally {
        fs.closeSync(file);
      }
    } catch (_e) {
      return false;
    }
  }

  static importLocalAudio(srcUri: string, title: string): string {
    const dir = AppStorageUtil.localMusicDir();
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const base = AppStorageUtil.safeLocalName(title.length > 0 ? title : srcUri);
    const ext = AppStorageUtil.extFromUri(srcUri);
    let dest = `${dir}/${base}${ext}`;
    let n = 1;
    while (fs.accessSync(dest)) {
      dest = `${dir}/${base}_${n}${ext}`;
      n += 1;
      if (n > 99) {
        break;
      }
    }
    AppStorageUtil.copyUri(srcUri, dest);
    if (!fs.accessSync(dest) || fs.statSync(dest).size <= 0) {
      return '';
    }
    return dest;
  }

  private static isAudioExt(ext: string): boolean {
    return ext === '.mp3' || ext === '.flac' || ext === '.wav' || ext === '.m4a' || ext === '.aac' ||
      ext === '.ogg' || ext === '.ape' || ext === '.wma';
  }

  private static extFromUri(uri: string): string {
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
    const dot = raw.lastIndexOf('.');
    if (dot > 0 && dot < raw.length - 1) {
      const ext = raw.substring(dot).toLowerCase();
      if (AppStorageUtil.isAudioExt(ext)) {
        return ext;
      }
    }
    return '.mp3';
  }

  private static safeLocalName(raw: string): string {
    let name = raw;
    const hash = name.indexOf('#');
    if (hash >= 0) {
      name = name.substring(0, hash);
    }
    const query = name.indexOf('?');
    if (query >= 0) {
      name = name.substring(0, query);
    }
    const slash = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    const dot = name.lastIndexOf('.');
    if (dot > 0) {
      name = name.substring(0, dot);
    }
    let out = '';
    for (let i = 0; i < name.length; i++) {
      const c = name.charAt(i);
      if (c === '/' || c === '\\' || c === ':' || c === '*' || c === '?' || c === '"' || c === '<' || c === '>' ||
        c === '|') {
        out += '_';
      } else {
        out += c;
      }
    }
    if (out.length === 0) {
      return 'local';
    }
    if (out.length > 80) {
      return out.substring(0, 80);
    }
    return out;
  }

  static errorLogPath(): string {
    return `${AppStorageUtil.filesDir}/logs/error.log`;
  }

  static readTextFromUri(uri: string): string {
    if (uri.length === 0) {
      return '';
    }
    const tmp = `${AppStorageUtil.filesDir}/_import_backup.json`;
    try {
      AppStorageUtil.copyUri(uri, tmp);
      const copied = AppStorageUtil.readText(tmp);
      if (copied.length > 0) {
        return copied;
      }
    } catch (_e) {
    }
    const direct = AppStorageUtil.readTextDirect(uri);
    if (direct.length > 0) {
      return direct;
    }
    return AppStorageUtil.readText(uri);
  }

  static writeTextToUri(uri: string, content: string): void {
    const tmp = `${AppStorageUtil.filesDir}/_export_backup.json`;
    AppStorageUtil.writeText(tmp, content);
    try {
      fs.copyFileSync(tmp, uri);
      return;
    } catch (_e) {
    }
    AppStorageUtil.writeTextDirect(uri, content);
  }

  static dirSize(dir: string): number {
    if (!AppStorageUtil.exists(dir)) {
      return 0;
    }
    let total = 0;
    try {
      const names = fs.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        const p = `${dir}/${names[i]}`;
        try {
          const st = fs.statSync(p);
          if (st.isDirectory()) {
            total += AppStorageUtil.dirSize(p);
          } else {
            total += st.size;
          }
        } catch (_e) {
        }
      }
    } catch (_e) {
    }
    return total;
  }

  static clearDir(dir: string): void {
    if (!AppStorageUtil.exists(dir)) {
      return;
    }
    try {
      const names = fs.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        const p = `${dir}/${names[i]}`;
        try {
          const st = fs.statSync(p);
          if (st.isDirectory()) {
            AppStorageUtil.clearDir(p);
            fs.rmdirSync(p);
          } else {
            fs.unlinkSync(p);
          }
        } catch (_e) {
        }
      }
    } catch (_e) {
    }
  }

  static fileSize(path: string): number {
    if (!AppStorageUtil.exists(path)) {
      return 0;
    }
    try {
      return fs.statSync(path).size;
    } catch (_e) {
      return 0;
    }
  }

  static formatBytes(bytes: number): string {
    if (!bytes || bytes <= 0 || Number.isNaN(bytes)) {
      return '0B';
    }
    if (bytes < 1024) {
      return `${Math.floor(bytes)}B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)}K`;
    }
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)}M`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)}G`;
  }

  static readErrorLog(): string {
    return AppStorageUtil.readText(AppStorageUtil.errorLogPath());
  }

  static clearErrorLog(): void {
    AppStorageUtil.removeFile(AppStorageUtil.errorLogPath());
  }

  static appendErrorLog(line: string): void {
    const prev = AppStorageUtil.readErrorLog();
    const next = prev.length > 0 ? `${prev}\n${line}` : line;
    AppStorageUtil.writeText(AppStorageUtil.errorLogPath(), next);
  }

  private static readTextDirect(uri: string): string {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(file.fd);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        const decoder = util.TextDecoder.create('utf-8');
        return decoder.decodeToString(new Uint8Array(buf));
      } finally {
        fs.closeSync(file);
      }
    } catch (_e) {
      return '';
    }
  }

  private static writeTextDirect(uri: string, content: string): void {
    const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(content);
      fs.writeSync(file.fd, data.buffer);
    } finally {
      fs.closeSync(file);
    }
  }
}
