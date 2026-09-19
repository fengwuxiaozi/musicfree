import { SheetItem } from '../common/Types';
import { ROUTES, FAVORITE_SHEET_ID, APP_VERSION, APP_NAME, LOCAL_PLATFORM } from '../common/Constants';
import { IconImg } from '../components/IconImg';
import { MusicBar } from '../components/MusicBar';
import { ScheduleClosePanel } from '../components/ScheduleClosePanel';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { UpdateService } from '../core/UpdateService';
import { promptAction } from '@kit.ArkUI';

@Component
struct HomeActionCard {
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @Prop icon: string = '';
  @Prop titleKey: string = '';
  onAction: () => void = () => {
  };

  build() {
    Column() {
      IconImg({ name: this.icon, iconSize: 24, color: this.textColor })
      Text(I18n.tx(this.appLocale, this.titleKey))
        .fontSize(13)
        .fontColor(this.textColor)
        .margin({ top: 6 })
        .fontWeight(FontWeight.Medium)
    }
    .layoutWeight(1)
    .height(80)
    .margin({ left: 6, right: 6 })
    .borderRadius(9)
    .backgroundColor(this.card)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onAction();
    })
  }
}

@Component
export struct HomePage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('textHint') textHint: string = '#99FCFCFC';
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
  @State showSchedule: boolean = false;
  @State showDelete: boolean = false;
  @State deleteTarget: SheetItem = new SheetItem();
  @StorageLink('scheduleRemain') scheduleRemain: string = '';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('localeRev') @Watch('onLocaleRev') localeRev: number = 0;
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;

  aboutToAppear(): void {
    this.refresh();
    AppService.sheets.onChange(() => {
      this.refresh();
    });
  }

  onLocaleRev(): void {
    this.tick += 1;
  }

  private refresh(): void {
    this.sheets = AppService.sheets.sheets.slice();
    this.starred = AppService.sheets.starred.slice();
    this.tick += 1;
  }

  private currentSheets(): SheetItem[] {
    return this.tab === 0 ? this.sheets : this.starred;
  }

  private runDrawerAction(action: () => void): void {
    this.showDrawer = false;
    setTimeout((): void => {
      action();
    }, 80);
  }

  private openCreateSheet(): void {
    this.newSheetName = '';
    this.showCreate = true;
  }

  private confirmCreateSheet(): void {
    const fallback = I18n.tx(this.appLocale, 'panel.createMusicSheet.title');
    const name = this.newSheetName.trim().length > 0 ? this.newSheetName.trim() : fallback;
    AppService.sheets.addSheet(name);
    this.showCreate = false;
    this.newSheetName = '';
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
            IconImg({ name: 'bars-3', iconSize: 21, color: this.textColor })
          }
          .width(40)
          .height(44)
          .margin({ left: 12 })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showDrawer = true;
          })

          Row() {
            IconImg({ name: 'magnifying-glass', iconSize: 16, color: this.textHint })
            Text(I18n.tx(this.appLocale, 'home.clickToSearch'))
              .fontSize(13)
              .fontColor(this.textHint)
              .margin({ left: 6 })
          }
          .layoutWeight(1)
          .height(32)
          .margin({ left: 12, right: 12 })
          .padding({ left: 10, right: 10 })
          .borderRadius(18)
          .backgroundColor(this.placeholder)
          .onClick(() => {
            AppService.push(ROUTES.SEARCH);
          })
        }
        .width('100%')
        .height(44 + this.statusBarHeight)
        .padding({ top: this.statusBarHeight })
        .alignItems(VerticalAlign.Center)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            this.operations()
            this.sheetHeader()
            if (this.currentSheets().length === 0) {
              EmptyView({ text: this.tab === 0 ? I18n.tx(this.appLocale, 'home.emptyMySheets') : I18n.tx(this.appLocale, 'home.emptyStarredSheets') })
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
        .zIndex(8)
      }
      if (this.showLanguage) {
        this.languageOverlay()
      }
      if (this.showDelete) {
        this.deleteOverlay()
      }
      if (this.showCreate) {
        this.createOverlay()
      }
      if (this.showSchedule) {
        this.scheduleOverlay()
      }
    }
    .id(`home-${this.appLocale}-${this.localeRev}`)
  }

  @Builder
  operations() {
    Row() {
      HomeActionCard({
        icon: 'fire',
        titleKey: 'home.recommendSheet',
        onAction: () => {
          AppService.push(ROUTES.RECOMMEND);
        }
      })
      HomeActionCard({
        icon: 'trophy',
        titleKey: 'home.topList',
        onAction: () => {
          AppService.push(ROUTES.TOP_LIST);
        }
      })
      HomeActionCard({
        icon: 'clock-outline',
        titleKey: 'home.playHistory',
        onAction: () => {
          AppService.push(ROUTES.HISTORY);
        }
      })
      HomeActionCard({
        icon: 'folder-music-outline',
        titleKey: 'home.localMusic',
        onAction: () => {
          AppService.push(ROUTES.LOCAL);
        }
      })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 16, bottom: 8 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  sheetHeader() {
    Row() {
      Row() {
        Text(I18n.tx(this.appLocale, 'home.myPlaylists'))
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
        Text(I18n.tx(this.appLocale, 'home.starredPlaylists'))
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
      Row() {
        IconImg({ name: 'plus', iconSize: 21, color: this.textColor })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.openCreateSheet();
      })
      Row() {
        IconImg({ name: 'inbox-arrow-down', iconSize: 21, color: this.textColor })
      }
      .width(36)
      .height(36)
      .margin({ left: 8 })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        AppService.push(ROUTES.IMPORT_SHEET);
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
          Text(sheet.platform === '本地' ? I18n.tx(this.appLocale, 'home.songCount').replace('{count}', `${sheet.worksNum}`) : sheet.artist)
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
          AppService.params.sheetKind = sheet.kind.length > 0 ? sheet.kind : 'sheet';
          AppService.params.sheet = sheet;
          AppService.push(ROUTES.PLUGIN_SHEET);
        }
      })

      if (sheet.id !== FAVORITE_SHEET_ID) {
        Row() {
          IconImg({ name: 'trash-outline', iconSize: 21, color: this.textColor })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.deleteTarget = sheet;
          this.showDelete = true;
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
    this.tick += 1;
  }

  @Builder
  drawer() {
    Scroll() {
      Column() {
        Text(APP_NAME)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 8 })
          .margin({ top: 6 })

        Column() {
          Text(I18n.tx(this.appLocale, 'common.setting'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 12, top: 8, bottom: 4 })
          this.drawerItem('cog-8-tooth', I18n.tx(this.appLocale, 'sidebar.basicSettings'), () => {
            AppService.push(ROUTES.BASIC);
          })
          this.drawerItem('javascript', I18n.tx(this.appLocale, 'sidebar.pluginManagement'), () => {
            AppService.push(ROUTES.PLUGIN);
          })
          this.drawerItem('t-shirt-outline', I18n.tx(this.appLocale, 'sidebar.themeSettings'), () => {
            AppService.push(ROUTES.THEME);
          })
        }
        .width('100%')
        .margin({ bottom: 12 })

        Column() {
          Text(I18n.tx(this.appLocale, 'common.other'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 12, top: 8, bottom: 4 })
          this.drawerScheduleItem()
          this.drawerItem('circle-stack', I18n.tx(this.appLocale, 'sidebar.backupAndResume'), () => {
            AppService.push(ROUTES.BACKUP);
          })
          this.drawerItem('shield-keyhole-outline', I18n.tx(this.appLocale, 'sidebar.permissionManagement'), () => {
            AppService.push(ROUTES.PERMISSIONS);
          })
          this.drawerItem('language', I18n.tx(this.appLocale, 'sidebar.languageSettings'), () => {
            this.pickLanguage();
          }, I18n.localeLabel(this.appLocale))
        }
        .width('100%')
        .margin({ bottom: 12 })

        Column() {
          Text(I18n.tx(this.appLocale, 'common.software'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 12, top: 8, bottom: 4 })
          this.drawerItem('arrow-path', I18n.tx(this.appLocale, 'sidebar.checkUpdate'), () => {
            UpdateService.showResult(true);
          }, `${I18n.tx(this.appLocale, 'sidebar.currentVersion')}${APP_VERSION}`)
          this.drawerItem('information-circle', `${I18n.tx(this.appLocale, 'common.about')} ${APP_NAME}`, () => {
            AppService.push(ROUTES.ABOUT);
          })
        }
        .width('100%')

        Column()
          .width('100%')
          .height(1)
          .margin({ top: 16, bottom: 8, left: 12, right: 12 })
          .backgroundColor(this.divider)

        this.drawerItem('home-outline', I18n.tx(this.appLocale, 'sidebar.backToDesktop'), () => {
          AppService.goBackground();
        })
        this.drawerItem('power-outline', I18n.tx(this.appLocale, 'sidebar.exitApp'), () => {
          AppService.exitApp();
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
  drawerItem(icon: string, title: string, action: () => void, rightText: string = '') {
    Row() {
      IconImg({ name: icon, iconSize: 21, color: this.textColor })
      Text(title)
        .fontSize(15)
        .fontColor(this.textColor)
        .margin({ left: 12 })
        .layoutWeight(1)
      if (rightText.length > 0) {
        Text(rightText)
          .fontSize(13)
          .fontColor(this.textColor)
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.runDrawerAction(action);
    })
  }

  @Builder
  drawerScheduleItem() {
    Row() {
      IconImg({ name: 'alarm-outline', iconSize: 21, color: this.textColor })
      Text(I18n.tx(this.appLocale, 'sidebar.scheduleClose'))
        .fontSize(15)
        .fontColor(this.textColor)
        .margin({ left: 12 })
        .layoutWeight(1)
      if (this.scheduleRemain.length > 0) {
        Text(this.scheduleRemain)
          .fontSize(13)
          .fontColor(this.textColor)
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.runDrawerAction(() => {
        this.showSchedule = true;
      });
    })
  }

  @Builder
  panelActionHeader(title: string, onCancel: () => void, onConfirm: () => void, hideButtons: boolean) {
    Row() {
      if (hideButtons) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .textAlign(TextAlign.Center)
          .maxLines(1)
      } else {
        Text(I18n.tx(this.appLocale, 'common.cancel'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width(60)
          .onClick(onCancel)
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
        Text(I18n.tx(this.appLocale, 'common.confirm'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primary)
          .width(60)
          .textAlign(TextAlign.End)
          .onClick(onConfirm)
      }
    }
    .width('100%')
    .height(50)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 1 }, color: this.divider })
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
        Text(I18n.tx(this.appLocale, 'sidebar.languageSettings'))
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
    .zIndex(20)
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

  private confirmDeleteSheet(): void {
    const sheet = this.deleteTarget;
    this.showDelete = false;
    const local = sheet.platform === LOCAL_PLATFORM || sheet.platform.length === 0;
    if (local) {
      AppService.sheets.removeSheet(sheet.id);
    } else {
      AppService.sheets.unstarSheet(sheet);
    }
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.deleteSuccess'), duration: 1500 });
  }

  @Builder
  deleteOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showDelete = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'dialog.deleteSheetTitle'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        Text(I18n.tx(this.appLocale, 'dialog.deleteSheetContent').replace('{name}', this.deleteTarget.title))
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
              this.showDelete = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.confirmDeleteSheet();
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
    .zIndex(20)
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
        this.panelActionHeader(I18n.tx(this.appLocale, 'panel.createMusicSheet.title'), () => {
          this.showCreate = false;
        }, () => {
          this.confirmCreateSheet();
        }, false)
        TextInput({ placeholder: I18n.tx(this.appLocale, 'panel.createMusicSheet.title'), text: this.newSheetName })
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .backgroundColor(this.placeholder)
          .caretColor(this.primary)
          .maxLength(200)
          .defaultFocus(true)
          .onChange((v: string) => {
            this.newSheetName = v;
          })
          .margin({ left: 12, right: 12, top: 12, bottom: 16 })
      }
      .width('100%')
      .padding({ bottom: 12 + this.gestureBarHeight })
      .backgroundColor(this.backdrop)
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
    .width('100%')
    .height('100%')
    .zIndex(20)
  }

  @Builder
  scheduleOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showSchedule = false;
        })
      Column() {
        ScheduleClosePanel({
          onDismiss: () => {
            this.showSchedule = false;
          }
        })
      }
      .width('100%')
      .padding({ bottom: this.gestureBarHeight })
      .backgroundColor(this.backdrop)
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
    .width('100%')
    .height('100%')
    .zIndex(20)
  }
}
