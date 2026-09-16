import { SheetItem } from '../common/Types';
import { ROUTES, FAVORITE_SHEET_ID, APP_VERSION } from '../common/Constants';
import { IconImg } from '../components/IconImg';
import { MusicBar } from '../components/MusicBar';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { ScheduleClose } from '../core/ScheduleClose';
import { UpdateService } from '../core/UpdateService';
import { promptAction } from '@kit.ArkUI';

@Component
export struct HomePage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @StorageLink('divider') divider: string = '#1AFFFFFF';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('danger') danger: string = '#FC5F5F';
  @StorageLink('bgUrl') bgUrl: string = '';
  @StorageLink('bgBlur') bgBlur: number = 20;
  @StorageLink('bgOpacity') bgOpacity: number = 0.6;
  @State showDrawer: boolean = false;
  @State showLanguage: boolean = false;
  @State tab: number = 0;
  @State sheets: SheetItem[] = [];
  @State starred: SheetItem[] = [];
  @State showCreate: boolean = false;
  @State newSheetName: string = '';
  @State tick: number = 0;
  @State showImport: boolean = false;
  @State importUrl: string = '';
  @State importing: boolean = false;
  @State showSchedule: boolean = false;
  @State exitOnClose: boolean = false;
  @StorageLink('scheduleRemain') scheduleRemain: string = '';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;

  aboutToAppear(): void {
    this.refresh();
    AppService.sheets.onChange(() => {
      this.refresh();
    });
  }

  private refresh(): void {
    this.sheets = AppService.sheets.sheets.slice();
    this.starred = AppService.sheets.starred.slice();
    this.tick += 1;
  }

  private currentSheets(): SheetItem[] {
    return this.tab === 0 ? this.sheets : this.starred;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pageBackground)
      if (this.bgUrl.length > 0) {
        Image(this.bgUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.bgOpacity)
          .blur(this.bgBlur)
          .syncLoad(true)
          .hitTestBehavior(HitTestMode.None)
      }
      Column() {
        Row() {
          Row() {
            IconImg({ name: 'bars-3', iconSize: 22, color: this.textColor })
          }
          .width(40)
          .height(40)
          .margin({ left: 8 })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showDrawer = true;
          })

          Row() {
            IconImg({ name: 'magnifying-glass', iconSize: 16, color: this.textSecondary })
            Text(I18n.t('home.clickToSearch'))
              .fontSize(14)
              .fontColor(this.textSecondary)
              .margin({ left: 8 })
          }
          .layoutWeight(1)
          .height(36)
          .margin({ left: 8, right: 16 })
          .padding({ left: 14, right: 14 })
          .borderRadius(18)
          .backgroundColor(this.placeholder)
          .onClick(() => {
            AppService.push(ROUTES.SEARCH);
          })
        }
        .width('100%')
        .height(48 + this.statusBarHeight)
        .padding({ top: this.statusBarHeight })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column() {
            this.operations()
            this.sheetHeader()
            if (this.currentSheets().length === 0) {
              EmptyView({ text: this.tab === 0 ? I18n.t('home.emptyMySheets') : I18n.t('home.emptyStarredSheets') })
            } else {
              ForEach(this.currentSheets(), (sheet: SheetItem) => {
                this.sheetRow(sheet)
              }, (sheet: SheetItem) => `${sheet.platform}-${sheet.id}-${this.tick}`)
            }
          }
          .width('100%')
          .padding({ bottom: 80 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)

        MusicBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgUrl.length > 0 ? '#00000000' : this.pageBackground)

      if (this.showDrawer) {
        Row() {
          this.drawer()
          Column()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor(this.maskColor)
            .onClick(() => {
              this.showDrawer = false;
            })
        }
        .width('100%')
        .height('100%')
      }
      if (this.showLanguage) {
        this.languageOverlay()
      }
    }
    .id(`home-${this.appLocale}`)
    .bindSheet($$this.showCreate, this.createBuilder(), {
      height: 240,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE,
      maskColor: this.maskColor,
      showClose: false
    })
    .bindSheet($$this.showImport, this.importBuilder(), {
      height: 280,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE,
      maskColor: this.maskColor,
      showClose: false
    })
    .bindSheet($$this.showSchedule, this.scheduleBuilder(), {
      height: 400,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE,
      maskColor: this.maskColor,
      showClose: false
    })
  }

  @Builder
  operations() {
    Row() {
      this.actionCard('fire', I18n.t('home.recommendSheet'), () => {
        AppService.push(ROUTES.RECOMMEND);
      })
      this.actionCard('trophy', I18n.t('home.topList'), () => {
        AppService.push(ROUTES.TOP_LIST);
      })
      this.actionCard('clock-outline', I18n.t('home.playHistory'), () => {
        AppService.push(ROUTES.HISTORY);
      })
      this.actionCard('folder-music-outline', I18n.t('home.localMusic'), () => {
        AppService.push(ROUTES.LOCAL);
      })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 16, bottom: 8 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  actionCard(icon: string, title: string, action: () => void) {
    Column() {
      IconImg({ name: icon, iconSize: 24, color: this.textColor })
      Text(title)
        .fontSize(12)
        .fontColor(this.textColor)
        .margin({ top: 8 })
        .fontWeight(FontWeight.Medium)
    }
    .layoutWeight(1)
    .height(80)
    .margin({ left: 6, right: 6 })
    .borderRadius(10)
    .backgroundColor(this.card)
    .justifyContent(FlexAlign.Center)
    .onClick(action)
  }

  @Builder
  sheetHeader() {
    Row() {
      Row() {
        Text(I18n.t('home.mySheets'))
          .fontSize(16)
          .fontWeight(this.tab === 0 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.textColor)
          .padding({ bottom: 4 })
          .border({
            width: { bottom: this.tab === 0 ? 2 : 0 },
            color: this.primary
          })
          .onClick(() => {
            this.tab = 0;
          })
        Text(` (${this.sheets.length})`)
          .fontSize(13)
          .fontColor(this.textSecondary)
        Text(I18n.t('home.starredSheets'))
          .fontSize(16)
          .fontWeight(this.tab === 1 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.textColor)
          .margin({ left: 16 })
          .padding({ bottom: 4 })
          .border({
            width: { bottom: this.tab === 1 ? 2 : 0 },
            color: this.primary
          })
          .onClick(() => {
            this.tab = 1;
          })
        Text(` (${this.starred.length})`)
          .fontSize(13)
          .fontColor(this.textSecondary)
      }
      Blank()
      IconImg({ name: 'plus', iconSize: 20, color: this.textColor })
        .onClick(() => {
          this.newSheetName = '';
          this.showCreate = true;
        })
      IconImg({ name: 'inbox-arrow-down', iconSize: 20, color: this.textColor })
        .margin({ left: 12 })
        .onClick(() => {
          this.importUrl = '';
          this.showImport = true;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  sheetRow(sheet: SheetItem) {
    Row() {
      Row() {
        Stack() {
          if (sheet.coverImg.length > 0) {
            Image(sheet.coverImg)
              .width(56)
              .height(56)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
          } else {
            Image($r('app.media.album_default'))
              .width(56)
              .height(56)
              .borderRadius(6)
          }
          if (sheet.id === FAVORITE_SHEET_ID) {
            Column() {
              IconImg({ name: 'heart', iconSize: 20, color: '#FC5F5F' })
            }
            .width(56)
            .height(56)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#66000000')
            .borderRadius(6)
            .hitTestBehavior(HitTestMode.None)
          }
        }
        .width(56)
        .height(56)
        Column() {
          Text(sheet.title)
            .fontSize(15)
            .fontColor(this.textColor)
            .maxLines(1)
          Text(sheet.platform === '本地' ? I18n.t('home.songCount').replace('{count}', `${sheet.worksNum}`) : sheet.artist)
            .fontSize(12)
            .fontColor(this.textSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (sheet.platform === '本地' || sheet.platform.length === 0) {
          AppService.params.sheetId = sheet.id;
          AppService.params.sheet = sheet;
          AppService.push(ROUTES.SHEET_DETAIL);
        } else {
          AppService.params.sheet = sheet;
          AppService.push(ROUTES.PLUGIN_SHEET);
        }
      })

      if (sheet.id !== FAVORITE_SHEET_ID) {
        IconImg({ name: 'trash-outline', iconSize: 18, color: this.textSecondary })
          .onClick(() => {
            AppService.sheets.removeSheet(sheet.id);
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  private pickLanguage(): void {
    this.showLanguage = true;
  }

  private selectLocale(locale: string): void {
    I18n.setLocale(locale);
    this.showLanguage = false;
  }

  @Builder
  drawer() {
    Scroll() {
      Column() {
        Text('MusicFree')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 12 })
          .margin({ top: 12 })

        Column() {
          Text(I18n.t('common.setting'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 4 })
          this.drawerItem('cog-8-tooth', I18n.t('sidebar.basicSettings'), () => {
            AppService.push(ROUTES.BASIC);
          })
          this.drawerItem('javascript', I18n.t('sidebar.pluginManagement'), () => {
            AppService.push(ROUTES.PLUGIN);
          })
          this.drawerItem('t-shirt-outline', I18n.t('sidebar.themeSettings'), () => {
            AppService.push(ROUTES.THEME);
          })
        }
        .width('100%')
        .margin({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor(this.card)

        Column() {
          Text(I18n.t('common.other'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 4 })
          this.drawerScheduleItem()
          this.drawerItem('circle-stack', I18n.t('sidebar.backupAndResume'), () => {
            AppService.push(ROUTES.BACKUP);
          })
          this.drawerItem('shield-keyhole-outline', I18n.t('sidebar.permissionManagement'), () => {
            AppService.push(ROUTES.PERMISSIONS);
          })
          this.drawerItem('language', I18n.t('sidebar.languageSettings'), () => {
            this.pickLanguage();
          }, I18n.localeLabel(this.appLocale), false)
          this.drawerItem('arrow-down-tray', I18n.t('downloading.title'), () => {
            AppService.push(ROUTES.DOWNLOADING);
          })
        }
        .width('100%')
        .margin({ left: 12, right: 12, top: 12 })
        .borderRadius(12)
        .backgroundColor(this.card)

        Column() {
          Text(I18n.t('common.software'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 4 })
          this.drawerItem('arrow-path', I18n.t('sidebar.checkUpdate'), () => {
            UpdateService.showResult(true);
          }, `${I18n.t('sidebar.currentVersion')}${APP_VERSION}`)
          this.drawerItem('information-circle', I18n.t('about.title'), () => {
            AppService.push(ROUTES.ABOUT);
          })
        }
        .width('100%')
        .margin({ left: 12, right: 12, top: 12 })
        .borderRadius(12)
        .backgroundColor(this.card)

        Column()
          .width('100%')
          .height(1)
          .margin({ top: 16, bottom: 8, left: 20, right: 20 })
          .backgroundColor(this.divider)

        this.drawerItem('home-outline', I18n.t('sidebar.backToDesktop'), () => {
          AppService.context?.moveAbilityToBackground();
        })
        this.drawerItem('power-outline', I18n.t('sidebar.exitApp'), () => {
          AppService.player.reset();
          AppService.context?.terminateSelf();
        })
      }
      .width('100%')
      .padding({ top: this.statusBarHeight, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('80%')
    .height('100%')
    .backgroundColor(this.pageBackground)
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }

  @Builder
  drawerItem(icon: string, title: string, action: () => void, rightText: string = '', closeDrawer: boolean = true) {
    Row() {
      IconImg({ name: icon, iconSize: 20, color: this.textColor })
      Text(title)
        .fontSize(15)
        .fontColor(this.textColor)
        .margin({ left: 14 })
        .layoutWeight(1)
      if (rightText.length > 0) {
        Text(rightText)
          .fontSize(12)
          .fontColor(this.textColor)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      if (closeDrawer) {
        this.showDrawer = false;
      }
      action();
    })
  }

  @Builder
  drawerScheduleItem() {
    Row() {
      IconImg({ name: 'alarm-outline', iconSize: 20, color: this.textColor })
      Text(I18n.t('sidebar.scheduleClose'))
        .fontSize(15)
        .fontColor(this.textColor)
        .margin({ left: 14 })
        .layoutWeight(1)
      if (this.scheduleRemain.length > 0) {
        Text(this.scheduleRemain)
          .fontSize(12)
          .fontColor(this.textColor)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      this.showDrawer = false;
      this.exitOnClose = ScheduleClose.exitApp;
      this.showSchedule = true;
    })
  }

  @Builder
  panelActionHeader(title: string, onCancel: () => void, onConfirm: () => void) {
    Row() {
      Text(I18n.t('common.cancel'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .width(72)
        .onClick(onCancel)
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
      Text(I18n.t('common.confirm'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primary)
        .width(72)
        .textAlign(TextAlign.End)
        .onClick(onConfirm)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  panelTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.textColor)
      .width('100%')
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }

  @Builder
  languageOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showLanguage = false;
        })
      Column() {
        Text(I18n.t('sidebar.languageSettings'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        this.languageRow('zh-CN')
        this.languageRow('zh-TW')
        this.languageRow('en-US')
      }
      .width('80%')
      .borderRadius(12)
      .backgroundColor(this.backdrop)
      .padding({ bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  languageRow(locale: string) {
    Row() {
      Text(I18n.localeLabel(locale))
        .fontSize(15)
        .fontColor(this.textColor)
        .layoutWeight(1)
      if (this.appLocale === locale) {
        IconImg({ name: 'check', iconSize: 20, color: this.primary })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      this.selectLocale(locale);
    })
  }

  @Builder
  createBuilder() {
    Column() {
      this.panelActionHeader(I18n.t('panel.createMusicSheet.title'), () => {
        this.showCreate = false;
      }, () => {
        if (this.newSheetName.trim().length === 0) {
          return;
        }
        AppService.sheets.addSheet(this.newSheetName.trim());
        this.showCreate = false;
      })
      TextInput({ placeholder: I18n.t('home.sheetNamePlaceholder'), text: this.newSheetName })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .onChange((v: string) => {
          this.newSheetName = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(I18n.t('common.create'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .onClick(() => {
          if (this.newSheetName.trim().length === 0) {
            return;
          }
          AppService.sheets.addSheet(this.newSheetName.trim());
          this.showCreate = false;
        })
    }
    .width('100%')
    .backgroundColor(this.backdrop)
  }

  @Builder
  importBuilder() {
    Column() {
      this.panelActionHeader(I18n.t('panel.importMusicSheet.title'), () => {
        this.showImport = false;
      }, () => {
        this.doImport();
      })
      Text(I18n.t('home.importHint'))
        .fontSize(12)
        .fontColor(this.textColor)
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

  @Builder
  scheduleBuilder() {
    Column() {
      this.panelTitle(this.scheduleRemain.length > 0 ?
        `${I18n.t('sidebar.scheduleClose')}  ${this.scheduleRemain}` :
        I18n.t('sidebar.scheduleClose'))
      Text(this.scheduleRemain.length > 0 ? I18n.t('panel.timingClose.remain').replace('{time}', this.scheduleRemain) : I18n.t('panel.timingClose.pickTime'))
        .fontSize(14)
        .fontColor(this.textColor)
        .margin({ top: 8, bottom: 12 })
      Row() {
        this.timeChip(I18n.t('panel.timingClose.min15'), () => {
          ScheduleClose.setMinutes(15);
        })
        this.timeChip(I18n.t('panel.timingClose.min30'), () => {
          ScheduleClose.setMinutes(30);
        })
        this.timeChip(I18n.t('panel.timingClose.min45'), () => {
          ScheduleClose.setMinutes(45);
        })
        this.timeChip(I18n.t('panel.timingClose.min60'), () => {
          ScheduleClose.setMinutes(60);
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.SpaceBetween)

      Button(I18n.t('panel.timingClose.closeAfterPlay'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.placeholder)
        .fontColor(this.textColor)
        .onClick(() => {
          ScheduleClose.setAfterCurrent();
        })

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.exitOnClose })
          .selectedColor(this.primary)
          .onChange((on: boolean) => {
            this.exitOnClose = on;
            ScheduleClose.exitApp = on;
          })
        Text(I18n.t('panel.timingClose.exitApp'))
          .fontSize(14)
          .fontColor(this.textColor)
          .margin({ left: 10 })
      }
      .width('90%')
      .margin({ top: 16 })
      .justifyContent(FlexAlign.Start)

      if (this.scheduleRemain.length > 0) {
        Button(I18n.t('panel.timingClose.cancelScheduleClose'))
          .width('90%')
          .margin({ top: 16 })
          .backgroundColor(this.danger)
          .fontColor('#FEFEFE')
          .onClick(() => {
            ScheduleClose.cancel();
          })
      }
    }
    .width('100%')
    .backgroundColor(this.backdrop)
  }

  @Builder
  timeChip(label: string, action: () => void) {
    Text(label)
      .fontSize(13)
      .fontColor(this.textColor)
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .borderRadius(8)
      .backgroundColor(this.placeholder)
      .onClick(action)
  }
}
