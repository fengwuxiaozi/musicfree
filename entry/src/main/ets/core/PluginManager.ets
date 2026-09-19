import { PluginMeta, PluginUserVar, MusicItem, SheetItem, SheetPageResult, AlbumItem, ArtistItem, MediaSource, LyricSource, CommentItem, RecommendTag, RecommendTagGroup, RecommendTagsResult, InstallPluginResult, parseMusicList, parseSheetList } from '../common/Types';
import { AppStorageUtil } from './AppStorageUtil';
import { PluginSandbox } from './PluginSandbox';
import { HttpUtil, simpleHash, showToast } from './HttpUtil';
import { AudiomackApi } from './AudiomackApi';
import { MediaCache } from './MediaCache';
import { LOCAL_PLATFORM } from '../common/Constants';
import { I18n } from './I18n';
import { AppConfig, KEYS } from './AppConfig';
import { UpdateService } from './UpdateService';
import { AppChannel } from './AppChannel';

const PLUGIN_SEARCH_TIMEOUT = 8000;

export class PluginSubscribeItem {
  name: string = '';
  url: string = '';
}

export class CommentPageResult {
  data: CommentItem[] = [];
  isEnd: boolean = true;
}

class SavedPluginState {
  platform: string = '';
  path: string = '';
  order: number = 0;
  srcUrl: string = '';
  enabled: boolean = true;
  alternativePlugin: string = '';
  userVariableValues: Record<string, string> = {};
}

class PluginDedupeSplit {
  kept: PluginMeta[] = [];
  removed: PluginMeta[] = [];
}

export class PluginManager {
  plugins: PluginMeta[] = [];
  listeners: Array<() => void> = [];

  onChange(cb: () => void): void {
    this.listeners.push(cb);
  }

  private emit(): void {
    AppStorage.setOrCreate('pluginCount', this.plugins.length);
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  enabledPlugins(): PluginMeta[] {
    const list: PluginMeta[] = [];
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].enabled && this.plugins[i].state === 'mounted') {
        list.push(this.plugins[i]);
      }
    }
    list.sort((a: PluginMeta, b: PluginMeta) => a.order - b.order);
    return list;
  }

  sortedPlugins(): PluginMeta[] {
    const list = this.plugins.slice();
    list.sort((a: PluginMeta, b: PluginMeta) => a.order - b.order);
    return list;
  }

  findByPlatform(platform: string): PluginMeta | null {
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].platform === platform) {
        return this.plugins[i];
      }
    }
    return null;
  }

  async reloadAll(): Promise<void> {
    if (AppChannel.isStore()) {
      this.plugins = [];
      this.emit();
      return;
    }
    const savedList = this.readSavedList();
    const names = AppStorageUtil.listFiles(AppStorageUtil.pluginDir());
    const next: PluginMeta[] = [];
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      if (!name.endsWith('.js')) {
        continue;
      }
      const path = `${AppStorageUtil.pluginDir()}/${name}`;
      const code = AppStorageUtil.readText(path);
      const byPath = this.findSavedByPath(savedList, path, name);
      const uv = byPath !== null ? byPath.userVariableValues : this.emptyVars();
      let meta = await this.mount(path, code, uv);
      let saved = byPath;
      if (saved === null) {
        saved = this.findSavedByPlatform(savedList, meta.platform);
      }
      if (saved !== null) {
        if (byPath === null && this.recordHasKeys(saved.userVariableValues)) {
          meta = await this.mount(path, code, saved.userVariableValues);
        }
        meta.order = saved.order;
        if (meta.srcUrl.length === 0) {
          meta.srcUrl = saved.srcUrl;
        }
        meta.enabled = saved.enabled;
        meta.alternativePlugin = saved.alternativePlugin;
        meta.userVariableValues = this.copyStringRecord(saved.userVariableValues);
      } else {
        meta.order = i;
      }
      next.push(meta);
    }
    next.sort((a: PluginMeta, b: PluginMeta) => a.order - b.order);
    const unique = this.splitUnique(next);
    this.plugins = unique.kept;
    this.saveOrder();
    this.emit();
    await this.dropPlugins(unique.removed);
  }

  private async mount(path: string, code: string, userVariableValues: Record<string, string>): Promise<PluginMeta> {
    return await this.mountWithId(simpleHash(path), path, code, userVariableValues);
  }

  private async mountWithId(id: string, path: string, code: string, userVariableValues: Record<string, string>): Promise<PluginMeta> {
    const meta = new PluginMeta();
    meta.hash = id;
    meta.path = path;
    meta.userVariableValues = this.copyStringRecord(userVariableValues);
    try {
      const uvJson = JSON.stringify(meta.userVariableValues);
      const infoText = await PluginSandbox.instance().loadPlugin(id, code, uvJson.length > 0 ? uvJson : '{}');
      const info = JSON.parse(infoText) as Record<string, Object>;
      meta.platform = this.infoText(info, 'platform');
      meta.version = this.infoText(info, 'version');
      meta.author = this.infoText(info, 'author');
      meta.srcUrl = this.infoText(info, 'srcUrl');
      meta.description = this.infoText(info, 'description');
      meta.cacheControl = this.infoText(info, 'cacheControl');
      const methodsObj = info['methods'];
      if (Array.isArray(methodsObj)) {
        const arr = methodsObj as Object[];
        const methods: string[] = [];
        for (let i = 0; i < arr.length; i++) {
          methods.push(`${arr[i]}`);
        }
        meta.methods = methods;
      }
      const searchTypes = info['supportedSearchType'];
      if (Array.isArray(searchTypes)) {
        const types: string[] = [];
        const typeArr = searchTypes as Object[];
        for (let i = 0; i < typeArr.length; i++) {
          const t = `${typeArr[i]}`.trim();
          if (t.length > 0) {
            types.push(t);
          }
        }
        meta.supportedSearchType = types;
      }
      meta.userVariables = this.parseUserVarList(info['userVariables']);
      this.applyHints(meta, info['hints']);
      meta.state = meta.platform.length > 0 ? 'mounted' : 'error';
      if (meta.platform.length === 0) {
        meta.errorMsg = I18n.t('toast.pluginParseFail');
      }
    } catch (e) {
      meta.state = 'error';
      meta.errorMsg = e instanceof Error ? e.message : I18n.t('toast.pluginParseFail');
    }
    return meta;
  }

  async installFromUrl(url: string): Promise<void> {
    if (AppChannel.isStore()) {
      return;
    }
    const trimmed = url.trim();
    if (this.isJsonPluginUrl(trimmed)) {
      await this.installFromSubscribe(trimmed);
      return;
    }
    const code = await HttpUtil.getText(trimmed);
    await this.installCode(code, trimmed);
  }

  async installFromUrlResult(url: string): Promise<InstallPluginResult> {
    const result = new InstallPluginResult();
    result.pluginUrl = url;
    try {
      await this.installFromUrl(url);
      result.success = true;
      const installed = this.findBySrcUrl(url.trim());
      if (installed !== null) {
        result.pluginName = installed.platform;
      }
      return result;
    } catch (e) {
      result.success = false;
      result.message = e instanceof Error ? e.message : I18n.t('toast.installPluginFail');
      return result;
    }
  }

  async installFromSubscribe(url: string): Promise<void> {
    const text = await HttpUtil.getText(url);
    const obj = JSON.parse(text) as Record<string, Object>;
    const plugins = obj['plugins'] as Object[];
    if (!Array.isArray(plugins)) {
      throw new Error(I18n.t('toast.subscriptionInvalid'));
    }
    let ok = 0;
    for (let i = 0; i < plugins.length; i++) {
      const item = plugins[i] as Record<string, Object>;
      const raw = item['url'] !== undefined && item['url'] !== null ? item['url'] : item['srcUrl'];
      const src = raw !== undefined && raw !== null ? `${raw}`.trim() : '';
      if (src.length === 0 || src === 'undefined' || src === 'null') {
        continue;
      }
      if (this.findBySrcUrl(src) !== null) {
        ok += 1;
        continue;
      }
      try {
        await this.installFromUrl(src);
        ok += 1;
      } catch (_e) {
      }
    }
    if (ok === 0) {
      throw new Error(I18n.t('toast.allPluginInstallFailed'));
    }
  }

  async installCode(code: string, srcUrl: string): Promise<void> {
    if (AppChannel.isStore()) {
      throw new Error(I18n.t('toast.pluginUnrecognized'));
    }
    const trimmed = code.trim();
    if (trimmed.length === 0) {
      throw new Error(I18n.t('toast.pluginUnrecognized'));
    }
    if (trimmed.startsWith('<')) {
      throw new Error(I18n.t('toast.pluginParseFail'));
    }
    const probeId = `probe_${simpleHash(`${srcUrl}:${Date.now()}`)}`;
    const probe = await this.mountWithId(probeId, '', code, this.emptyVars());
    if (probe.state !== 'mounted') {
      await PluginSandbox.instance().unloadPlugin(probeId);
      throw new Error(probe.errorMsg.length > 0 ? probe.errorMsg : I18n.t('toast.pluginParseFail'));
    }
    const notCheck = AppConfig.getBool(KEYS.NOT_CHECK_PLUGIN_VERSION, false);
    let oldEnabled = true;
    let oldOrder = this.nextOrder();
    let oldAlt = '';
    let oldUv: Record<string, string> = this.emptyVars();
    const oldPaths: string[] = [];
    const oldHashes: string[] = [];
    const next: PluginMeta[] = [];
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].platform !== probe.platform) {
        next.push(this.plugins[i]);
      } else {
        if (!notCheck && UpdateService.compareVersion(this.plugins[i].version, probe.version) > 0) {
          await PluginSandbox.instance().unloadPlugin(probeId);
          throw new Error('已安装更新版本的插件');
        }
        oldEnabled = this.plugins[i].enabled;
        oldOrder = this.plugins[i].order;
        oldAlt = this.plugins[i].alternativePlugin;
        oldUv = this.copyStringRecord(this.plugins[i].userVariableValues);
        oldPaths.push(this.plugins[i].path);
        oldHashes.push(this.plugins[i].hash);
      }
    }
    await PluginSandbox.instance().unloadPlugin(probeId);
    const path = `${AppStorageUtil.pluginDir()}/${simpleHash(srcUrl + code.substring(0, 64))}.js`;
    AppStorageUtil.writeText(path, code);
    let meta = await this.mount(path, code, this.recordHasKeys(oldUv) ? oldUv : this.emptyVars());
    if (meta.state !== 'mounted') {
      AppStorageUtil.removeFile(path);
      await PluginSandbox.instance().unloadPlugin(meta.hash);
      throw new Error(meta.errorMsg.length > 0 ? meta.errorMsg : I18n.t('toast.installPluginFail'));
    }
    meta.srcUrl = srcUrl;
    meta.enabled = oldEnabled;
    meta.order = oldOrder;
    meta.alternativePlugin = oldAlt;
    meta.userVariableValues = oldUv;
    next.push(meta);
    next.sort((a: PluginMeta, b: PluginMeta) => a.order - b.order);
    this.plugins = next;
    this.saveOrder();
    this.emit();
    for (let i = 0; i < oldHashes.length; i++) {
      if (oldHashes[i] !== meta.hash) {
        await PluginSandbox.instance().unloadPlugin(oldHashes[i]);
      }
    }
    for (let j = 0; j < oldPaths.length; j++) {
      if (oldPaths[j] !== path) {
        AppStorageUtil.removeFile(oldPaths[j]);
      }
    }
  }

  async dedupe(): Promise<number> {
    const unique = this.splitUnique(this.plugins);
    if (unique.removed.length === 0) {
      return 0;
    }
    this.plugins = unique.kept;
    this.saveOrder();
    this.emit();
    await this.dropPlugins(unique.removed);
    return unique.removed.length;
  }

  private pluginDedupeKey(p: PluginMeta): string {
    const platform = p.platform.trim();
    if (platform.length > 0) {
      return `p:${platform}`;
    }
    const src = p.srcUrl.trim();
    if (src.length > 0) {
      return `u:${src}`;
    }
    return `h:${p.hash}`;
  }

  private preferPlugin(a: PluginMeta, b: PluginMeta): boolean {
    const cmp = UpdateService.compareVersion(a.version, b.version);
    if (cmp > 0) {
      return true;
    }
    if (cmp < 0) {
      return false;
    }
    if (a.enabled !== b.enabled) {
      return a.enabled;
    }
    return a.order < b.order;
  }

  private splitUnique(list: PluginMeta[]): PluginDedupeSplit {
    const best: Record<string, PluginMeta> = {};
    const keys: string[] = [];
    const removed: PluginMeta[] = [];
    for (let i = 0; i < list.length; i++) {
      const item = list[i];
      const key = this.pluginDedupeKey(item);
      const current = best[key];
      if (current === undefined) {
        best[key] = item;
        keys.push(key);
      } else if (this.preferPlugin(item, current)) {
        removed.push(current);
        best[key] = item;
      } else {
        removed.push(item);
      }
    }
    const kept: PluginMeta[] = [];
    for (let j = 0; j < keys.length; j++) {
      kept.push(best[keys[j]]);
    }
    kept.sort((a: PluginMeta, b: PluginMeta) => a.order - b.order);
    const out = new PluginDedupeSplit();
    out.kept = kept;
    out.removed = removed;
    return out;
  }

  private async dropPlugins(list: PluginMeta[]): Promise<void> {
    for (let i = 0; i < list.length; i++) {
      await PluginSandbox.instance().unloadPlugin(list[i].hash);
      if (list[i].path.length > 0) {
        AppStorageUtil.removeFile(list[i].path);
      }
    }
  }

  async uninstallAll(): Promise<void> {
    const hashes: string[] = [];
    for (let i = 0; i < this.plugins.length; i++) {
      hashes.push(this.plugins[i].hash);
    }
    for (let i = 0; i < hashes.length; i++) {
      await this.uninstall(hashes[i]);
    }
    const dir = AppStorageUtil.pluginDir();
    const names = AppStorageUtil.listFiles(dir);
    for (let j = 0; j < names.length; j++) {
      if (names[j].endsWith('.js')) {
        AppStorageUtil.removeFile(`${dir}/${names[j]}`);
      }
    }
  }

  async uninstall(hash: string): Promise<void> {
    const found = this.plugins.filter((p: PluginMeta) => p.hash === hash);
    if (found.length > 0) {
      AppStorageUtil.removeFile(found[0].path);
      await PluginSandbox.instance().unloadPlugin(hash);
    }
    this.plugins = this.plugins.filter((p: PluginMeta) => p.hash !== hash);
    this.saveOrder();
    this.emit();
  }

  async setEnabled(hash: string, enabled: boolean): Promise<void> {
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].hash === hash) {
        this.plugins[i].enabled = enabled;
      }
    }
    this.saveOrder();
    this.emit();
  }

  hasMethod(plugin: PluginMeta, method: string): boolean {
    return plugin.methods.indexOf(method) >= 0;
  }

  findByHash(hash: string): PluginMeta | null {
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].hash === hash) {
        return this.plugins[i];
      }
    }
    return null;
  }

  pluginsWithMethod(method: string): PluginMeta[] {
    const enabled = this.enabledPlugins();
    const list: PluginMeta[] = [];
    for (let i = 0; i < enabled.length; i++) {
      if (this.hasMethod(enabled[i], method)) {
        list.push(enabled[i]);
      }
    }
    return list;
  }

  async importMusicSheetByHash(hash: string, url: string): Promise<MusicItem[]> {
    const plugin = this.findByHash(hash);
    if (plugin === null || !this.hasMethod(plugin, 'importMusicSheet')) {
      return [];
    }
    const raw = await this.callQuiet(plugin.hash, 'importMusicSheet', JSON.stringify([url]));
    const list = this.parseImportResult(raw);
    for (let j = 0; j < list.length; j++) {
      if (list[j].platform.length === 0) {
        list[j].platform = plugin.platform;
      }
    }
    return list;
  }

  searchHashes(): string[] {
    const list = this.searchablePlugins('');
    const hashes: string[] = [];
    for (let i = 0; i < list.length; i++) {
      hashes.push(list[i].hash);
    }
    return hashes;
  }

  searchablePlugins(type: string): PluginMeta[] {
    const list = this.pluginsWithMethod('search');
    const out: PluginMeta[] = [];
    for (let i = 0; i < list.length; i++) {
      if (type.length === 0 || list[i].supportedSearchType.length === 0 ||
        list[i].supportedSearchType.indexOf(type) >= 0) {
        out.push(list[i]);
      }
    }
    return out;
  }

  async searchOne(hash: string, query: string, page: number, type: string): Promise<string> {
    const plugin = this.findByHash(hash);
    const platform = plugin !== null ? plugin.platform : '';
    const raw = await this.callQuiet(hash, 'search', JSON.stringify([query, page, type]), PLUGIN_SEARCH_TIMEOUT);
    return this.extractSearchData(raw, platform);
  }

  async search(query: string, page: number, type: string): Promise<string> {
    if (AppChannel.isStore()) {
      return '[]';
    }
    const hashes = this.searchHashes();
    const tasks: Promise<string>[] = [];
    for (let i = 0; i < hashes.length; i++) {
      tasks.push(this.searchOne(hashes[i], query, page, type));
    }
    const results = await Promise.all(tasks);
    const merged: Object[] = [];
    for (let i = 0; i < results.length; i++) {
      try {
        const data = JSON.parse(results[i]) as Object[];
        if (Array.isArray(data)) {
          for (let j = 0; j < data.length; j++) {
            merged.push(data[j]);
          }
        }
      } catch (_e) {
      }
    }
    return JSON.stringify(merged);
  }

  private extractSearchData(raw: string, platform: string): string {
    if (raw.length === 0 || raw === 'null') {
      return '[]';
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const arr = parsed as Object[];
        this.fillSearchPlatform(arr, platform);
        return JSON.stringify(arr);
      }
      const obj = parsed as Record<string, Object>;
      const data = obj['data'];
      if (Array.isArray(data)) {
        this.fillSearchPlatform(data as Object[], platform);
        return JSON.stringify(data);
      }
    } catch (_e) {
    }
    return '[]';
  }

  private fillSearchPlatform(data: Object[], platform: string): void {
    if (platform.length === 0) {
      return;
    }
    for (let i = 0; i < data.length; i++) {
      const rec = data[i] as Record<string, Object>;
      if (rec === undefined || rec === null) {
        continue;
      }
      if (`${rec['platform'] ?? ''}`.length === 0) {
        rec['platform'] = platform as Object;
      }
    }
  }

  async getMediaSource(item: MusicItem, quality: string, allowFallback: boolean = true): Promise<MediaSource> {
    const source = new MediaSource();
    if (item.platform === LOCAL_PLATFORM) {
      source.url = item.url;
      return source;
    }
    if (item.url.indexOf('file://') === 0 || (item.url.indexOf('/') === 0 && item.url.indexOf('http') !== 0)) {
      source.url = item.url;
      return source;
    }
    if (AppChannel.isStore()) {
      return source;
    }
    if (allowFallback) {
      const direct = this.pickItemAudioUrl(item);
      if (direct.length > 0) {
        source.url = direct;
        return source;
      }
    }
    const plugin = this.findByPlatform(item.platform);
    const cacheControl = plugin !== null && plugin.cacheControl.length > 0 ? plugin.cacheControl : 'no-cache';
    if (allowFallback && cacheControl === 'cache') {
      const cached = this.sourceFromCache(item);
      if (cached !== null) {
        return cached;
      }
    }
    let parser: PluginMeta | null = plugin;
    if (plugin !== null && plugin.alternativePlugin.length > 0) {
      const alt = this.findByPlatform(plugin.alternativePlugin);
      if (alt !== null && this.hasMethod(alt, 'getMediaSource')) {
        parser = alt;
      }
    }
    if (parser === null || !this.hasMethod(parser, 'getMediaSource')) {
      source.url = this.isDirectAudioUrl(item.url) ? item.url : '';
      return source;
    }
    const qualities = allowFallback ? this.playQualityOrder(quality) : [quality];
    const timeoutMs = allowFallback ? 0 : 12000;
    for (let i = 0; i < qualities.length; i++) {
      let parsed = await this.fetchMediaSource(parser.hash, item, qualities[i], timeoutMs);
      if (parsed === null) {
        await this.delayMs(150);
        parsed = await this.fetchMediaSource(parser.hash, item, qualities[i], timeoutMs);
      }
      if (parsed !== null && parsed.url.length > 0 && !this.isHlsUrl(parsed.url)) {
        if (cacheControl !== 'no-store') {
          this.saveSourceCache(item, parsed);
        }
        return parsed;
      }
    }
    if (!allowFallback) {
      return source;
    }
    const fallback = this.pickItemAudioUrl(item);
    source.url = fallback.length > 0 ? fallback : (this.isDirectAudioUrl(item.url) ? item.url : '');
    return source;
  }

  private playQualityOrder(preferred: string): string[] {
    const keys: string[] = ['low', 'standard', 'high', 'super'];
    let idx = 1;
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] === preferred) {
        idx = i;
        break;
      }
    }
    const left: string[] = [];
    const right: string[] = [];
    for (let i = 0; i < idx; i++) {
      left.push(keys[i]);
    }
    for (let j = idx + 1; j < keys.length; j++) {
      right.push(keys[j]);
    }
    const out: string[] = [];
    out.push(keys[idx]);
    const sort = AppConfig.getString(KEYS.PLAY_QUALITY_ORDER, 'asc');
    if (sort === 'desc') {
      for (let a = left.length - 1; a >= 0; a--) {
        out.push(left[a]);
      }
      for (let b = 0; b < right.length; b++) {
        out.push(right[b]);
      }
    } else {
      for (let b = 0; b < right.length; b++) {
        out.push(right[b]);
      }
      for (let a = left.length - 1; a >= 0; a--) {
        out.push(left[a]);
      }
    }
    return out;
  }

  private pickItemAudioUrl(item: MusicItem): string {
    if (this.isDirectAudioUrl(item.url)) {
      return item.url;
    }
    try {
      const obj = JSON.parse(item.rawJson) as Record<string, Object>;
      const sound = `${obj['soundurl'] ?? ''}`;
      if (this.isDirectAudioUrl(sound)) {
        return sound;
      }
    } catch (_e) {
    }
    return '';
  }

  private isHlsUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    return lower.indexOf('.m3u8') >= 0 || lower.indexOf('/hls.') >= 0 || lower.indexOf('/hls?') >= 0;
  }

  private isDirectAudioUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    if (lower.indexOf('http://') !== 0 && lower.indexOf('https://') !== 0) {
      return false;
    }
    if (this.isHlsUrl(lower)) {
      return false;
    }
    const marks: string[] = ['.m4a', '.mp3', '.aac', '.flac', '.ogg', '.wav', '.opus'];
    for (let i = 0; i < marks.length; i++) {
      if (lower.indexOf(marks[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  async getMusicInfo(item: MusicItem): Promise<MusicItem | null> {
    const plugin = this.findByPlatform(item.platform);
    if (plugin === null || !this.hasMethod(plugin, 'getMusicInfo')) {
      return null;
    }
    const raw = await this.callQuiet(plugin.hash, 'getMusicInfo', `[${item.toPluginJson()}]`);
    const info = this.parseMusicItemRaw(raw);
    if (info === null) {
      return null;
    }
    if (info.platform.length === 0) {
      info.platform = plugin.platform;
    }
    if (info.id.length === 0) {
      info.id = item.id;
    }
    if (info.title.length === 0) {
      info.title = item.title;
    }
    if (info.artist.length === 0) {
      info.artist = item.artist;
    }
    if (info.album.length === 0) {
      info.album = item.album;
    }
    if (info.artwork.length === 0) {
      info.artwork = item.artwork;
    }
    if (info.url.length === 0) {
      info.url = item.url;
    }
    return info;
  }

  async importMusicItem(hash: string, url: string): Promise<MusicItem | null> {
    const plugin = this.findByHash(hash);
    if (plugin === null || !this.hasMethod(plugin, 'importMusicItem')) {
      return null;
    }
    const raw = await this.callQuiet(plugin.hash, 'importMusicItem', JSON.stringify([url]));
    const single = this.parseMusicItemRaw(raw);
    if (single !== null) {
      if (single.platform.length === 0) {
        single.platform = plugin.platform;
      }
      return single;
    }
    const list = this.parseImportResult(raw);
    if (list.length === 0) {
      return null;
    }
    if (list[0].platform.length === 0) {
      list[0].platform = plugin.platform;
    }
    return list[0];
  }

  async getMusicComments(item: MusicItem, page: number): Promise<CommentPageResult> {
    const result = new CommentPageResult();
    const plugin = this.findByPlatform(item.platform);
    if (plugin === null || !this.hasMethod(plugin, 'getMusicComments')) {
      return result;
    }
    const raw = await this.callQuiet(plugin.hash, 'getMusicComments', `[${item.toPluginJson()},${page}]`);
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      const data = obj['data'];
      if (Array.isArray(data)) {
        const arr = data as Object[];
        const comments: CommentItem[] = [];
        for (let i = 0; i < arr.length; i++) {
          comments.push(this.parseComment(arr[i]));
        }
        result.data = comments;
      }
      const isEndText = `${obj['isEnd']}`;
      if (isEndText === 'false' || isEndText === '0') {
        result.isEnd = false;
      } else {
        result.isEnd = true;
      }
    } catch (_e) {
    }
    return result;
  }

  async setUserVariables(hash: string, values: Record<string, string>): Promise<void> {
    const plugin = this.findByHash(hash);
    if (plugin === null) {
      return;
    }
    plugin.userVariableValues = this.copyStringRecord(values);
    this.saveOrder();
    const code = AppStorageUtil.readText(plugin.path);
    const remounted = await this.mount(plugin.path, code, plugin.userVariableValues);
    remounted.hash = plugin.hash;
    remounted.path = plugin.path;
    remounted.enabled = plugin.enabled;
    remounted.order = plugin.order;
    remounted.srcUrl = plugin.srcUrl.length > 0 ? plugin.srcUrl : remounted.srcUrl;
    remounted.alternativePlugin = plugin.alternativePlugin;
    remounted.userVariableValues = plugin.userVariableValues;
    const next: PluginMeta[] = [];
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].hash === hash) {
        next.push(remounted);
      } else {
        next.push(this.plugins[i]);
      }
    }
    this.plugins = next;
    this.saveOrder();
    this.emit();
  }

  setAlternativePlugin(hash: string, platform: string): void {
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].hash === hash) {
        this.plugins[i].alternativePlugin = platform;
      }
    }
    this.saveOrder();
    this.emit();
  }

  getAlternativePluginName(plugin: PluginMeta): string {
    return plugin.alternativePlugin;
  }

  parseRecommendTags(raw: string): RecommendTagsResult {
    const result = new RecommendTagsResult();
    if (raw.length === 0 || raw === 'null') {
      return result;
    }
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      result.pinned = this.parseTagList(obj['pinned']);
      const groups = obj['data'];
      if (Array.isArray(groups)) {
        const arr = groups as Object[];
        const data: RecommendTagGroup[] = [];
        for (let i = 0; i < arr.length; i++) {
          const row = arr[i] as Record<string, Object>;
          const group = new RecommendTagGroup();
          group.title = row['title'] ? `${row['title']}` : '';
          group.data = this.parseTagList(row['data']);
          data.push(group);
        }
        result.data = data;
      }
    } catch (_e) {
    }
    return result;
  }

  async getRecommendTagsParsed(platform: string): Promise<RecommendTagsResult> {
    const raw = await this.getRecommendTags(platform);
    return this.parseRecommendTags(raw);
  }

  private sourceFromCache(item: MusicItem): MediaSource | null {
    const cached = MediaCache.get(item);
    if (cached.length === 0) {
      return null;
    }
    try {
      const obj = JSON.parse(cached) as Record<string, Object>;
      const url = obj['url'] ? `${obj['url']}` : '';
      if (url.indexOf('http') !== 0) {
        return null;
      }
      const source = new MediaSource();
      source.url = url;
      source.userAgent = obj['userAgent'] ? `${obj['userAgent']}` : '';
      const headers = obj['headers'] as Record<string, Object>;
      if (headers) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          source.headers[keys[i]] = `${headers[keys[i]]}`;
        }
      }
      return source;
    } catch (_e) {
      return null;
    }
  }

  private saveSourceCache(item: MusicItem, source: MediaSource): void {
    try {
      const obj = JSON.parse(item.toPluginJson()) as Record<string, Object>;
      obj['url'] = source.url;
      obj['userAgent'] = source.userAgent;
      obj['headers'] = source.headers;
      const copy = MusicItem.fromJson(JSON.stringify(obj));
      copy.url = source.url;
      MediaCache.set(copy);
    } catch (_e) {
    }
  }

  async getLyric(item: MusicItem): Promise<LyricSource> {
    const source = new LyricSource();
    const plugin = this.findByPlatform(item.platform);
    if (plugin === null || !this.hasMethod(plugin, 'getLyric')) {
      return source;
    }
    const raw = await this.safeCall(plugin.hash, 'getLyric', `[${item.toPluginJson()}]`, 12000);
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      let rawLrc = obj['rawLrc'] ? `${obj['rawLrc']}` : '';
      const lrc = obj['lrc'] ? `${obj['lrc']}` : '';
      const translation = obj['translation'] ? `${obj['translation']}` : '';
      if (rawLrc.length === 0 && lrc.length > 0) {
        rawLrc = lrc;
      }
      if (rawLrc.length > 0) {
        source.rawLrc = await this.resolveLyricText(rawLrc);
      }
      if (translation.length > 0) {
        source.translation = await this.resolveLyricText(translation);
      }
    } catch (_e) {
    }
    return source;
  }

  async searchLyric(query: string, page: number): Promise<MusicItem[]> {
    const plugins = this.searchablePlugins('lyric');
    const tasks: Promise<string>[] = [];
    const platforms: string[] = [];
    for (let i = 0; i < plugins.length; i++) {
      const p = plugins[i];
      if (p.supportedSearchType.length > 0 && p.supportedSearchType.indexOf('lyric') < 0) {
        continue;
      }
      if (!this.hasMethod(p, 'getLyric') && p.supportedSearchType.indexOf('lyric') < 0) {
        continue;
      }
      tasks.push(this.callQuiet(p.hash, 'search', JSON.stringify([query, page, 'lyric']), PLUGIN_SEARCH_TIMEOUT));
      platforms.push(p.platform);
    }
    const results = await Promise.all(tasks);
    const merged: MusicItem[] = [];
    for (let i = 0; i < results.length; i++) {
      this.appendSearchLyric(merged, results[i], platforms[i]);
    }
    return merged;
  }

  private appendSearchLyric(merged: MusicItem[], raw: string, platform: string): void {
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const arr = parsed as Object[];
        for (let i = 0; i < arr.length; i++) {
          const item = MusicItem.fromJson(JSON.stringify(arr[i]));
          if (item.platform.length === 0) {
            item.platform = platform;
          }
          item.rawJson = this.injectPlatformOnRaw(item.rawJson, item.platform);
          merged.push(item);
        }
        return;
      }
      const obj = parsed as Record<string, Object>;
      const data = obj['data'] as Object[];
      if (Array.isArray(data)) {
        for (let j = 0; j < data.length; j++) {
          const item = MusicItem.fromJson(JSON.stringify(data[j]));
          if (item.platform.length === 0) {
            item.platform = platform;
          }
          item.rawJson = this.injectPlatformOnRaw(item.rawJson, item.platform);
          merged.push(item);
        }
      }
    } catch (_e) {
    }
  }

  private async resolveLyricText(value: string): Promise<string> {
    const text = value.trim();
    if (text.length === 0) {
      return '';
    }
    if (text.indexOf('http://') === 0 || text.indexOf('https://') === 0) {
      try {
        return await HttpUtil.getText(text);
      } catch (_e) {
        return '';
      }
    }
    return text;
  }

  async getAlbumInfo(album: AlbumItem, page: number): Promise<MusicItem[]> {
    const plugin = this.findByPlatform(album.platform);
    if (plugin === null) {
      return [];
    }
    const raw = await this.safeCall(plugin.hash, 'getAlbumInfo', `[${album.toPluginJson()},${page}]`);
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      return this.injectPlatformOnMusics(parseMusicList(JSON.stringify(obj['musicList'] || [])), plugin.platform);
    } catch (_e) {
      return [];
    }
  }

  async getSheetInfo(sheet: SheetItem, page: number, kind: string = 'sheet'): Promise<SheetPageResult> {
    const result = new SheetPageResult();
    const plugin = this.findByPlatform(sheet.platform);
    if (plugin === null) {
      return result;
    }
    const useTopList = kind === 'topList' && this.hasMethod(plugin, 'getTopListDetail');
    if (useTopList) {
      const raw = await this.safeCall(plugin.hash, 'getTopListDetail', `[${sheet.toPluginJson()},${page}]`);
      return this.parseSheetPage(raw, plugin.platform);
    }
    if (this.isAudiomack(plugin.platform)) {
      const nativeRaw = await AudiomackApi.sheetInfo(sheet.id);
      const nativePage = this.parseSheetPage(nativeRaw, plugin.platform);
      if (nativePage.musics.length > 0) {
        return nativePage;
      }
    }
    if (this.hasMethod(plugin, 'getMusicSheetInfo')) {
      const raw = await this.safeCall(plugin.hash, 'getMusicSheetInfo', `[${sheet.toPluginJson()},${page}]`);
      return this.parseSheetPage(raw, plugin.platform);
    }
    if (this.hasMethod(plugin, 'getTopListDetail')) {
      const raw = await this.safeCall(plugin.hash, 'getTopListDetail', `[${sheet.toPluginJson()},${page}]`);
      return this.parseSheetPage(raw, plugin.platform);
    }
    try {
      const obj = JSON.parse(sheet.rawJson) as Record<string, Object>;
      if (Array.isArray(obj['musicList'])) {
        result.musics = this.injectPlatformOnMusics(parseMusicList(JSON.stringify(obj['musicList'])), plugin.platform);
      }
    } catch (_e) {
    }
    result.isEnd = true;
    return result;
  }

  async getArtistWorks(artist: ArtistItem, page: number, type: string): Promise<string> {
    const plugin = this.findByPlatform(artist.platform);
    if (plugin === null || !this.hasMethod(plugin, 'getArtistWorks')) {
      return '[]';
    }
    const raw = await this.safeCall(plugin.hash, 'getArtistWorks', `[${artist.toPluginJson()},${page},${JSON.stringify(type)}]`);
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        this.fillSearchPlatform(parsed as Object[], plugin.platform);
        return JSON.stringify(parsed);
      }
      const obj = parsed as Record<string, Object>;
      const data = obj['data'] ?? obj['musicList'] ?? obj['albumList'];
      if (Array.isArray(data)) {
        this.fillSearchPlatform(data as Object[], plugin.platform);
        return JSON.stringify(data);
      }
    } catch (_e) {
    }
    return '[]';
  }

  async getTopLists(platform: string): Promise<string> {
    const plugin = this.findByPlatform(platform);
    if (plugin === null) {
      return '[]';
    }
    return this.safeCall(plugin.hash, 'getTopLists', '[]');
  }

  async getTopListDetail(sheet: SheetItem, page: number): Promise<MusicItem[]> {
    const plugin = this.findByPlatform(sheet.platform);
    if (plugin === null) {
      return [];
    }
    const raw = await this.safeCall(plugin.hash, 'getTopListDetail', `[${sheet.toPluginJson()},${page}]`);
    return this.parseSheetPage(raw, plugin.platform).musics;
  }

  async getRecommendTags(platform: string): Promise<string> {
    if (this.isAudiomack(platform)) {
      try {
        return await AudiomackApi.recommendTags();
      } catch (_e) {
        return '{}';
      }
    }
    const plugin = this.findByPlatform(platform);
    if (plugin === null) {
      return '{}';
    }
    return this.callQuiet(plugin.hash, 'getRecommendSheetTags', '[]');
  }

  async getRecommendSheets(platform: string, tag: string, page: number): Promise<SheetItem[]> {
    const plugin = this.findByPlatform(platform);
    if (plugin === null) {
      return [];
    }
    const tagArg = this.audiomackTagJson(platform, tag);
    if (this.isAudiomack(platform)) {
      try {
        const nativeRaw = await AudiomackApi.recommendSheets(tagArg, page);
        return this.injectPlatformOnSheets(this.parseRecommendSheetData(nativeRaw), platform);
      } catch (_e) {
        return [];
      }
    }
    let raw = await this.safeCall(plugin.hash, 'getRecommendSheetsByTag', `[${tagArg},${page}]`);
    let list = this.parseRecommendSheetData(raw);
    if (list.length === 0) {
      await this.delayMs(400);
      raw = await this.safeCall(plugin.hash, 'getRecommendSheetsByTag', `[${tagArg},${page}]`);
      list = this.parseRecommendSheetData(raw);
    }
    return this.injectPlatformOnSheets(list, platform);
  }

  private isAudiomack(platform: string): boolean {
    return platform.toLowerCase().indexOf('audiomack') >= 0;
  }

  private audiomackTagJson(platform: string, tag: string): string {
    if (!this.isAudiomack(platform) || tag.length === 0) {
      return tag;
    }
    try {
      const obj = JSON.parse(tag) as Record<string, Object>;
      const slug = obj['url_slug'] ? `${obj['url_slug']}` : '';
      if (slug.length > 0) {
        return tag;
      }
      const id = obj['id'] ? `${obj['id']}` : '';
      if (id.length === 0) {
        return JSON.stringify({
          'id': '34',
          'title': "What's New",
          'url_slug': 'whats-new'
        });
      }
    } catch (_e) {
    }
    return tag;
  }

  private parseRecommendSheetData(raw: string): SheetItem[] {
    if (raw.length === 0 || raw === 'null') {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        return parseSheetList(JSON.stringify(parsed));
      }
      const obj = parsed as Record<string, Object>;
      if (Array.isArray(obj['data'])) {
        return parseSheetList(JSON.stringify(obj['data']));
      }
      const results = obj['results'];
      if (results !== undefined && results !== null && typeof results === 'object') {
        const resObj = results as Record<string, Object>;
        if (Array.isArray(resObj['playlists'])) {
          return parseSheetList(JSON.stringify(resObj['playlists']));
        }
      }
    } catch (_e) {
    }
    return [];
  }

  private parseSheetPage(raw: string, platform: string): SheetPageResult {
    const result = new SheetPageResult();
    if (raw.length === 0 || raw === 'null') {
      result.isEnd = true;
      return result;
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        result.musics = this.injectPlatformOnMusics(parseMusicList(JSON.stringify(parsed)), platform);
        result.isEnd = true;
        return result;
      }
      const obj = parsed as Record<string, Object>;
      let listRaw = '[]';
      if (Array.isArray(obj['musicList'])) {
        listRaw = JSON.stringify(obj['musicList']);
      } else if (Array.isArray(obj['data'])) {
        listRaw = JSON.stringify(obj['data']);
      }
      result.musics = this.injectPlatformOnMusics(parseMusicList(listRaw), platform);
      result.isEnd = obj['isEnd'] === false || `${obj['isEnd']}` === 'false' ? false : true;
      let sheetVal = obj['sheetItem'];
      if (sheetVal === undefined || sheetVal === null) {
        sheetVal = obj['topListItem'];
      }
      if (sheetVal === undefined || sheetVal === null) {
        sheetVal = obj['albumItem'];
      }
      if (sheetVal !== undefined && sheetVal !== null && typeof sheetVal === 'object') {
        const rec = sheetVal as Record<string, Object>;
        result.title = rec['title'] ? `${rec['title']}` : '';
        result.coverImg = rec['coverImg'] ? `${rec['coverImg']}` : (rec['artwork'] ? `${rec['artwork']}` : '');
        result.description = rec['description'] ? `${rec['description']}` : '';
        const works = Number(`${rec['worksNum'] ?? 0}`);
        result.worksNum = Number.isNaN(works) ? 0 : works;
      }
      if (result.title.length === 0 && obj['title'] !== undefined && obj['title'] !== null) {
        result.title = `${obj['title']}`;
      }
      if (result.coverImg.length === 0) {
        result.coverImg = obj['coverImg'] ? `${obj['coverImg']}` : (obj['artwork'] ? `${obj['artwork']}` : '');
      }
    } catch (_e) {
    }
    return result;
  }

  private injectPlatformOnSheets(list: SheetItem[], platform: string): SheetItem[] {
    if (platform.length === 0) {
      return list;
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i].platform.length === 0) {
        list[i].platform = platform;
      }
      list[i].rawJson = this.injectPlatformOnRaw(list[i].rawJson, platform);
    }
    return list;
  }

  private injectPlatformOnMusics(list: MusicItem[], platform: string): MusicItem[] {
    if (platform.length === 0) {
      return list;
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i].platform.length === 0) {
        list[i].platform = platform;
      }
      list[i].rawJson = this.injectPlatformOnRaw(list[i].rawJson, platform);
    }
    return list;
  }

  private injectPlatformOnRaw(raw: string, platform: string): string {
    if (platform.length === 0) {
      return raw;
    }
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      if (`${obj['platform'] ?? ''}`.length === 0) {
        obj['platform'] = platform as Object;
        return JSON.stringify(obj);
      }
    } catch (_e) {
    }
    return raw;
  }

  async updateAll(): Promise<string> {
    let ok = 0;
    let fail = 0;
    let skip = 0;
    const list = this.plugins.slice();
    for (let i = 0; i < list.length; i++) {
      const src = list[i].srcUrl;
      if (src.length === 0 || !src.startsWith('http')) {
        skip += 1;
        continue;
      }
      try {
        await this.installFromUrl(src);
        ok += 1;
      } catch (_e) {
        fail += 1;
      }
    }
    if (ok === 0 && fail === 0) {
      return skip > 0 ? I18n.t('toast.noPluginToUpdate') : I18n.t('toast.noPlugin');
    }
    return I18n.t('toast.updatePluginResult').replace('{ok}', `${ok}`).replace('{fail}', `${fail}`);
  }

  async updateFromSubscribe(): Promise<string> {
    const subs = this.getSubscribes();
    if (subs.length === 0) {
      throw new Error(I18n.t('toast.noSubscription'));
    }
    let ok = 0;
    let fail = 0;
    for (let i = 0; i < subs.length; i++) {
      try {
        await this.installFromUrl(subs[i].url);
        ok += 1;
      } catch (_e) {
        fail += 1;
      }
    }
    if (ok === 0) {
      throw new Error(I18n.t('toast.allSubscribeUpdateFailed'));
    }
    return I18n.t('toast.subscribeUpdateResult').replace('{ok}', `${ok}`).replace('{fail}', `${fail}`);
  }

  getSubscribes(): PluginSubscribeItem[] {
    const raw = AppStorageUtil.readText(this.subscribePath());
    const list: PluginSubscribeItem[] = [];
    if (raw.length === 0) {
      return list;
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const arr = parsed as Object[];
        for (let i = 0; i < arr.length; i++) {
          const obj = arr[i] as Record<string, Object>;
          const item = new PluginSubscribeItem();
          item.name = obj['name'] ? `${obj['name']}` : I18n.t('pluginSubscribe.defaultName');
          item.url = obj['url'] ? `${obj['url']}` : '';
          if (item.url.length > 0) {
            list.push(item);
          }
        }
        return list;
      }
    } catch (_e) {
    }
    if (raw.indexOf('http') === 0) {
      const item = new PluginSubscribeItem();
      item.name = I18n.t('pluginSubscribe.defaultName');
      item.url = raw.trim();
      list.push(item);
    }
    return list;
  }

  addSubscribe(name: string, url: string): void {
    const list = this.getSubscribes();
    for (let i = 0; i < list.length; i++) {
      if (list[i].url === url) {
        list[i].name = name;
        this.writeSubscribes(list);
        return;
      }
    }
    const item = new PluginSubscribeItem();
    item.name = name;
    item.url = url;
    list.push(item);
    this.writeSubscribes(list);
  }

  updateSubscribe(index: number, name: string, url: string): void {
    const list = this.getSubscribes();
    if (index < 0 || index >= list.length) {
      return;
    }
    list[index].name = name;
    list[index].url = url;
    this.writeSubscribes(list);
  }

  removeSubscribe(index: number): void {
    const list = this.getSubscribes();
    if (index < 0 || index >= list.length) {
      return;
    }
    const next: PluginSubscribeItem[] = [];
    for (let i = 0; i < list.length; i++) {
      if (i !== index) {
        next.push(list[i]);
      }
    }
    this.writeSubscribes(next);
  }

  movePlugin(index: number, delta: number): void {
    const list = this.sortedPlugins();
    const target = index + delta;
    if (index < 0 || target < 0 || index >= list.length || target >= list.length) {
      return;
    }
    const tmp = list[index];
    list[index] = list[target];
    list[target] = tmp;
    for (let i = 0; i < list.length; i++) {
      list[i].order = i;
    }
    this.plugins = list;
    this.saveOrder();
    this.emit();
  }

  setPluginOrder(ordered: PluginMeta[]): void {
    for (let i = 0; i < ordered.length; i++) {
      ordered[i].order = i;
      for (let j = 0; j < this.plugins.length; j++) {
        if (this.plugins[j].hash === ordered[i].hash) {
          this.plugins[j].order = i;
        }
      }
    }
    this.plugins.sort((a: PluginMeta, b: PluginMeta) => a.order - b.order);
    this.saveOrder();
    this.emit();
  }

  async importMusicSheet(url: string): Promise<MusicItem[]> {
    const enabled = this.enabledPlugins();
    for (let i = 0; i < enabled.length; i++) {
      const p = enabled[i];
      if (!this.hasMethod(p, 'importMusicSheet')) {
        continue;
      }
      const raw = await this.callQuiet(p.hash, 'importMusicSheet', JSON.stringify([url]));
      const list = this.parseImportResult(raw);
      if (list.length === 0) {
        continue;
      }
      for (let j = 0; j < list.length; j++) {
        if (list[j].platform.length === 0) {
          list[j].platform = p.platform;
        }
      }
      return list;
    }
    return [];
  }

  private parseImportResult(raw: string): MusicItem[] {
    let list = parseMusicList(raw);
    if (list.length > 0) {
      return list;
    }
    try {
      const obj = JSON.parse(raw) as Record<string, Object>;
      if (Array.isArray(obj['data'])) {
        list = parseMusicList(JSON.stringify(obj['data']));
      }
      if (list.length === 0 && Array.isArray(obj['musicList'])) {
        list = parseMusicList(JSON.stringify(obj['musicList']));
      }
    } catch (_e) {
    }
    return list;
  }

  private async callQuiet(hash: string, method: string, argsJson: string, timeoutMs: number = 45000): Promise<string> {
    try {
      return await PluginSandbox.instance().callMethod(hash, method, argsJson, timeoutMs);
    } catch (_e) {
      return 'null';
    }
  }

  private nextOrder(): number {
    let max = -1;
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].order > max) {
        max = this.plugins[i].order;
      }
    }
    return max + 1;
  }

  private metaPath(): string {
    return `${AppStorageUtil.filesRoot()}/plugin_meta.json`;
  }

  private subscribePath(): string {
    return `${AppStorageUtil.filesRoot()}/plugin_subscribe.json`;
  }

  private writeSubscribes(list: PluginSubscribeItem[]): void {
    AppStorageUtil.writeText(this.subscribePath(), JSON.stringify(list));
  }

  private saveOrder(): void {
    AppStorageUtil.writeText(this.metaPath(), JSON.stringify(this.plugins));
  }

  private readSavedList(): SavedPluginState[] {
    const list: SavedPluginState[] = [];
    const raw = AppStorageUtil.readText(this.metaPath());
    if (raw.length === 0) {
      return list;
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const arr = parsed as Object[];
        for (let i = 0; i < arr.length; i++) {
          list.push(this.savedFromRow(arr[i] as Record<string, Object>, ''));
        }
        return list;
      }
      const obj = parsed as Record<string, Object>;
      const keys = Object.keys(obj);
      for (let i = 0; i < keys.length; i++) {
        const row = obj[keys[i]] as Record<string, Object>;
        list.push(this.savedFromRow(row, keys[i]));
      }
    } catch (_e) {
    }
    return list;
  }

  private savedFromRow(row: Record<string, Object>, fallbackPlatform: string): SavedPluginState {
    const state = new SavedPluginState();
    const platform = row['platform'] ? `${row['platform']}` : fallbackPlatform;
    state.platform = platform;
    state.path = row['path'] ? `${row['path']}` : '';
    state.order = Number(`${row['order']}`) || 0;
    state.srcUrl = row['srcUrl'] ? `${row['srcUrl']}` : '';
    state.enabled = this.parseEnabled(row);
    state.alternativePlugin = row['alternativePlugin'] ? `${row['alternativePlugin']}` : '';
    state.userVariableValues = this.readStringRecord(row['userVariableValues']);
    return state;
  }

  private parseEnabled(row: Record<string, Object>): boolean {
    if (row['enabled'] === undefined || row['enabled'] === null) {
      return true;
    }
    const text = `${row['enabled']}`;
    if (text === 'false' || text === '0') {
      return false;
    }
    return true;
  }

  private findSavedByPath(list: SavedPluginState[], path: string, fileName: string): SavedPluginState | null {
    for (let i = 0; i < list.length; i++) {
      if (list[i].path.length > 0 && list[i].path === path) {
        return list[i];
      }
    }
    for (let i = 0; i < list.length; i++) {
      const savedPath = list[i].path;
      if (savedPath.length > 0 && savedPath.substring(savedPath.lastIndexOf('/') + 1) === fileName) {
        return list[i];
      }
    }
    return null;
  }

  private findSavedByPlatform(list: SavedPluginState[], platform: string): SavedPluginState | null {
    if (platform.length === 0) {
      return null;
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i].platform === platform) {
        return list[i];
      }
    }
    return null;
  }

  private findBySrcUrl(srcUrl: string): PluginMeta | null {
    for (let i = 0; i < this.plugins.length; i++) {
      if (this.plugins[i].srcUrl === srcUrl) {
        return this.plugins[i];
      }
    }
    return null;
  }

  private isJsonPluginUrl(url: string): boolean {
    let path = url.trim();
    const hashIdx = path.indexOf('#');
    if (hashIdx >= 0) {
      path = path.substring(0, hashIdx);
    }
    const queryIdx = path.indexOf('?');
    if (queryIdx >= 0) {
      path = path.substring(0, queryIdx);
    }
    const lower = path.toLowerCase();
    return lower.length >= 5 && lower.substring(lower.length - 5) === '.json';
  }

  private async fetchMediaSource(hash: string, item: MusicItem, quality: string, timeoutMs: number = 0): Promise<MediaSource | null> {
    try {
      const args = `[${item.toPluginJson()},${JSON.stringify(quality)}]`;
      const raw = timeoutMs > 0 ?
        await PluginSandbox.instance().callMethod(hash, 'getMediaSource', args, timeoutMs) :
        await PluginSandbox.instance().callMethod(hash, 'getMediaSource', args);
      return this.parseMediaSourceRaw(raw);
    } catch (_e) {
      return null;
    }
  }

  private parseMediaSourceRaw(raw: string): MediaSource | null {
    if (raw.length === 0 || raw === 'null') {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      const source = new MediaSource();
      if (typeof parsed === 'string') {
        source.url = `${parsed}`;
        return source.url.length > 0 ? source : null;
      }
      const obj = parsed as Record<string, Object>;
      source.url = obj['url'] ? `${obj['url']}` : '';
      source.userAgent = obj['userAgent'] ? `${obj['userAgent']}` : '';
      const headers = obj['headers'] as Record<string, Object>;
      if (headers) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          source.headers[keys[i]] = `${headers[keys[i]]}`;
        }
      }
      if (source.userAgent.length === 0) {
        if (source.headers['user-agent'] !== undefined) {
          source.userAgent = source.headers['user-agent'];
        } else if (source.headers['User-Agent'] !== undefined) {
          source.userAgent = source.headers['User-Agent'];
        }
      }
      if (source.url.length === 0) {
        return null;
      }
      return source;
    } catch (_e) {
      return null;
    }
  }

  private parseMusicItemRaw(raw: string): MusicItem | null {
    if (raw.length === 0 || raw === 'null' || raw === '{}') {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        return null;
      }
      const item = MusicItem.fromJson(raw);
      if (item.id.length === 0 && item.title.length === 0 && item.url.length === 0) {
        return null;
      }
      return item;
    } catch (_e) {
      return null;
    }
  }

  private parseComment(raw: Object): CommentItem {
    const item = new CommentItem();
    try {
      const obj = raw as Record<string, Object>;
      item.id = obj['id'] ? `${obj['id']}` : '';
      item.nickName = obj['nickName'] ? `${obj['nickName']}` : '';
      item.avatar = obj['avatar'] ? `${obj['avatar']}` : '';
      item.comment = obj['comment'] ? `${obj['comment']}` : '';
      item.like = Number(`${obj['like']}`) || 0;
      item.createAt = Number(`${obj['createAt']}`) || 0;
      item.location = obj['location'] ? `${obj['location']}` : '';
      const replies = obj['replies'];
      if (Array.isArray(replies)) {
        const arr = replies as Object[];
        const list: CommentItem[] = [];
        for (let i = 0; i < arr.length; i++) {
          list.push(this.parseComment(arr[i]));
        }
        item.replies = list;
      }
    } catch (_e) {
    }
    return item;
  }

  private parseTagList(raw: Object | undefined): RecommendTag[] {
    const list: RecommendTag[] = [];
    if (raw === undefined || raw === null || !Array.isArray(raw)) {
      return list;
    }
    const arr = raw as Object[];
    for (let i = 0; i < arr.length; i++) {
      const row = arr[i] as Record<string, Object>;
      const tag = new RecommendTag();
      tag.id = row['id'] ? `${row['id']}` : '';
      if (row['title']) {
        tag.title = `${row['title']}`;
      } else if (row['name']) {
        tag.title = `${row['name']}`;
      }
      if (row['url_slug']) {
        tag.urlSlug = `${row['url_slug']}`;
      } else if (row['urlSlug']) {
        tag.urlSlug = `${row['urlSlug']}`;
      }
      list.push(tag);
    }
    return list;
  }

  private infoText(info: Record<string, Object>, key: string): string {
    const raw = info[key];
    if (raw === undefined || raw === null) {
      return '';
    }
    const text = `${raw}`.trim();
    if (text === 'undefined' || text === 'null') {
      return '';
    }
    return text;
  }

  private parseUserVarList(raw: Object | undefined): PluginUserVar[] {
    const list: PluginUserVar[] = [];
    if (raw === undefined || raw === null || !Array.isArray(raw)) {
      return list;
    }
    const arr = raw as Object[];
    for (let i = 0; i < arr.length; i++) {
      try {
        const row = arr[i] as Record<string, Object>;
        const item = new PluginUserVar();
        item.key = row['key'] ? `${row['key']}` : '';
        item.name = row['name'] ? `${row['name']}` : '';
        item.hint = row['hint'] ? `${row['hint']}` : '';
        if (item.key.length > 0) {
          list.push(item);
        }
      } catch (_e) {
      }
    }
    return list;
  }

  private applyHints(meta: PluginMeta, raw: Object | undefined): void {
    if (raw === undefined || raw === null) {
      return;
    }
    try {
      const hints = raw as Record<string, Object>;
      meta.hintsImportMusic = this.hintToString(hints['importMusicItem']);
      meta.hintsImportSheet = this.hintToString(hints['importMusicSheet']);
    } catch (_e) {
    }
  }

  private hintToString(v: Object | undefined): string {
    if (v === undefined || v === null) {
      return '';
    }
    if (Array.isArray(v)) {
      const arr = v as Object[];
      const parts: string[] = [];
      for (let i = 0; i < arr.length; i++) {
        parts.push(`${arr[i]}`);
      }
      return parts.join('\n');
    }
    return `${v}`;
  }

  private emptyVars(): Record<string, string> {
    return this.copyStringRecord(new SavedPluginState().userVariableValues);
  }

  private copyStringRecord(src: Record<string, string>): Record<string, string> {
    const out: Record<string, string> = {};
    const keys = Object.keys(src);
    for (let i = 0; i < keys.length; i++) {
      out[keys[i]] = src[keys[i]];
    }
    return out;
  }

  private readStringRecord(v: Object | undefined): Record<string, string> {
    const out: Record<string, string> = {};
    if (v === undefined || v === null) {
      return out;
    }
    try {
      const obj = v as Record<string, Object>;
      const keys = Object.keys(obj);
      for (let i = 0; i < keys.length; i++) {
        out[keys[i]] = `${obj[keys[i]]}`;
      }
    } catch (_e) {
    }
    return out;
  }

  private recordHasKeys(map: Record<string, string>): boolean {
    return Object.keys(map).length > 0;
  }

  private delayMs(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  private async safeCall(hash: string, method: string, argsJson: string, timeoutMs: number = 0): Promise<string> {
    try {
      if (timeoutMs > 0) {
        return await PluginSandbox.instance().callMethod(hash, method, argsJson, timeoutMs);
      }
      return await PluginSandbox.instance().callMethod(hash, method, argsJson);
    } catch (e) {
      showToast(e instanceof Error ? e.message : I18n.t('toast.pluginCallFail'));
      return 'null';
    }
  }
}
