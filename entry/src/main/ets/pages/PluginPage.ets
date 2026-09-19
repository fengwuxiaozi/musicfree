import { PluginMeta, PluginUserVar, MusicItem, SheetItem, InstallPluginResult } from '../common/Types';
import { ROUTES } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppStorageUtil } from '../core/AppStorageUtil';
import { HttpUtil } from '../core/HttpUtil';

class UserVarRow {
  key: string = '';
  name: string = '';
  hint: string = '';
  value: string = '';
}

@Component
export struct PluginPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;
  @State plugins: PluginMeta[] = [];
  @State showInstall: boolean = false;
  @State pluginUrl: string = '';
  @State installing: boolean = false;
  @State busy: boolean = false;
  @State showUninstall: boolean = false;
  @State uninstallHash: string = '';
  @State uninstallName: string = '';
  @State showUninstallAll: boolean = false;
  @State showFabMenu: boolean = false;
  @State showDesc: boolean = false;
  @State descTitle: string = '';
  @State descText: string = '';
  @State showAlt: boolean = false;
  @State altHash: string = '';
  @State altPlatforms: string[] = [];
  @State altSelected: string = '';
  @State showImportInput: boolean = false;
  @State importMode: number = 0;
  @State importHash: string = '';
  @State importName: string = '';
  @State importUrl: string = '';
  @State importHint: string = '';
  @State importing: boolean = false;
  @State showImportConfirm: boolean = false;
  @State importConfirmContent: string = '';
  @State pendingMusics: MusicItem[] = [];
  @State newSheetDefaultName: string = '';
  @State showAddToSheet: boolean = false;
  @State sheetOptions: SheetItem[] = [];
  @State showUserVars: boolean = false;
  @State userVarHash: string = '';
  @State userVarItems: UserVarRow[] = [];
  @State showInstallFail: boolean = false;
  @State installFailDetail: string = '';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  private listening: boolean = false;

  aboutToAppear(): void {
    this.refresh();
    if (this.listening) {
      return;
    }
    this.listening = true;
    AppService.plugins.onChange(() => {
      this.refresh();
    });
  }

  private refresh(): void {
    this.plugins = AppService.plugins.sortedPlugins();
  }

  private pluginName(p: PluginMeta): string {
    return p.platform.length > 0 ? p.platform : I18n.tx(this.appLocale, 'common.unknownPlugin');
  }

  private hasMethod(p: PluginMeta, method: string): boolean {
    return p.methods.indexOf(method) >= 0;
  }

  private stripUrlTail(url: string): string {
    let s = url.trim();
    const hashIdx = s.indexOf('#');
    if (hashIdx >= 0) {
      s = s.substring(0, hashIdx);
    }
    const queryIdx = s.indexOf('?');
    if (queryIdx >= 0) {
      s = s.substring(0, queryIdx);
    }
    return s;
  }

  private isPluginResourceUrl(url: string): boolean {
    const trimmed = url.trim();
    if (trimmed.length === 0) {
      return false;
    }
    const lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    const path = this.stripUrlTail(trimmed).toLowerCase();
    return path.endsWith('.js') || path.endsWith('.json');
  }

  private pathIsJson(url: string): boolean {
    return this.stripUrlTail(url).toLowerCase().endsWith('.json');
  }

  private pluginSrcFromRow(item: Record<string, Object>): string {
    const raw = item['url'] !== undefined && item['url'] !== null ? item['url'] : item['srcUrl'];
    if (raw === undefined || raw === null) {
      return '';
    }
    const src = `${raw}`.trim();
    if (src.length === 0 || src === 'undefined' || src === 'null') {
      return '';
    }
    return src;
  }

  private looksLikeJsonUrl(url: string): boolean {
    if (this.pathIsJson(url)) {
      return true;
    }
    const path = this.stripUrlTail(url).toLowerCase();
    if (path.endsWith('.js')) {
      return false;
    }
    return url.toLowerCase().indexOf('.json') >= 0;
  }

  private codeLooksLikePluginList(code: string): boolean {
    const trimmed = code.trim();
    if (!trimmed.startsWith('{')) {
      return false;
    }
    try {
      const parsed = JSON.parse(trimmed) as Record<string, Object>;
      return parsed['plugins'] instanceof Array;
    } catch (_e) {
      return false;
    }
  }

  private failResult(url: string, message: string): InstallPluginResult {
    const result = new InstallPluginResult();
    result.pluginUrl = url;
    result.message = message;
    result.success = false;
    return result;
  }

  private okResult(url: string): InstallPluginResult {
    const result = new InstallPluginResult();
    result.pluginUrl = url;
    result.success = true;
    return result;
  }

  private confirmUninstall(p: PluginMeta): void {
    this.uninstallHash = p.hash;
    this.uninstallName = this.pluginName(p);
    this.showUninstall = true;
  }

  private doUninstall(): void {
    AppService.plugins.uninstall(this.uninstallHash);
    this.showUninstall = false;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pluginUninstalled'), duration: 1500 });
  }

  async doUninstallAll(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.showUninstallAll = false;
    this.busy = true;
    try {
      await AppService.plugins.uninstallAll();
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pluginUninstalled'), duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.pluginUninstalled'), duration: 2500 });
    }
    this.busy = false;
  }

  private openDesc(p: PluginMeta): void {
    this.descTitle = this.pluginName(p);
    this.descText = p.description;
    this.showDesc = true;
  }

  private openAlt(p: PluginMeta): void {
    const options: string[] = [''];
    const sources = AppService.plugins.pluginsWithMethod('getMediaSource');
    for (let i = 0; i < sources.length; i++) {
      options.push(sources[i].platform);
    }
    if (p.alternativePlugin.length > 0 && options.indexOf(p.alternativePlugin) < 0) {
      options.push(p.alternativePlugin);
    }
    this.altHash = p.hash;
    this.altPlatforms = options;
    this.altSelected = p.alternativePlugin;
    this.showAlt = true;
  }

  private applyAlt(platform: string): void {
    let next = platform;
    const current = AppService.plugins.findByHash(this.altHash);
    if (current !== null && next === current.platform) {
      next = '';
    }
    AppService.plugins.setAlternativePlugin(this.altHash, next);
    this.showAlt = false;
    this.refresh();
  }

  private openImportMusic(p: PluginMeta): void {
    this.importMode = 0;
    this.importHash = p.hash;
    this.importName = this.pluginName(p);
    this.importUrl = '';
    this.importHint = p.hintsImportMusic;
    this.showImportInput = true;
  }

  private openImportSheet(p: PluginMeta): void {
    this.importMode = 1;
    this.importHash = p.hash;
    this.importName = this.pluginName(p);
    this.importUrl = '';
    this.importHint = p.hintsImportSheet;
    this.showImportInput = true;
  }

  private openUserVars(p: PluginMeta): void {
    const rows: UserVarRow[] = [];
    for (let i = 0; i < p.userVariables.length; i++) {
      const item: PluginUserVar = p.userVariables[i];
      const row = new UserVarRow();
      row.key = item.key;
      row.name = item.name;
      row.hint = item.hint;
      const saved = p.userVariableValues[item.key];
      row.value = saved !== undefined ? saved : '';
      rows.push(row);
    }
    this.userVarHash = p.hash;
    this.userVarItems = rows;
    this.showUserVars = true;
  }

  private sharePlugin(srcUrl: string): void {
    if (srcUrl.length === 0) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.failToSharePlugin'), duration: 2000 });
      return;
    }
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, srcUrl);
      board.setData(data);
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.copiedToClipboard'), duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.failToSharePlugin'), duration: 2000 });
    }
  }

  async updateOnePlugin(srcUrl: string): Promise<void> {
    if (srcUrl.length === 0) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.noUpdateSource'), duration: 2000 });
      return;
    }
    try {
      await AppService.plugins.installFromUrl(srcUrl);
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pluginUpdateSuccess'), duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.failToUpdatePlugin'), duration: 2500 });
    }
  }

  async saveUserVars(): Promise<void> {
    const values: Record<string, string> = {};
    for (let i = 0; i < this.userVarItems.length; i++) {
      const row = this.userVarItems[i];
      if (row.key.length > 0) {
        values[row.key] = row.value;
      }
    }
    AppService.plugins.setUserVariables(this.userVarHash, values);
    this.showUserVars = false;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.settingSuccess'), duration: 1500 });
    this.refresh();
  }

  async install(): Promise<void> {
    const url = this.pluginUrl.trim();
    if (url.length === 0) {
      return;
    }
    if (!this.isPluginResourceUrl(url)) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pluginUrlInvalid'), duration: 2000 });
      return;
    }
    this.installing = true;
    try {
      const results = await this.installFromInput(url);
      this.reportInstallResults(results, true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.installPluginFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.installing = false;
  }

  private async installFromInput(url: string): Promise<InstallPluginResult[]> {
    if (this.looksLikeJsonUrl(url)) {
      return await this.installJsonText(await HttpUtil.getText(url), url);
    }
    try {
      await AppService.plugins.installFromUrl(url);
      const list: InstallPluginResult[] = [];
      list.push(this.okResult(url));
      return list;
    } catch (e) {
      const list: InstallPluginResult[] = [];
      list.push(this.failResult(url, e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.installPluginFail')));
      return list;
    }
  }

  private async installJsonText(code: string, source: string): Promise<InstallPluginResult[]> {
    try {
      const parsed = JSON.parse(code) as Record<string, Object>;
      const maybePlugins = parsed['plugins'];
      if (!(maybePlugins instanceof Array)) {
        const list: InstallPluginResult[] = [];
        list.push(this.failResult(source, I18n.tx(this.appLocale, 'toast.subscriptionInvalid')));
        return list;
      }
      const results: InstallPluginResult[] = [];
      for (let i = 0; i < maybePlugins.length; i++) {
        const item = maybePlugins[i] as Record<string, Object>;
        const src = this.pluginSrcFromRow(item);
        if (src.length === 0) {
          results.push(this.failResult(source, I18n.tx(this.appLocale, 'toast.installPluginFail')));
          continue;
        }
        try {
          await AppService.plugins.installFromUrl(src);
          results.push(this.okResult(src));
        } catch (e) {
          results.push(this.failResult(src, e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.installPluginFail')));
        }
      }
      if (results.length === 0) {
        results.push(this.failResult(source, I18n.tx(this.appLocale, 'toast.subscriptionInvalid')));
      }
      return results;
    } catch (e) {
      const list: InstallPluginResult[] = [];
      list.push(this.failResult(source, e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.installPluginFail')));
      return list;
    }
  }

  async installLocal(): Promise<void> {
    if (this.busy) {
      return;
    }
    try {
      const docPicker = new picker.DocumentViewPicker();
      const uris = await docPicker.select({
        maxSelectNumber: 5,
        fileSuffixFilters: ['插件|.js,.json', '.js', '.json']
      });
      if (uris.length === 0) {
        return;
      }
      this.busy = true;
      const results: InstallPluginResult[] = [];
      for (let i = 0; i < uris.length; i++) {
        const part = await this.installLocalUri(uris[i]);
        for (let j = 0; j < part.length; j++) {
          results.push(part[j]);
        }
      }
      this.reportInstallResults(results, false);
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.installFail'), duration: 2500 });
    }
    this.busy = false;
  }

  private async installLocalUri(uri: string): Promise<InstallPluginResult[]> {
    const code = AppStorageUtil.readTextFromUri(uri);
    if (code.length === 0) {
      const list: InstallPluginResult[] = [];
      list.push(this.failResult(uri, I18n.tx(this.appLocale, 'toast.installFail')));
      return list;
    }
    if (this.looksLikeJsonUrl(uri) || this.codeLooksLikePluginList(code)) {
      return await this.installJsonText(code, uri);
    }
    try {
      await AppService.plugins.installCode(code, uri);
      const list: InstallPluginResult[] = [];
      list.push(this.okResult(uri));
      return list;
    } catch (e) {
      const list: InstallPluginResult[] = [];
      list.push(this.failResult(uri, e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.installPluginFail')));
      return list;
    }
  }

  private reportInstallResults(results: InstallPluginResult[], fromNetwork: boolean): void {
    let ok = 0;
    const fails: InstallPluginResult[] = [];
    for (let i = 0; i < results.length; i++) {
      if (results[i].success) {
        ok += 1;
      } else {
        fails.push(results[i]);
      }
    }
    if (fails.length === 0 && ok > 0) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.installPluginSuccess'), duration: 2000 });
      if (fromNetwork) {
        this.showInstall = false;
        this.pluginUrl = '';
      }
      return;
    }
    if (ok > 0) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.partialPluginInstallFailed'), duration: 2000 });
    } else {
      promptAction.showToast({
        message: fails.length > 1 ? I18n.tx(this.appLocale, 'toast.allPluginInstallFailed') : I18n.tx(this.appLocale, 'toast.installPluginFail'),
        duration: 2500
      });
    }
    if (fails.length > 0) {
      this.installFailDetail = this.buildFailDetail(fails);
      this.showInstallFail = true;
    }
  }

  private buildFailDetail(fails: InstallPluginResult[]): string {
    const parts: string[] = [];
    for (let i = 0; i < fails.length; i++) {
      const reason = I18n.tx(this.appLocale, 'pluginSetting.failReason').replace('{reason}', fails[i].message);
      parts.push(`${fails[i].pluginUrl}\n${reason}`);
    }
    return I18n.tx(this.appLocale, 'pluginSetting.pluginInstallFailedDialogContent').replace('{detail}', parts.join('\n-----\n'));
  }

  async doImportInput(): Promise<void> {
    const text = this.importUrl.trim();
    if (text.length === 0 || this.importing) {
      return;
    }
    this.importing = true;
    try {
      if (this.importMode === 0) {
        const item: MusicItem | null = await AppService.plugins.importMusicItem(this.importHash, text);
        if (item === null) {
          promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.failToImportMusic'), duration: 2500 });
        } else {
          const musics: MusicItem[] = [];
          musics.push(item);
          this.pendingMusics = musics;
          this.newSheetDefaultName = I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importMusicToSheetName').replace('{name}', this.importName);
          const songName = item.title.length > 0 ? item.title : I18n.tx(this.appLocale, 'common.unknownMusic');
          this.importConfirmContent = I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importMusicDialogContent').replace('{name}', songName);
          this.showImportInput = false;
          this.importUrl = '';
          this.showImportConfirm = true;
        }
      } else {
        promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.importing'), duration: 1500 });
        const list = await AppService.plugins.importMusicSheetByHash(this.importHash, text);
        if (list.length === 0) {
          promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.failToImportSheet'), duration: 2500 });
        } else {
          this.pendingMusics = list;
          this.newSheetDefaultName = I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importMusicToSheetName').replace('{name}', this.importName);
          this.importConfirmContent = I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importSheetDialogContent').replace('{count}', `${list.length}`);
          this.showImportInput = false;
          this.importUrl = '';
          this.showImportConfirm = true;
        }
      }
    } catch (_e) {
      promptAction.showToast({
        message: this.importMode === 0 ? I18n.tx(this.appLocale, 'toast.failToImportMusic') : I18n.tx(this.appLocale, 'toast.failToImportSheet'),
        duration: 2500
      });
    }
    this.importing = false;
  }

  private openAddToSheet(): void {
    this.showImportConfirm = false;
    this.sheetOptions = AppService.sheets.sheets.slice();
    this.showAddToSheet = true;
  }

  private addPendingToSheet(sheet: SheetItem): void {
    AppService.sheets.addMusics(sheet.id, this.pendingMusics);
    this.pendingMusics = [];
    this.showAddToSheet = false;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'panel.addToMusicSheet.toast.success'), duration: 1500 });
  }

  private addPendingToNewSheet(): void {
    const title = this.newSheetDefaultName.length > 0 ? this.newSheetDefaultName : I18n.tx(this.appLocale, 'panel.addToMusicSheet.newMusicSheet');
    const created = AppService.sheets.addSheet(title);
    AppService.sheets.addMusics(created.id, this.pendingMusics);
    this.pendingMusics = [];
    this.showAddToSheet = false;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'panel.addToMusicSheet.toast.success'), duration: 1500 });
  }

  private updateUserVar(key: string, value: string): void {
    for (let i = 0; i < this.userVarItems.length; i++) {
      if (this.userVarItems[i].key === key) {
        this.userVarItems[i].value = value;
        break;
      }
    }
  }

  build() {
    Stack() {
      Column() {
        AppNavBar({
          title: I18n.tx(this.appLocale, 'sidebar.pluginManagement'),
          menuTitles: [
            I18n.tx(this.appLocale, 'pluginSetting.menu.subscriptionSetting'),
            I18n.tx(this.appLocale, 'pluginSetting.menu.sort'),
            I18n.tx(this.appLocale, 'pluginSetting.menu.dedupe'),
            I18n.tx(this.appLocale, 'pluginSetting.menu.uninstallAll')
          ],
          onBack: () => {
            AppService.pop();
          },
          onMenuAction: (index: number) => {
            this.handlePluginMenu(index);
          }
        })

        if (this.plugins.length === 0) {
          EmptyView({ text: I18n.tx(this.appLocale, 'common.emptyList') })
        } else {
          List() {
            ForEach(this.plugins, (p: PluginMeta) => {
              ListItem() {
                Column() {
                Row() {
                  Row() {
                    Text(this.pluginName(p))
                      .fontSize(18)
                      .fontColor(this.textColor)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                    if (p.description.length > 0) {
                      Row() {
                        IconImg({ name: 'question-mark-circle', iconSize: 18, color: this.textSecondary })
                      }
                      .width(28)
                      .height(28)
                      .margin({ left: 4 })
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.openDesc(p);
                      })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(VerticalAlign.Center)
                  Toggle({ type: ToggleType.Switch, isOn: p.enabled })
                    .selectedColor(this.primary)
                    .onChange((on: boolean) => {
                      AppService.plugins.setEnabled(p.hash, on);
                    })
                }
                .width('100%')
                .padding({ left: 8, right: 8 })
                .alignItems(VerticalAlign.Center)

                Row() {
                  Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.versionHint').replace('{version}', p.version))
                    .fontSize(14)
                    .fontColor(this.textSecondary)
                  if (p.author.length > 0) {
                    Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.author').replace('{author}', p.author))
                      .fontSize(14)
                      .fontColor(this.textSecondary)
                      .margin({ left: 12 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                }
                .width('100%')
                .padding({ left: 8, right: 8 })
                .margin({ top: 12, bottom: 12 })

                if (p.alternativePlugin.length > 0) {
                  Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.alternativePlugin').replace('{name}', p.alternativePlugin))
                    .fontSize(14)
                    .fontColor(this.textSecondary)
                    .padding({ left: 8, right: 8 })
                    .margin({ bottom: 12 })
                    .width('100%')
                }

                if (p.state !== 'mounted') {
                  Text(p.errorMsg.length > 0 ? p.errorMsg : I18n.tx(this.appLocale, 'pluginPage.parseFail'))
                    .fontSize(14)
                    .fontColor('#FC5F5F')
                    .padding({ left: 8, right: 8 })
                    .margin({ bottom: 12 })
                    .width('100%')
                }

                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
                  if (p.srcUrl.length > 0) {
                    this.pluginActionBtn('arrow-path', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.updatePlugin'), p.hash, 1)
                    this.pluginActionBtn('share', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.sharePlugin'), p.hash, 2)
                  }
                  this.pluginActionBtn('trash-outline', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.uninstallPlugin'), p.hash, 3)
                  this.pluginActionBtn('strategy', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.alternativePlugin'), p.hash, 4)
                  if (this.hasMethod(p, 'importMusicItem')) {
                    this.pluginActionBtn('arrow-right-end-on-rectangle', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importMusic'), p.hash, 5)
                  }
                  if (this.hasMethod(p, 'importMusicSheet')) {
                    this.pluginActionBtn('arrow-right-end-on-rectangle', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importSheet'), p.hash, 6)
                  }
                  if (p.userVariables.length > 0) {
                    this.pluginActionBtn('code-bracket-square', I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.userVariables'), p.hash, 7)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .borderRadius(4)
              .clip(true)
              .backgroundColor(this.card)
              }
              .padding(0)
              .margin({ left: 12, right: 12, top: 18 })
            }, (p: PluginMeta) => p.hash)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .padding({ bottom: 80 + this.gestureBarHeight })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground)

      Column() {
        Button({ type: ButtonType.Circle }) {
          IconImg({ name: 'plus', iconSize: 22, color: this.textColor })
        }
        .width(54)
        .height(54)
        .backgroundColor(this.backdrop)
        .padding(0)
        .stateEffect(false)
        .onClick(() => {
          this.showFabMenu = true;
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.End)
      .padding({ right: 18, bottom: 36 + this.gestureBarHeight })
      .hitTestBehavior(HitTestMode.Transparent)

      if (this.showFabMenu) {
        this.fabMenuOverlay()
      }
      if (this.showUninstall) {
        this.uninstallDialog()
      }
      if (this.showUninstallAll) {
        this.uninstallAllDialog()
      }
      if (this.showDesc) {
        this.descDialog()
      }
      if (this.showAlt) {
        this.altDialog()
      }
      if (this.showImportConfirm) {
        this.importConfirmDialog()
      }
      if (this.showInstallFail) {
        this.installFailDialog()
      }
      if (this.showInstall) {
        this.installOverlay()
      }
      if (this.showImportInput) {
        this.importOverlay()
      }
      if (this.showUserVars) {
        this.userVarsOverlay()
      }
      if (this.showAddToSheet) {
        this.addToSheetOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  pluginActionBtn(icon: string, title: string, hash: string, action: number) {
    Row() {
      IconImg({ name: icon, iconSize: 18, color: this.textColor })
      Text(title)
        .fontSize(14)
        .fontColor(this.textColor)
        .margin({ left: 4 })
        .maxLines(1)
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .margin({ right: 8, bottom: 4 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.runCardAction(hash, action);
    })
  }

  private runCardAction(hash: string, action: number): void {
    const p = AppService.plugins.findByHash(hash);
    if (p === null) {
      return;
    }
    if (action === 1) {
      this.updateOnePlugin(p.srcUrl);
    } else if (action === 2) {
      this.sharePlugin(p.srcUrl);
    } else if (action === 3) {
      this.confirmUninstall(p);
    } else if (action === 4) {
      this.openAlt(p);
    } else if (action === 5) {
      this.openImportMusic(p);
    } else if (action === 6) {
      this.openImportSheet(p);
    } else if (action === 7) {
      this.openUserVars(p);
    }
  }

  private handlePluginMenu(index: number): void {
    if (index === 0) {
      AppService.push(ROUTES.PLUGIN_SUBSCRIBE);
    } else if (index === 1) {
      AppService.push(ROUTES.PLUGIN_SORT);
    } else if (index === 2) {
      this.dedupePlugins();
    } else if (index === 3) {
      this.showUninstallAll = true;
    }
  }

  private async dedupePlugins(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const count = await AppService.plugins.dedupe();
      if (count === 0) {
        promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pluginDedupeNone'), duration: 2000 });
      } else {
        promptAction.showToast({
          message: I18n.tx(this.appLocale, 'toast.pluginDedupeDone').replace('{count}', `${count}`),
          duration: 2500
        });
      }
    } catch (_e) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pluginDedupeFail'), duration: 2500 });
    }
    this.busy = false;
  }

  private handleFabAction(index: number): void {
    this.showFabMenu = false;
    if (index === 0) {
      this.installLocal();
    } else if (index === 1) {
      this.showInstall = true;
    } else if (index === 2) {
      this.updateAll();
    } else if (index === 3) {
      this.updateSubscribe();
    }
  }

  @Builder
  sheetHeader(title: string, close: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .onClick(close)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 8 })
  }

  @Builder
  fabMenuOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showFabMenu = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'pluginSetting.menu.installPlugin'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 8 })
        this.fabActionRow(I18n.tx(this.appLocale, 'pluginSetting.fabOptions.installFromLocal'), 0)
        this.fabActionRow(I18n.tx(this.appLocale, 'pluginSetting.fabOptions.installFromNetwork'), 1)
        this.fabActionRow(I18n.tx(this.appLocale, 'pluginSetting.fabOptions.updateAllPlugins'), 2)
        this.fabActionRow(I18n.tx(this.appLocale, 'pluginSetting.fabOptions.updateSubscription'), 3)
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 + this.gestureBarHeight })
      .borderRadius({ topLeft: 12, topRight: 12 })
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  fabActionRow(title: string, index: number) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor(this.textColor)
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      this.handleFabAction(index);
    })
  }

  @Builder
  uninstallDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showUninstall = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.uninstallPlugin'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.uninstallPluginContent').replace('{name}', this.uninstallName))
          .fontSize(14)
          .fontColor(this.textColor)
          .margin({ top: 12 })
          .width('100%')
        Row() {
          Button(I18n.tx(this.appLocale, 'common.cancel'))
            .layoutWeight(1)
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .onClick(() => {
              this.showUninstall = false;
            })
          Button(I18n.tx(this.appLocale, 'common.confirm'))
            .layoutWeight(1)
            .margin({ left: 12 })
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .onClick(() => {
              this.doUninstall();
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('80%')
      .padding(20)
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  uninstallAllDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showUninstallAll = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'pluginSetting.menu.uninstallAll'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Text(I18n.tx(this.appLocale, 'pluginSetting.menu.uninstallAllContent'))
          .fontSize(14)
          .fontColor(this.textColor)
          .margin({ top: 12 })
          .width('100%')
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(this.textColor)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showUninstallAll = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(this.primary)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.doUninstallAll();
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('80%')
      .padding(20)
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  descDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showDesc = false;
        })
      Column() {
        Text(this.descTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Scroll() {
          Text(this.descText)
            .fontSize(14)
            .fontColor(this.textColor)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 280 })
        .margin({ top: 12 })
        .scrollBar(BarState.Off)
        Button(I18n.tx(this.appLocale, 'common.confirm'))
          .width('100%')
          .margin({ top: 16 })
          .backgroundColor(this.primary)
          .fontColor('#FEFEFE')
          .onClick(() => {
            this.showDesc = false;
          })
      }
      .width('80%')
      .padding(20)
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  altDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showAlt = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.dialog.setAlternativePluginTitle'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.dialog.setAlternativePluginTip'))
          .fontSize(13)
          .fontColor(this.textSecondary)
          .margin({ top: 8 })
          .width('100%')
        Scroll() {
          Column() {
            ForEach(this.altPlatforms, (platform: string, index: number) => {
              Row() {
                Text(platform.length > 0 ? platform : I18n.tx(this.appLocale, 'pluginSetting.none'))
                  .fontSize(15)
                  .fontColor(platform === this.altSelected ? this.primary : this.textColor)
                  .layoutWeight(1)
                if (platform === this.altSelected) {
                  IconImg({ name: 'check', iconSize: 18, color: this.primary })
                }
              }
              .width('100%')
              .height(48)
              .onClick(() => {
                this.applyAlt(platform);
              })
            }, (platform: string, index: number) => `alt-${index}-${platform}`)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 280 })
        .margin({ top: 8 })
        .scrollBar(BarState.Off)
      }
      .width('80%')
      .padding(20)
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  importConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showImportConfirm = false;
          this.pendingMusics = [];
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importDialogTitle'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Text(this.importConfirmContent)
          .fontSize(14)
          .fontColor(this.textColor)
          .margin({ top: 12 })
          .width('100%')
        Row() {
          Button(I18n.tx(this.appLocale, 'common.cancel'))
            .layoutWeight(1)
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .onClick(() => {
              this.showImportConfirm = false;
              this.pendingMusics = [];
            })
          Button(I18n.tx(this.appLocale, 'common.confirm'))
            .layoutWeight(1)
            .margin({ left: 12 })
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .onClick(() => {
              this.openAddToSheet();
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('80%')
      .padding(20)
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  installFailDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showInstallFail = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'pluginSetting.menu.pluginInstallFailedDialogTitle'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Scroll() {
          Text(this.installFailDetail)
            .fontSize(13)
            .fontColor(this.textColor)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 280 })
        .margin({ top: 12 })
        .scrollBar(BarState.Off)
        Button(I18n.tx(this.appLocale, 'common.confirm'))
          .width('100%')
          .margin({ top: 16 })
          .backgroundColor(this.primary)
          .fontColor('#FEFEFE')
          .onClick(() => {
            this.showInstallFail = false;
          })
      }
      .width('80%')
      .padding(20)
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  installOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          if (!this.installing) {
            this.showInstall = false;
          }
        })
      this.installBuilder()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  importOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          if (!this.importing) {
            this.showImportInput = false;
          }
        })
      this.importInputBuilder()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  userVarsOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showUserVars = false;
        })
      this.userVarsBuilder()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  addToSheetOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showAddToSheet = false;
          this.pendingMusics = [];
        })
      this.addToSheetBuilder()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  installBuilder() {
    Column() {
      this.sheetHeader(I18n.tx(this.appLocale, 'pluginSetting.menu.installPlugin'), () => {
        if (!this.installing) {
          this.showInstall = false;
        }
      })
      TextInput({ placeholder: I18n.tx(this.appLocale, 'pluginSetting.menu.installPluginDialogPlaceholder'), text: this.pluginUrl })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .maxLength(1000)
        .onChange((v: string) => {
          this.pluginUrl = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(this.installing ? I18n.tx(this.appLocale, 'common.installing') : I18n.tx(this.appLocale, 'common.install'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .enabled(!this.installing)
        .onClick(() => {
          this.install();
        })
    }
    .width('100%')
    .padding({ bottom: 24 + this.gestureBarHeight })
    .borderRadius({ topLeft: 16, topRight: 16 })
    .backgroundColor(this.backdrop)
    .onClick(() => {
    })
  }

  @Builder
  importInputBuilder() {
    Column() {
      this.sheetHeader(
        this.importMode === 0 ? I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importMusic') : I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importSheet'),
        () => {
          this.showImportInput = false;
        }
      )
      if (this.importHint.length > 0) {
        Text(this.importHint)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ left: 16, right: 16, top: 8 })
      }
      TextInput({
        placeholder: this.importMode === 0 ? I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importMusicPlaceHolder') : I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.importSheetPlaceHolder'),
        text: this.importUrl
      })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .maxLength(1000)
        .onChange((v: string) => {
          this.importUrl = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(this.importing ? I18n.tx(this.appLocale, 'toast.importing') : I18n.tx(this.appLocale, 'common.import'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .enabled(!this.importing)
        .onClick(() => {
          this.doImportInput();
        })
    }
    .width('100%')
    .padding({ bottom: 24 + this.gestureBarHeight })
    .borderRadius({ topLeft: 16, topRight: 16 })
    .backgroundColor(this.backdrop)
    .onClick(() => {
    })
  }

  @Builder
  userVarsBuilder() {
    Column() {
      this.sheetHeader(I18n.tx(this.appLocale, 'pluginSetting.pluginItem.options.userVariables'), () => {
        this.showUserVars = false;
      })
      Scroll() {
        Column() {
          ForEach(this.userVarItems, (row: UserVarRow) => {
            Text(row.name.length > 0 ? row.name : row.key)
              .fontSize(13)
              .fontColor(this.textColor)
              .width('100%')
              .margin({ top: 10 })
            TextInput({ placeholder: row.hint.length > 0 ? row.hint : row.name, text: row.value })
              .fontColor(this.textColor)
              .placeholderColor(this.textSecondary)
              .backgroundColor(this.placeholder)
              .caretColor(this.primary)
              .onChange((v: string) => {
                this.updateUserVar(row.key, v);
              })
              .margin({ top: 6 })
          }, (row: UserVarRow) => `user-var-${row.key}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      Button(I18n.tx(this.appLocale, 'common.save'))
        .width('90%')
        .margin({ top: 8, bottom: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .onClick(() => {
          this.saveUserVars();
        })
    }
    .width('100%')
    .height(460)
    .padding({ bottom: 8 + this.gestureBarHeight })
    .borderRadius({ topLeft: 16, topRight: 16 })
    .backgroundColor(this.backdrop)
    .onClick(() => {
    })
  }

  @Builder
  addToSheetBuilder() {
    Column() {
      this.sheetHeader(I18n.tx(this.appLocale, 'panel.addToMusicSheet.title').replace('{count}', `${this.pendingMusics.length}`), () => {
        this.showAddToSheet = false;
        this.pendingMusics = [];
      })
      List() {
        ListItem() {
          Row() {
            IconImg({ name: 'folder-plus', iconSize: 20, color: this.textColor })
            Text(I18n.tx(this.appLocale, 'panel.addToMusicSheet.newMusicSheet'))
              .fontSize(15)
              .fontColor(this.textColor)
              .margin({ left: 12 })
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
        }
        .onClick(() => {
          this.addPendingToNewSheet();
        })
        ForEach(this.sheetOptions, (sheet: SheetItem) => {
          ListItem() {
            Row() {
              IconImg({ name: 'folder-outline', iconSize: 20, color: this.textColor })
              Column() {
                Text(sheet.title.length > 0 ? sheet.title : I18n.tx(this.appLocale, 'common.unknownName'))
                  .fontSize(15)
                  .fontColor(this.textColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(I18n.tx(this.appLocale, 'panel.addToMusicSheet.count').replace('{count}', `${sheet.worksNum}`))
                  .fontSize(12)
                  .fontColor(this.textSecondary)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
          }
          .onClick(() => {
            this.addPendingToSheet(sheet);
          })
        }, (sheet: SheetItem) => `add-sheet-${sheet.id}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height(460)
    .padding({ bottom: 8 + this.gestureBarHeight })
    .borderRadius({ topLeft: 16, topRight: 16 })
    .backgroundColor(this.backdrop)
    .onClick(() => {
    })
  }

  async updateAll(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.updatingAllPlugins'), duration: 1500 });
    try {
      const msg = await AppService.plugins.updateAll();
      promptAction.showToast({ message: msg, duration: 2500 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.updateFail'), duration: 2500 });
    }
    this.busy = false;
  }

  async updateSubscribe(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const msg = await AppService.plugins.updateFromSubscribe();
      promptAction.showToast({ message: msg, duration: 2500 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.updateSubscribeFail'), duration: 2500 });
    }
    this.busy = false;
  }
}
