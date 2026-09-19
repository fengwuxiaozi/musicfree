import { MusicItem } from '../common/Types';
import { AppStorageUtil } from './AppStorageUtil';

export class MusicHistory {
  list: MusicItem[] = [];
  maxLength: number = 300;
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
    const text = AppStorageUtil.readText(`${AppStorageUtil.filesRoot()}/history.json`);
    if (text.length === 0) {
      return;
    }
    try {
      const arr = JSON.parse(text) as Object[];
      const list: MusicItem[] = [];
      for (let i = 0; i < arr.length; i++) {
        list.push(MusicItem.fromJson(JSON.stringify(arr[i])));
      }
      this.list = list;
    } catch (_e) {
    }
    this.emit();
  }

  add(item: MusicItem): void {
    const next: MusicItem[] = [item];
    for (let i = 0; i < this.list.length; i++) {
      if (!this.list[i].sameAs(item)) {
        next.push(this.list[i]);
      }
    }
    if (next.length > this.maxLength) {
      this.list = next.slice(0, this.maxLength);
    } else {
      this.list = next;
    }
    this.emit();
    const snapshot: MusicItem[] = this.list.slice();
    setTimeout((): void => {
      MusicHistory.write(snapshot);
    }, 0);
  }

  patchMeta(item: MusicItem): void {
    let dirty = false;
    for (let i = 0; i < this.list.length; i++) {
      if (!this.list[i].sameAs(item)) {
        continue;
      }
      if (item.artwork.length > 0) {
        this.list[i].artwork = item.artwork;
      }
      if (item.artist.length > 0) {
        this.list[i].artist = item.artist;
      }
      if (item.album.length > 0) {
        this.list[i].album = item.album;
      }
      if (item.title.length > 0) {
        this.list[i].title = item.title;
      }
      dirty = true;
    }
    if (dirty) {
      this.emit();
      MusicHistory.write(this.list.slice());
    }
  }

  private static write(snapshot: MusicItem[]): void {
    const rows: Record<string, string | number>[] = [];
    for (let i = 0; i < snapshot.length; i++) {
      const m = snapshot[i];
      rows.push({
        'id': m.id,
        'platform': m.platform,
        'artist': m.artist,
        'title': m.title,
        'album': m.album,
        'artwork': m.artwork,
        'duration': m.duration,
        'url': m.url,
        'rawJson': m.rawJson
      });
    }
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/history.json`, JSON.stringify(rows));
  }

  clear(): void {
    this.list = [];
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/history.json`, '[]');
    this.emit();
  }

  replaceAll(list: MusicItem[]): void {
    if (list.length > this.maxLength) {
      this.list = list.slice(0, this.maxLength);
    } else {
      this.list = list.slice();
    }
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/history.json`, JSON.stringify(this.list));
    this.emit();
  }

  removeItems(items: MusicItem[]): void {
    this.list = this.list.filter((m: MusicItem) => {
      for (let i = 0; i < items.length; i++) {
        if (m.sameAs(items[i])) {
          return false;
        }
      }
      return true;
    });
    AppStorageUtil.writeText(`${AppStorageUtil.filesRoot()}/history.json`, JSON.stringify(this.list));
    this.emit();
  }
}
