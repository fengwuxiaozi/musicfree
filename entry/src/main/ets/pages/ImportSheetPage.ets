import { MusicItem, PluginMeta, SheetItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { showToast } from '../core/HttpUtil';

@Component
export struct ImportSheetPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;
  @State step: number = 0;
  @State plugins: PluginMeta[] = [];
  @State pluginHash: string = '';
  @State pluginName: string = '';
  @State importUrl: string = '';
  @State importing: boolean = false;
  @State pendingMusics: MusicItem[] = [];
  @State sheets: SheetItem[] = [];
  @State showConfirm: boolean = false;
  @State showCreate: boolean = false;
  @State newSheetName: string = '';
  @State tick: number = 0;

  aboutToAppear(): void {
    this.plugins = AppService.plugins.pluginsWithMethod('importMusicSheet');
    this.refreshSheets();
    AppService.sheets.onChange(() => {
      this.refreshSheets();
    });
  }

  private refreshSheets(): void {
    this.sheets = AppService.sheets.sheets.slice();
    this.tick += 1;
  }

  private pageTitle(): string {
    if (this.step === 2) {
      return I18n.tx(this.appLocale, 'panel.addToMusicSheet.title').replace('{count}', `${this.pendingMusics.length}`);
    }
    return I18n.tx(this.appLocale, 'panel.importMusicSheet.title');
  }

  private goBack(): void {
    if (this.step === 2) {
      this.step = 1;
      return;
    }
    if (this.step === 1) {
      this.step = 0;
      this.importUrl = '';
      return;
    }
    AppService.pop();
  }

  async doImport(): Promise<void> {
    if (this.importUrl.trim().length === 0 || this.importing) {
      return;
    }
    this.importing = true;
    showToast(I18n.tx(this.appLocale, 'panel.importMusicSheet.importing'));
    try {
      const list = await AppService.plugins.importMusicSheetByHash(this.pluginHash, this.importUrl);
      this.importing = false;
      if (list.length === 0) {
        showToast(I18n.tx(this.appLocale, 'panel.importMusicSheet.invalidLink'));
        return;
      }
      this.pendingMusics = list;
      this.showConfirm = true;
    } catch (e) {
      this.importing = false;
      showToast(e instanceof Error ? e.message : I18n.tx(this.appLocale, 'home.importFail'));
    }
  }

  private addToSheet(sheetId: string): void {
    AppService.sheets.addMusics(sheetId, this.pendingMusics);
    this.pendingMusics = [];
    showToast(I18n.tx(this.appLocale, 'panel.addToMusicSheet.toast.success'));
    AppService.pop();
  }

  private confirmCreateSheet(): void {
    const fallback = I18n.tx(this.appLocale, 'panel.createMusicSheet.title');
    const name = this.newSheetName.trim().length > 0 ? this.newSheetName.trim() : fallback;
    const sheet = AppService.sheets.addSheet(name);
    this.showCreate = false;
    this.newSheetName = '';
    this.addToSheet(sheet.id);
  }

  build() {
    Stack() {
      Column() {
        AppNavBar({
          title: this.pageTitle(),
          onBack: () => {
            this.goBack();
          }
        })
        if (this.step === 0) {
          this.pluginList()
        } else if (this.step === 1) {
          this.urlForm()
        } else {
          this.sheetList()
        }
        MusicBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground)

      if (this.showConfirm) {
        this.confirmOverlay()
      }
      if (this.showCreate) {
        this.createOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  pluginList() {
    if (this.plugins.length === 0) {
      EmptyView({
        text: `${I18n.tx(this.appLocale, 'noPlugin.titleWithType').replace('{type}', I18n.tx(this.appLocale, 'panel.importMusicSheet.title'))}\n${I18n.tx(this.appLocale, 'noPlugin.description')}`
      })
    } else {
      List() {
        ForEach(this.plugins, (plugin: PluginMeta) => {
          ListItem() {
            Row() {
              Text(plugin.platform.length > 0 ? plugin.platform : I18n.tx(this.appLocale, 'common.unknownPlugin'))
                .fontSize(15)
                .fontColor(this.textColor)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
          }
          .onClick(() => {
            this.pluginHash = plugin.hash;
            this.pluginName = plugin.platform;
            this.importUrl = '';
            this.step = 1;
          })
        }, (plugin: PluginMeta) => `import-plugin-${plugin.hash}`)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  urlForm() {
    Column() {
      if (this.pluginName.length > 0) {
        Text(this.pluginName)
          .fontSize(13)
          .fontColor(this.textSecondary)
          .width('100%')
          .margin({ left: 16, right: 16, top: 16 })
      }
      TextInput({
        placeholder: I18n.tx(this.appLocale, 'panel.importMusicSheet.placeholder'),
        text: this.importUrl
      })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .maxLength(1000)
        .enabled(!this.importing)
        .onChange((v: string) => {
          this.importUrl = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      if (this.importing) {
        Text(I18n.tx(this.appLocale, 'panel.importMusicSheet.importing'))
          .fontSize(13)
          .fontColor(this.textSecondary)
          .margin({ left: 16, top: 12 })
      }
      Button(I18n.tx(this.appLocale, 'common.confirm'))
        .width('90%')
        .margin({ top: 24 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .enabled(!this.importing)
        .onClick(() => {
          this.doImport();
        })
      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  sheetList() {
    List() {
      ListItem() {
        Row() {
          Image($r('app.media.album_default'))
            .width(48)
            .height(48)
            .borderRadius(6)
          Text(I18n.tx(this.appLocale, 'panel.addToMusicSheet.newMusicSheet'))
            .fontSize(15)
            .fontColor(this.textColor)
            .margin({ left: 12 })
        }
        .width('100%')
        .height(64)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
      }
      .onClick(() => {
        this.newSheetName = '';
        this.showCreate = true;
      })
      ForEach(this.sheets, (sheet: SheetItem) => {
        ListItem() {
          Row() {
            if (sheet.coverImg.length > 0) {
              Image(sheet.coverImg)
                .width(48)
                .height(48)
                .borderRadius(6)
                .objectFit(ImageFit.Cover)
            } else {
              Image($r('app.media.album_default'))
                .width(48)
                .height(48)
                .borderRadius(6)
            }
            Column() {
              Text(sheet.title)
                .fontSize(15)
                .fontColor(this.textColor)
                .maxLines(1)
              Text(I18n.tx(this.appLocale, 'panel.addToMusicSheet.count').replace('{count}', `${sheet.worksNum}`))
                .fontSize(12)
                .fontColor(this.textSecondary)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')
          .height(64)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
        }
        .onClick(() => {
          this.addToSheet(sheet.id);
        })
      }, (sheet: SheetItem) => `import-add-${sheet.id}-${this.tick}`)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  confirmOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showConfirm = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'panel.importMusicSheet.prepareImport'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        Text(I18n.tx(this.appLocale, 'panel.importMusicSheet.foundSongs').replace('{count}', `${this.pendingMusics.length}`))
          .fontSize(14)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 16 })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showConfirm = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showConfirm = false;
              this.step = 2;
            })
        }
        .width('100%')
      }
      .width('80%')
      .borderRadius(12)
      .backgroundColor(this.backdrop)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  createOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showCreate = false;
        })
      Column() {
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .padding({ left: 16, right: 8, top: 14, bottom: 14 })
            .onClick(() => {
              this.showCreate = false;
            })
          Text(I18n.tx(this.appLocale, 'panel.createMusicSheet.title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .padding({ left: 8, right: 16, top: 14, bottom: 14 })
            .onClick(() => {
              this.confirmCreateSheet();
            })
        }
        .width('100%')
        TextInput({ placeholder: I18n.tx(this.appLocale, 'panel.createMusicSheet.title'), text: this.newSheetName })
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .backgroundColor(this.placeholder)
          .caretColor(this.primary)
          .maxLength(200)
          .onChange((v: string) => {
            this.newSheetName = v;
          })
          .margin({ left: 12, right: 12, top: 8, bottom: 16 })
      }
      .width('100%')
      .padding({ bottom: 12 + this.gestureBarHeight })
      .backgroundColor(this.backdrop)
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
    .width('100%')
    .height('100%')
  }
}
