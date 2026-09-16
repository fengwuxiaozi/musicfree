import { PluginMeta } from '../common/Types';
import { ROUTES } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { AppStorageUtil } from '../core/AppStorageUtil';

@Component
export struct PluginPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @State plugins: PluginMeta[] = [];
  @State showInstall: boolean = false;
  @State pluginUrl: string = '';
  @State installing: boolean = false;
  @State showImport: boolean = false;
  @State importUrl: string = '';
  @State importing: boolean = false;
  @State busy: boolean = false;
  @State showUninstall: boolean = false;
  @State uninstallHash: string = '';
  @State uninstallName: string = '';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.refresh();
    AppService.plugins.onChange(() => {
      this.refresh();
    });
  }

  private refresh(): void {
    this.plugins = AppService.plugins.sortedPlugins();
  }

  private confirmUninstall(p: PluginMeta): void {
    this.uninstallHash = p.hash;
    this.uninstallName = p.platform.length > 0 ? p.platform : I18n.t('common.unknownPlugin');
    this.showUninstall = true;
  }

  private doUninstall(): void {
    AppService.plugins.uninstall(this.uninstallHash);
    this.showUninstall = false;
    promptAction.showToast({ message: I18n.t('toast.pluginUninstalled'), duration: 1500 });
  }

  async install(): Promise<void> {
    const url = this.pluginUrl.trim();
    if (url.length === 0) {
      return;
    }
    if (!url.endsWith('.js') && !url.endsWith('.json')) {
      promptAction.showToast({ message: I18n.t('toast.pluginUrlInvalid'), duration: 2000 });
      return;
    }
    this.installing = true;
    try {
      await AppService.plugins.installFromUrl(url);
      promptAction.showToast({ message: I18n.t('toast.installPluginSuccess'), duration: 2000 });
      this.showInstall = false;
      this.pluginUrl = '';
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.t('toast.installPluginFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.installing = false;
  }

  async installLocal(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const uris = await docPicker.select({
        maxSelectNumber: 5,
        fileSuffixFilters: ['.js', '.json']
      });
      if (uris.length === 0) {
        return;
      }
      for (let i = 0; i < uris.length; i++) {
        const uri = uris[i];
        const code = AppStorageUtil.readText(uri);
        if (code.length === 0) {
          continue;
        }
        if (uri.endsWith('.json')) {
          const obj = JSON.parse(code) as Record<string, Object>;
          const list = obj['plugins'] as Object[];
          if (Array.isArray(list)) {
            for (let j = 0; j < list.length; j++) {
              const item = list[j] as Record<string, Object>;
              await AppService.plugins.installFromUrl(`${item['url']}`);
            }
          }
        } else {
          await AppService.plugins.installCode(code, uri);
        }
      }
      promptAction.showToast({ message: I18n.t('toast.installPluginSuccess'), duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.t('toast.installFail'), duration: 2500 });
    }
  }

  build() {
    Stack() {
      Column() {
        AppNavBar({
          title: I18n.t('sidebar.pluginManagement'),
          menuTitles: [
            I18n.t('pluginSetting.menu.subscriptionSetting'),
            I18n.t('pluginSetting.menu.sort'),
            I18n.t('pluginSetting.fabOptions.updateAllPlugins'),
            I18n.t('pluginSetting.fabOptions.updateSubscription'),
            I18n.t('pluginSetting.pluginItem.options.importSheet')
          ],
          onBack: () => {
            AppService.pop();
          },
          onMenuAction: (index: number) => {
            this.handlePluginMenu(index);
          }
        })
        Row() {
          Button(I18n.t('pluginPage.installFromNetwork'))
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .onClick(() => {
              this.showInstall = true;
            })
          Button(I18n.t('pluginPage.installFromLocal'))
            .margin({ left: 12 })
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .onClick(() => {
              this.installLocal();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        Text(I18n.t('pluginPage.hint'))
          .fontSize(12)
          .fontColor(this.textSecondary)
          .padding({ left: 16, right: 16, bottom: 8 })

        if (this.plugins.length === 0) {
          EmptyView({ text: I18n.t('pluginPage.empty') })
        } else {
          List() {
            ForEach(this.plugins, (p: PluginMeta) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(p.platform.length > 0 ? p.platform : I18n.t('common.unknownPlugin'))
                      .fontSize(16)
                      .fontColor(this.textColor)
                    Text(`${I18n.t('pluginSetting.pluginItem.versionHint').replace('{version}', p.version.length > 0 ? p.version : '-')}    ${I18n.t('pluginSetting.pluginItem.author').replace('{author}', p.author.length > 0 ? p.author : '-')}`)
                      .fontSize(12)
                      .fontColor(this.textSecondary)
                      .margin({ top: 4 })
                    if (p.state !== 'mounted') {
                      Text(p.errorMsg.length > 0 ? p.errorMsg : I18n.t('pluginPage.parseFail'))
                        .fontSize(12)
                        .fontColor('#FC5F5F')
                        .margin({ top: 4 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: p.enabled })
                    .selectedColor(this.primary)
                    .onChange((on: boolean) => {
                      AppService.plugins.setEnabled(p.hash, on);
                    })
                  IconImg({ name: 'trash-outline', iconSize: 18, color: this.textSecondary })
                    .margin({ left: 12 })
                    .onClick(() => {
                      this.confirmUninstall(p);
                    })
                }
                .width('100%')
                .padding(16)
              }
            }, (p: PluginMeta) => p.hash)
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground)
      .bindSheet($$this.showInstall, this.installBuilder(), {
        height: 280,
        showClose: false,
        backgroundColor: this.backdrop,
        blurStyle: BlurStyle.NONE,
        maskColor: this.maskColor
      })
      .bindSheet($$this.showImport, this.importBuilder(), {
        height: 300,
        showClose: false,
        backgroundColor: this.backdrop,
        blurStyle: BlurStyle.NONE,
        maskColor: this.maskColor
      })

      if (this.showUninstall) {
        this.uninstallDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  private handlePluginMenu(index: number): void {
    if (index === 0) {
      AppService.push(ROUTES.PLUGIN_SUBSCRIBE);
    } else if (index === 1) {
      AppService.push(ROUTES.PLUGIN_SORT);
    } else if (index === 2) {
      this.updateAll();
    } else if (index === 3) {
      this.updateSubscribe();
    } else if (index === 4) {
      this.importUrl = '';
      this.showImport = true;
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
        Text(I18n.t('pluginSetting.pluginItem.options.uninstallPlugin'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
        Text(I18n.t('pluginSetting.pluginItem.options.uninstallPluginContent').replace('{name}', this.uninstallName))
          .fontSize(14)
          .fontColor(this.textColor)
          .margin({ top: 12 })
          .width('100%')
        Row() {
          Button(I18n.t('common.cancel'))
            .layoutWeight(1)
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .onClick(() => {
              this.showUninstall = false;
            })
          Button(I18n.t('common.confirm'))
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
  installBuilder() {
    Column() {
      this.sheetHeader(I18n.t('pluginPage.installFromNetworkTitle'), () => {
        this.showInstall = false;
      })
      TextInput({ placeholder: I18n.t('pluginPage.installPlaceholder'), text: this.pluginUrl })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .onChange((v: string) => {
          this.pluginUrl = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(this.installing ? I18n.t('common.installing') : I18n.t('common.install'))
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
    .height('100%')
    .backgroundColor(this.backdrop)
  }

  @Builder
  importBuilder() {
    Column() {
      this.sheetHeader(I18n.t('panel.importMusicSheet.title'), () => {
        this.showImport = false;
      })
      Text(I18n.t('home.importHint'))
        .fontSize(12)
        .fontColor(this.textSecondary)
        .margin({ left: 16, right: 16, top: 8 })
      TextInput({ placeholder: I18n.t('panel.importMusicSheet.placeholder'), text: this.importUrl })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .onChange((v: string) => {
          this.importUrl = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(this.importing ? I18n.t('panel.importMusicSheet.importing') : I18n.t('common.import'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .enabled(!this.importing)
        .onClick(() => {
          this.doImport();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdrop)
  }

  async doImport(): Promise<void> {
    if (this.importUrl.trim().length === 0 || this.importing) {
      return;
    }
    this.importing = true;
    try {
      const count = await AppService.importSheetByUrl(this.importUrl);
      if (count === 0) {
        promptAction.showToast({ message: I18n.t('panel.importMusicSheet.invalidLink'), duration: 2500 });
      } else {
        promptAction.showToast({ message: I18n.t('home.importedCount').replace('{count}', `${count}`), duration: 2000 });
        this.showImport = false;
        this.importUrl = '';
      }
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.t('home.importFail'), duration: 2500 });
    }
    this.importing = false;
  }

  async updateAll(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    promptAction.showToast({ message: I18n.t('toast.updatingAllPlugins'), duration: 1500 });
    try {
      const msg = await AppService.plugins.updateAll();
      promptAction.showToast({ message: msg, duration: 2500 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.t('toast.updateFail'), duration: 2500 });
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
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.t('toast.updateSubscribeFail'), duration: 2500 });
    }
    this.busy = false;
  }
}
