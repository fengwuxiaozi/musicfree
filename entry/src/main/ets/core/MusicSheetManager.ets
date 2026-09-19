import { FAVORITE_SHEET_ID, LOCAL_PLATFORM } from '../common/Constants';
import { MusicItem, SheetItem } from '../common/Types';
import { AppStorageUtil } from './AppStorageUtil';
import { showToast } from './HttpUtil';
import { I18n } from './I18n';

export class MusicSheetManager {
  sheets: SheetItem[] = [];
  starred: SheetItem[] = [];
  listeners: Array<() => void> = [];

  onChange(cb: () => void): void {
    this.listeners.push(cb);
  }

  private emit(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  load(): void {
    const text = AppStorageUtil.readText(`${AppStorageUtil.sheetDir()}/index.json`);
    if (text.length === 0) {
      const fav = this.createSheet(I18n.t('common.favorite'), FAVORITE_SHEET_ID);
      this.sheets = [fav];
      this.saveIndex();
      return;
    }
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      this.sheets = this.parseSheets(JSON.stringify(obj['sheets'] || []));
      this.starred = this.parseSheets(JSON.stringify(obj['starred'] || []));
      if (this.sheets.length === 0) {
        this.sheets = [this.createSheet(I18n.t('common.favorite'), FAVORITE_SHEET_ID)];
      }
    } catch (_e) {
      this.sheets = [this.createSheet(I18n.t('common.favorite'), FAVORITE_SHEET_ID)];
    }
    this.emit();
  }

  private parseSheets(payload: string): SheetItem[] {
    const list: SheetItem[] = [];
    try {
      const arr = JSON.parse(payload) as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.push(SheetItem.fromJson(JSON.stringify(arr[i])));
      }
    } catch (_e) {
    }
    return list;
  }

  private createSheet(title: string, id?: string): SheetItem {
    const item = new SheetItem();
    item.id = id !== undefined ? id : `${Date.now()}`;
    item.platform = LOCAL_PLATFORM;
    item.title = title;
    item.worksNum = 0;
    return item;
  }

  private saveIndex(): void {
    const payload = JSON.stringify({
      'sheets': this.sheets,
      'starred': this.starred
    });
    AppStorageUtil.writeText(`${AppStorageUtil.sheetDir()}/index.json`, payload);
  }

  private musicPath(id: string): string {
    return `${AppStorageUtil.sheetDir()}/${id}.json`;
  }

  getMusics(sheetId: string): MusicItem[] {
    const text = AppStorageUtil.readText(this.musicPath(sheetId));
    if (text.length === 0) {
      return [];
    }
    const list: MusicItem[] = [];
    try {
      const arr = JSON.parse(text) as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.push(MusicItem.fromJson(JSON.stringify(arr[i])));
      }
    } catch (_e) {
    }
    return list;
  }

  private saveMusics(sheetId: string, list: MusicItem[]): void {
    AppStorageUtil.writeText(this.musicPath(sheetId), JSON.stringify(list));
    for (let i = 0; i < this.sheets.length; i++) {
      if (this.sheets[i].id === sheetId) {
        this.sheets[i].worksNum = list.length;
        if (list.length > 0 && list[0].artwork.length > 0) {
          this.sheets[i].coverImg = list[0].artwork;
        }
      }
    }
    this.saveIndex();
    this.emit();
  }

  addSheet(title: string): SheetItem {
    const sheet = this.createSheet(title);
    let idx = this.sheets.length;
    for (let i = 0; i < this.sheets.length; i++) {
      if (this.sheets[i].id === FAVORITE_SHEET_ID) {
        idx = i + 1;
        break;
      }
    }
    this.sheets.splice(idx, 0, sheet);
    this.saveIndex();
    this.emit();
    return sheet;
  }

  removeSheet(id: string): void {
    if (id === FAVORITE_SHEET_ID) {
      showToast(I18n.t('toast.cannotDeleteDefaultSheet'));
      return;
    }
    this.sheets = this.sheets.filter((s: SheetItem) => s.id !== id);
    AppStorageUtil.removeFile(this.musicPath(id));
    this.saveIndex();
    this.emit();
  }

  replaceMusics(sheetId: string, list: MusicItem[]): void {
    this.saveMusics(sheetId, list.slice());
  }

  renameSheet(id: string, title: string): void {
    const name = title.trim();
    if (name.length === 0) {
      return;
    }
    for (let i = 0; i < this.sheets.length; i++) {
      if (this.sheets[i].id === id) {
        this.sheets[i].title = name;
        this.saveIndex();
        this.emit();
        return;
      }
    }
  }

  addMusics(sheetId: string, items: MusicItem[]): void {
    const list = this.getMusics(sheetId);
    for (let i = 0; i < items.length; i++) {
      let exists = false;
      for (let j = 0; j < list.length; j++) {
        if (list[j].sameAs(items[i])) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        list.push(items[i]);
      }
    }
    this.saveMusics(sheetId, list);
  }

  removeMusics(sheetId: string, items: MusicItem[]): void {
    const list = this.getMusics(sheetId).filter((m: MusicItem) => {
      for (let i = 0; i < items.length; i++) {
        if (m.sameAs(items[i])) {
          return false;
        }
      }
      return true;
    });
    this.saveMusics(sheetId, list);
  }

  isFavorite(item: MusicItem): boolean {
    const list = this.getMusics(FAVORITE_SHEET_ID);
    for (let i = 0; i < list.length; i++) {
      if (list[i].sameAs(item)) {
        return true;
      }
    }
    return false;
  }

  toggleFavorite(item: MusicItem): void {
    if (this.isFavorite(item)) {
      this.removeMusics(FAVORITE_SHEET_ID, [item]);
      showToast(I18n.t('toast.cancelFavorite'));
    } else {
      this.addMusics(FAVORITE_SHEET_ID, [item]);
      showToast(I18n.t('toast.addToFavorite'));
    }
  }

  starSheet(sheet: SheetItem, silent: boolean = false): void {
    for (let i = 0; i < this.starred.length; i++) {
      if (this.starred[i].id === sheet.id && this.starred[i].platform === sheet.platform) {
        return;
      }
    }
    this.starred.push(sheet);
    this.saveIndex();
    this.emit();
    if (!silent) {
      showToast(I18n.t('toast.hasStarred'));
    }
  }

  unstarSheet(sheet: SheetItem): void {
    this.starred = this.starred.filter((s: SheetItem) => !(s.id === sheet.id && s.platform === sheet.platform));
    this.saveIndex();
    this.emit();
    showToast(I18n.t('toast.hasUnstarred'));
  }

  findSheet(id: string): SheetItem | null {
    for (let i = 0; i < this.sheets.length; i++) {
      if (this.sheets[i].id === id) {
        return this.sheets[i];
      }
    }
    return null;
  }

  patchMeta(item: MusicItem): void {
    const ids: string[] = [];
    for (let i = 0; i < this.sheets.length; i++) {
      ids.push(this.sheets[i].id);
    }
    for (let s = 0; s < ids.length; s++) {
      const list = this.getMusics(ids[s]);
      let dirty = false;
      for (let i = 0; i < list.length; i++) {
        const row = list[i];
        const same = row.sameAs(item) || (item.url.length > 0 && (row.url === item.url || row.id === item.url || row.url === item.id));
        if (!same) {
          continue;
        }
        if (item.artwork.length > 0) {
          row.artwork = item.artwork;
        }
        if (item.artist.length > 0) {
          row.artist = item.artist;
        }
        if (item.album.length > 0) {
          row.album = item.album;
        }
        if (item.title.length > 0) {
          row.title = item.title;
        }
        dirty = true;
      }
      if (dirty) {
        this.saveMusics(ids[s], list);
      }
    }
  }
}
