import { LOCAL_PLATFORM } from '../common/Constants';
import { MusicItem } from '../common/Types';
import { AppStorageUtil } from './AppStorageUtil';

export class LyricExtraItem {
  offset: number = 0;
  associatedPlatform: string = '';
  associatedId: string = '';
  associatedRaw: string = '';
}

export class LyricExtra {
  private static loaded: boolean = false;
  private static showTranslationFlag: boolean = false;
  private static detailFontSize: number = 2;
  private static items: Record<string, LyricExtraItem> = {};

  static load(): void {
    if (LyricExtra.loaded) {
      return;
    }
    LyricExtra.loaded = true;
    const raw = AppStorageUtil.readText(LyricExtra.filePath());
    if (raw.length === 0) {
      return;
    }
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      LyricExtra.showTranslationFlag = `${obj['showTranslation']}` === 'true';
      const font = Number(`${obj['detailFontSize']}`);
      if (!Number.isNaN(font)) {
        if (font === 14) {
          LyricExtra.detailFontSize = 1;
        } else if (font === 16) {
          LyricExtra.detailFontSize = 2;
        } else if (font === 18) {
          LyricExtra.detailFontSize = 3;
        } else if (font >= 1 && font <= 3) {
          LyricExtra.detailFontSize = Math.floor(font);
        }
      }
      const itemsObj = obj['items'] as Record<string, Object>;
      if (itemsObj) {
        const keys = Object.keys(itemsObj);
        const next: Record<string, LyricExtraItem> = {};
        for (let i = 0; i < keys.length; i++) {
          const row = itemsObj[keys[i]] as Record<string, Object>;
          const extra = new LyricExtraItem();
          extra.offset = Number(`${row['offset']}`) || 0;
          extra.associatedPlatform = row['associatedPlatform'] ? `${row['associatedPlatform']}` : '';
          extra.associatedId = row['associatedId'] ? `${row['associatedId']}` : '';
          extra.associatedRaw = row['associatedRaw'] ? `${row['associatedRaw']}` : '';
          next[keys[i]] = extra;
        }
        LyricExtra.items = next;
      }
    } catch (_e) {
    }
  }

  static save(): void {
    const payload = new LyricExtraFile();
    payload.showTranslation = LyricExtra.showTranslationFlag;
    payload.detailFontSize = LyricExtra.detailFontSize;
    payload.items = LyricExtra.items;
    AppStorageUtil.writeText(LyricExtra.filePath(), JSON.stringify(payload));
  }

  static musicKey(item: MusicItem): string {
    if (item.platform === LOCAL_PLATFORM && item.title.length > 0) {
      return `${LOCAL_PLATFORM}::${item.title}`;
    }
    return item.key();
  }

  static getOffset(item: MusicItem): number {
    LyricExtra.ensureLoaded();
    let row = LyricExtra.findItem(LyricExtra.musicKey(item));
    if (row === null) {
      row = LyricExtra.findItem(item.key());
    }
    if (row === null) {
      row = LyricExtra.findLegacyLocal(item);
    }
    if (row === null) {
      return 0;
    }
    return row.offset;
  }

  static setOffset(item: MusicItem, offset: number): void {
    LyricExtra.ensureLoaded();
    const row = LyricExtra.ensureItem(LyricExtra.musicKey(item));
    row.offset = offset;
    LyricExtra.save();
  }

  static getAssociated(item: MusicItem): MusicItem | null {
    LyricExtra.ensureLoaded();
    let row = LyricExtra.findItem(LyricExtra.musicKey(item));
    if (row === null) {
      row = LyricExtra.findItem(item.key());
    }
    if (row === null) {
      row = LyricExtra.findLegacyLocal(item);
    }
    if (row === null || row.associatedPlatform.length === 0 || row.associatedId.length === 0) {
      return null;
    }
    let associated = new MusicItem();
    if (row.associatedRaw.length > 0 && row.associatedRaw !== '{}') {
      associated = MusicItem.fromJson(row.associatedRaw);
    }
    if (associated.platform.length === 0) {
      associated.platform = row.associatedPlatform;
    }
    if (associated.id.length === 0) {
      associated.id = row.associatedId;
    }
    return associated;
  }

  static setAssociated(item: MusicItem, associated: MusicItem): void {
    LyricExtra.ensureLoaded();
    const row = LyricExtra.ensureItem(LyricExtra.musicKey(item));
    row.associatedPlatform = associated.platform;
    row.associatedId = associated.id;
    row.associatedRaw = associated.toPluginJson();
    LyricExtra.save();
  }

  static clearAssociated(item: MusicItem): void {
    LyricExtra.ensureLoaded();
    const row = LyricExtra.findItem(LyricExtra.musicKey(item));
    if (row === null) {
      return;
    }
    row.associatedPlatform = '';
    row.associatedId = '';
    row.associatedRaw = '';
    LyricExtra.save();
  }

  static isShowTranslation(): boolean {
    LyricExtra.ensureLoaded();
    return LyricExtra.showTranslationFlag;
  }

  static setShowTranslation(show: boolean): void {
    LyricExtra.ensureLoaded();
    LyricExtra.showTranslationFlag = show;
    LyricExtra.save();
  }

  static getFontSize(): number {
    LyricExtra.ensureLoaded();
    if (LyricExtra.detailFontSize <= 1) {
      return 14;
    }
    if (LyricExtra.detailFontSize >= 3) {
      return 18;
    }
    return 16;
  }

  static setFontSize(size: number): void {
    LyricExtra.ensureLoaded();
    if (size === 1 || size === 14) {
      LyricExtra.detailFontSize = 1;
    } else if (size === 3 || size === 18) {
      LyricExtra.detailFontSize = 3;
    } else {
      LyricExtra.detailFontSize = 2;
    }
    LyricExtra.save();
  }

  private static ensureLoaded(): void {
    LyricExtra.load();
  }

  private static filePath(): string {
    return `${AppStorageUtil.filesRoot()}/lyric_extra.json`;
  }

  private static findLegacyLocal(item: MusicItem): LyricExtraItem | null {
    if (item.platform !== LOCAL_PLATFORM || item.title.length === 0) {
      return null;
    }
    const keys = Object.keys(LyricExtra.items);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key.indexOf(`${LOCAL_PLATFORM}::`) !== 0) {
        continue;
      }
      let decoded = key;
      try {
        decoded = decodeURIComponent(key);
      } catch (_e) {
      }
      if (key.indexOf(item.title) >= 0 || decoded.indexOf(item.title) >= 0) {
        return LyricExtra.items[key];
      }
    }
    return null;
  }

  private static findItem(key: string): LyricExtraItem | null {
    const keys = Object.keys(LyricExtra.items);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] === key) {
        return LyricExtra.items[keys[i]];
      }
    }
    return null;
  }

  private static ensureItem(key: string): LyricExtraItem {
    const found = LyricExtra.findItem(key);
    if (found !== null) {
      return found;
    }
    const extra = new LyricExtraItem();
    LyricExtra.items[key] = extra;
    return extra;
  }
}

class LyricExtraFile {
  showTranslation: boolean = false;
  detailFontSize: number = 2;
  items: Record<string, LyricExtraItem> = {};
}
