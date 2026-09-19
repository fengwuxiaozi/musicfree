import { MusicItem } from '../common/Types';
import { AppStorageUtil } from './AppStorageUtil';

class CacheRow {
  key: string = '';
  json: string = '';
  ts: number = 0;
}

/**
 * 媒体元数据缓存，按 platform::id 索引，最多 800 条。
 * 仅提供 API，由父代理在 getMediaSource 中接入。
 */
export class MediaCache {
  private static MAX: number = 800;
  private static rows: CacheRow[] = [];
  private static loaded: boolean = false;

  static get(item: MusicItem): string {
    MediaCache.ensureLoad();
    if (item.platform.length === 0 || item.id.length === 0) {
      return '';
    }
    const k = item.key();
    for (let i = 0; i < MediaCache.rows.length; i++) {
      if (MediaCache.rows[i].key === k) {
        return MediaCache.rows[i].json;
      }
    }
    return '';
  }

  static set(item: MusicItem): void {
    MediaCache.ensureLoad();
    if (item.platform.length === 0 || item.id.length === 0) {
      return;
    }
    const k = item.key();
    const json = item.toPluginJson();
    const now = Date.now();
    for (let i = 0; i < MediaCache.rows.length; i++) {
      if (MediaCache.rows[i].key === k) {
        MediaCache.rows[i].json = json;
        MediaCache.rows[i].ts = now;
        MediaCache.persist();
        return;
      }
    }
    if (MediaCache.rows.length >= MediaCache.MAX) {
      MediaCache.dropOldestHalf();
    }
    const row = new CacheRow();
    row.key = k;
    row.json = json;
    row.ts = now;
    MediaCache.rows.push(row);
    MediaCache.persist();
  }

  static remove(item: MusicItem): void {
    MediaCache.ensureLoad();
    if (item.platform.length === 0 || item.id.length === 0) {
      return;
    }
    const k = item.key();
    const next: CacheRow[] = [];
    for (let i = 0; i < MediaCache.rows.length; i++) {
      if (MediaCache.rows[i].key !== k) {
        next.push(MediaCache.rows[i]);
      }
    }
    MediaCache.rows = next;
    MediaCache.persist();
  }

  static clear(): void {
    MediaCache.loaded = true;
    MediaCache.rows = [];
    MediaCache.persist();
  }

  private static filePath(): string {
    return `${AppStorageUtil.filesRoot()}/media_cache.json`;
  }

  private static ensureLoad(): void {
    if (MediaCache.loaded) {
      return;
    }
    MediaCache.loaded = true;
    const text = AppStorageUtil.readText(MediaCache.filePath());
    if (text.length === 0) {
      return;
    }
    try {
      const arr = JSON.parse(text) as Object[];
      const rows: CacheRow[] = [];
      for (let i = 0; i < arr.length; i++) {
        const obj = JSON.parse(JSON.stringify(arr[i])) as Record<string, Object>;
        const row = new CacheRow();
        row.key = `${obj['key'] || ''}`;
        row.json = `${obj['json'] || ''}`;
        const ts = Number(`${obj['ts']}`);
        row.ts = Number.isNaN(ts) ? 0 : ts;
        if (row.key.length > 0) {
          rows.push(row);
        }
      }
      MediaCache.rows = rows;
    } catch (_e) {
      MediaCache.rows = [];
    }
  }

  private static dropOldestHalf(): void {
    const drop: number = Math.floor(MediaCache.MAX / 2);
    for (let n = 0; n < drop; n++) {
      if (MediaCache.rows.length === 0) {
        return;
      }
      let minIdx = 0;
      for (let i = 1; i < MediaCache.rows.length; i++) {
        if (MediaCache.rows[i].ts < MediaCache.rows[minIdx].ts) {
          minIdx = i;
        }
      }
      const remain: CacheRow[] = [];
      for (let i = 0; i < MediaCache.rows.length; i++) {
        if (i !== minIdx) {
          remain.push(MediaCache.rows[i]);
        }
      }
      MediaCache.rows = remain;
    }
  }

  private static persist(): void {
    const parts: string[] = [];
    for (let i = 0; i < MediaCache.rows.length; i++) {
      const r = MediaCache.rows[i];
      parts.push(`{"key":${JSON.stringify(r.key)},"json":${JSON.stringify(r.json)},"ts":${r.ts}}`);
    }
    AppStorageUtil.writeText(MediaCache.filePath(), `[${parts.join(',')}]`);
  }
}
