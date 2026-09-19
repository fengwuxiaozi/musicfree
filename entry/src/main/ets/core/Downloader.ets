import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { MusicItem, MediaSource } from '../common/Types';
import { LOCAL_PLATFORM, QUALITIES } from '../common/Constants';
import { PluginManager } from './PluginManager';
import { showToast } from './HttpUtil';
import { AppConfig, KEYS } from './AppConfig';
import { I18n } from './I18n';
import { AppChannel } from './AppChannel';

export enum DownloadStatus {
  Pending = 0,
  Preparing = 1,
  Downloading = 2,
  Completed = 3,
  Failed = 4
}

export enum DownloadFailReason {
  None = 0,
  FailToFetchSource = 1,
  Unknown = 2,
  NoWritePermission = 3
}

export class DownloadTask {
  key: string = '';
  status: DownloadStatus = DownloadStatus.Pending;
  filename: string = '';
  downloadedSize: number = 0;
  fileSize: number = 0;
  errorReason: DownloadFailReason = DownloadFailReason.None;
  localPath: string = '';
  lastNotifyAt: number = 0;
  musicItem: MusicItem = new MusicItem();
  localItem: MusicItem = new MusicItem();
}

const SUPPORT_EXT: string[] = ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg'];
const MAX_CONCURRENT_FALLBACK: number = 3;

export function formatFileSize(bytes: number): string {
  if (!bytes || bytes <= 0 || Number.isNaN(bytes)) {
    return '-';
  }
  if (bytes < 1024) {
    return `${Math.floor(bytes)}B`;
  }
  if (bytes < 1024 * 1024) {
    const kb = bytes / 1024;
    return `${kb.toFixed(1)}KB`;
  }
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(1)}MB`;
}

export function downloadFailReasonText(reason: DownloadFailReason): string {
  if (reason === DownloadFailReason.FailToFetchSource) {
    return I18n.t('downloading.downloadFailReason.failToFetchSource');
  }
  if (reason === DownloadFailReason.NoWritePermission) {
    return I18n.t('downloading.downloadFailReason.noWritePermission');
  }
  return I18n.t('downloading.downloadFailReason.unknown');
}

export function downloadStatusText(task: DownloadTask): string {
  if (task.status === DownloadStatus.Failed) {
    return downloadFailReasonText(task.errorReason);
  }
  if (task.status === DownloadStatus.Completed) {
    return I18n.t('downloading.downloadStatus.completed');
  }
  if (task.status === DownloadStatus.Downloading) {
    return I18n.t('downloading.downloadStatus.downloadProgress')
      .replace('{progress}', formatFileSize(task.downloadedSize))
      .replace('{totalSize}', formatFileSize(task.fileSize));
  }
  if (task.status === DownloadStatus.Pending) {
    return I18n.t('downloading.downloadStatus.pending');
  }
  return I18n.t('downloading.downloadStatus.preparing');
}

export class Downloader {
  tasks: DownloadTask[] = [];
  addLocalHandler: (origin: MusicItem, localPath: string) => MusicItem = (_origin: MusicItem, _path: string) => {
    return new MusicItem();
  };
  isLocalHandler: (item: MusicItem) => boolean = (_item: MusicItem) => {
    return false;
  };

  private plugins: PluginManager | null = null;
  private filesDir: string = '';
  private downloadingCount: number = 0;
  private tick: number = 0;

  setup(plugins: PluginManager, filesDir: string): void {
    this.plugins = plugins;
    this.filesDir = filesDir;
    const dir = this.downloadDir();
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    AppStorage.setOrCreate('downloadTick', 0);
  }

  download(item: MusicItem): void {
    this.downloadList([item]);
  }

  downloadList(items: MusicItem[]): void {
    if (AppChannel.isStore()) {
      return;
    }
    const added: DownloadTask[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.platform === LOCAL_PLATFORM || this.isLocalHandler(item)) {
        continue;
      }
      const key = item.key();
      if (this.findTask(key) !== null) {
        continue;
      }
      const task = new DownloadTask();
      task.key = key;
      task.status = DownloadStatus.Pending;
      task.filename = Downloader.generateFilename(item);
      task.musicItem = MusicItem.fromJson(item.toPluginJson());
      this.tasks.push(task);
      added.push(task);
    }
    if (added.length === 0) {
      if (items.length > 0) {
        showToast(I18n.t('toast.alreadyDownloaded'));
      }
      return;
    }
    showToast(I18n.t('toast.beginDownload'));
    this.notify();
    this.pump();
  }

  listTasks(): DownloadTask[] {
    return this.tasks.slice();
  }

  clearCompleted(): void {
    const next: DownloadTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status !== DownloadStatus.Completed) {
        next.push(this.tasks[i]);
      }
    }
    this.tasks = next;
    this.notify();
  }

  retry(task: DownloadTask): void {
    if (task.status !== DownloadStatus.Failed) {
      return;
    }
    task.status = DownloadStatus.Pending;
    task.errorReason = DownloadFailReason.None;
    task.downloadedSize = 0;
    task.fileSize = 0;
    this.notify();
    this.pump();
  }

  private findTask(key: string): DownloadTask | null {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].key === key) {
        return this.tasks[i];
      }
    }
    return null;
  }

  private downloadDir(): string {
    const custom = AppConfig.getString(KEYS.DOWNLOAD_PATH, '');
    if (custom.length > 0) {
      return custom;
    }
    return `${this.filesDir}/downloads`;
  }

  private notify(): void {
    this.tick += 1;
    AppStorage.setOrCreate('downloadTick', this.tick);
  }

  private maxConcurrent(): number {
    const n = AppConfig.getNumber(KEYS.MAX_DOWNLOAD, MAX_CONCURRENT_FALLBACK);
    if (n < 1) {
      return 1;
    }
    if (n > 7) {
      return 7;
    }
    return Math.floor(n);
  }

  private qualityOrder(): string[] {
    const preferred = AppConfig.getString(KEYS.DOWNLOAD_QUALITY, 'standard');
    const order: string[] = [preferred];
    for (let i = 0; i < QUALITIES.length; i++) {
      if (QUALITIES[i] !== preferred) {
        order.push(QUALITIES[i]);
      }
    }
    return order;
  }

  private pump(): void {
    while (this.downloadingCount < this.maxConcurrent()) {
      const next = this.findPending();
      if (next === null) {
        return;
      }
      this.runTask(next);
    }
  }

  private findPending(): DownloadTask | null {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === DownloadStatus.Pending) {
        return this.tasks[i];
      }
    }
    return null;
  }

  private async runTask(task: DownloadTask): Promise<void> {
    this.downloadingCount += 1;
    task.status = DownloadStatus.Preparing;
    this.notify();
    try {
      const source = await this.fetchSource(task.musicItem);
      if (source.url.length === 0 || source.url.indexOf('http') !== 0) {
        this.markFailed(task, DownloadFailReason.FailToFetchSource);
        return;
      }
      this.pump();
      await this.saveTask(task, source);
    } catch (_e) {
      this.markFailed(task, DownloadFailReason.Unknown);
    } finally {
      this.downloadingCount -= 1;
      this.pump();
    }
  }

  private async fetchSource(item: MusicItem): Promise<MediaSource> {
    if (this.plugins === null) {
      const empty = new MediaSource();
      empty.url = item.url;
      return empty;
    }
    const qualities = this.qualityOrder();
    for (let i = 0; i < qualities.length; i++) {
      try {
        const source = await this.plugins.getMediaSource(item, qualities[i]);
        if (source.url.length > 0) {
          return source;
        }
      } catch (_e) {
      }
    }
    const fallback = new MediaSource();
    fallback.url = item.url;
    return fallback;
  }

  private async saveTask(task: DownloadTask, source: MediaSource): Promise<void> {
    let ext = Downloader.extensionOf(source.url);
    if (SUPPORT_EXT.indexOf(ext) < 0) {
      ext = 'mp3';
    }
    const destPath = `${this.downloadDir()}/${task.filename}.${ext}`;
    try {
      const parent = destPath.substring(0, destPath.lastIndexOf('/'));
      if (!fs.accessSync(parent)) {
        fs.mkdirSync(parent, true);
      }
    } catch (_e) {
      this.markFailed(task, DownloadFailReason.NoWritePermission);
      return;
    }

    const headers: Record<string, string> = {};
    const keys = Object.keys(source.headers);
    for (let i = 0; i < keys.length; i++) {
      headers[keys[i]] = source.headers[keys[i]];
    }
    if (source.userAgent.length > 0) {
      headers['User-Agent'] = source.userAgent;
    }

    task.status = DownloadStatus.Downloading;
    task.downloadedSize = 0;
    task.fileSize = 0;
    this.notify();

    try {
      await this.saveHttpToFile(source.url, headers, destPath, (loaded: number, total: number) => {
        task.status = DownloadStatus.Downloading;
        task.downloadedSize = loaded;
        task.fileSize = total;
        const now = Date.now();
        if (now - task.lastNotifyAt >= 300) {
          task.lastNotifyAt = now;
          this.notify();
        }
      });
    } catch (_e) {
      Downloader.removeIfExists(destPath);
      this.markFailed(task, DownloadFailReason.Unknown);
      return;
    }

    task.localPath = destPath;
    task.localItem = this.addLocalHandler(task.musicItem, destPath);
    task.status = DownloadStatus.Completed;
    task.downloadedSize = task.fileSize > 0 ? task.fileSize : task.downloadedSize;
    this.notify();
  }

  private async saveHttpToFile(url: string, headers: Record<string, string>, destPath: string,
    onProgress: (loaded: number, total: number) => void): Promise<void> {
    const req = http.createHttp();
    req.on('dataReceiveProgress', (data: Object) => {
      const rec = data as Record<string, number>;
      const loaded = rec['receiveSize'] !== undefined ? rec['receiveSize'] : 0;
      const total = rec['totalSize'] !== undefined ? rec['totalSize'] : 0;
      onProgress(loaded, total);
    });
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 300000
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        throw new Error(`http ${resp.responseCode}`);
      }
      const buf = resp.result as ArrayBuffer;
      const file = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, buf);
      } finally {
        fs.closeSync(file);
      }
      onProgress(buf.byteLength, buf.byteLength);
    } finally {
      req.destroy();
    }
  }

  private static generateFilename(item: MusicItem): string {
    const raw = `${Downloader.sanitize(item.platform)}@${Downloader.sanitize(item.id)}@${Downloader.sanitize(item.title)}@${Downloader.sanitize(item.artist)}`;
    if (raw.length > 200) {
      return raw.substring(0, 200);
    }
    return raw.length > 0 ? raw : 'music';
  }

  private static sanitize(text: string): string {
    let out = '';
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' || ch === '"' || ch === '<' || ch === '>' || ch === '|') {
        out += '_';
      } else {
        out += ch;
      }
    }
    return out;
  }

  private static extensionOf(url: string): string {
    let clean = url;
    const q = url.indexOf('?');
    if (q >= 0) {
      clean = url.substring(0, q);
    }
    const dot = clean.lastIndexOf('.');
    if (dot < 0 || dot === clean.length - 1) {
      return 'mp3';
    }
    const ext = clean.substring(dot + 1).toLowerCase();
    if (ext.length === 0 || ext.length > 5) {
      return 'mp3';
    }
    return ext;
  }

  private markFailed(task: DownloadTask, reason: DownloadFailReason): void {
    task.status = DownloadStatus.Failed;
    task.errorReason = reason;
    this.notify();
    showToast(I18n.t('toast.downloadFail').replace('{reason}', downloadFailReasonText(reason)));
  }

  private static removeIfExists(path: string): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (_e) {
    }
  }
}
