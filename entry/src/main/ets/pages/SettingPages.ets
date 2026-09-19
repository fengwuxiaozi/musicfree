import { ROUTES, APP_VERSION, ResumeMode, STORE_KEYS } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { AppStorageUtil } from '../core/AppStorageUtil';
import { I18n } from '../core/I18n';
import { UpdateService } from '../core/UpdateService';
import { WebDavService } from '../core/WebDavService';
import { HttpUtil } from '../core/HttpUtil';
import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { Want } from '@kit.AbilityKit';

@Component
export struct SettingPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  build() {
    Column() {
      AppNavBar({ title: I18n.tx(this.appLocale, 'common.setting'), onBack: () => { AppService.pop(); } })
      this.item('cog-8-tooth', I18n.tx(this.appLocale, 'sidebar.basicSettings'), () => { AppService.push(ROUTES.BASIC); })
      this.item('javascript', I18n.tx(this.appLocale, 'sidebar.pluginManagement'), () => { AppService.push(ROUTES.PLUGIN); })
      this.item('t-shirt-outline', I18n.tx(this.appLocale, 'sidebar.themeSettings'), () => { AppService.push(ROUTES.THEME); })
      this.item('circle-stack', I18n.tx(this.appLocale, 'sidebar.backupAndResume'), () => { AppService.push(ROUTES.BACKUP); })
      this.item('information-circle', I18n.tx(this.appLocale, 'common.about'), () => { AppService.push(ROUTES.ABOUT); })
      this.item('shield-keyhole-outline', I18n.tx(this.appLocale, 'sidebar.permissionManagement'), () => { AppService.push(ROUTES.PERMISSIONS); })
    }
    .id(`setting-${this.appLocale}`)
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  item(icon: string, title: string, action: () => void) {
    Row() {
      IconImg({ name: icon, iconSize: 20, color: this.textColor })
      Text(title).fontSize(15).fontColor(this.textColor).margin({ left: 12 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(action)
  }
}

@Component
export struct ThemePage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('bgUrl') bgUrl: string = '';
  @StorageLink('themeFollowSystem') themeFollowSystem: boolean = false;
  @StorageLink('themeSelected') themeSelected: string = 'p-dark';
  @StorageLink('themeDark') themeDark: boolean = true;
  @StorageLink('themeRev') themeRev: number = 0;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State viewRev: number = 0;
  @State selectedKey: string = 'dark';

  aboutToAppear(): void {
    if (this.themeSelected === 'custom') {
      this.selectedKey = 'custom';
    } else if (this.themeDark) {
      this.selectedKey = 'dark';
    } else {
      this.selectedKey = 'light';
    }
  }

  private readStore(key: string, fallback: string): string {
    const raw = AppStorage.get<string>(key);
    if (raw === undefined || raw === null) {
      return fallback;
    }
    const text = `${raw}`.trim();
    if (text.length === 0) {
      return fallback;
    }
    return text;
  }

  private afterThemeChange(): void {
    this.pageBackground = this.readStore(STORE_KEYS.pageBackground, this.pageBackground);
    this.textColor = this.readStore(STORE_KEYS.textColor, this.textColor);
    this.textSecondary = this.readStore(STORE_KEYS.textSecondary, this.textSecondary);
    this.primary = this.readStore(STORE_KEYS.primary, this.primary);
    this.placeholder = this.readStore(STORE_KEYS.placeholder, this.placeholder);
    this.viewRev = this.viewRev + 1;
  }

  private chooseTheme(key: string): void {
    this.selectedKey = key;
    this.themeFollowSystem = false;
    if (key === 'light') {
      AppService.theme.setDark(false);
    } else if (key === 'dark') {
      AppService.theme.setDark(true);
    } else {
      AppService.theme.selectCustom();
    }
    this.afterThemeChange();
    if (key === 'custom') {
      AppService.push(ROUTES.SET_CUSTOM_THEME);
    }
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.tx(this.appLocale, 'sidebar.themeSettings'), stamp: this.viewRev, onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          Text(I18n.tx(this.appLocale, 'themeSettings.displayStyle'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 18 })
          Row() {
            Text(I18n.tx(this.appLocale, 'themeSettings.followSystemTheme')).fontSize(15).fontColor(this.textColor)
            Blank()
            Stack() {
              Row()
                .width(20)
                .height(20)
                .borderRadius(10)
                .backgroundColor('#FFFFFF')
            }
            .width(46)
            .height(24)
            .borderRadius(12)
            .clip(true)
            .padding({ left: 2, right: 2 })
            .alignContent(this.themeFollowSystem ? Alignment.End : Alignment.Start)
            .backgroundColor(this.themeFollowSystem ? this.primary : this.placeholder)
            .onClick(() => {
              const next = !this.themeFollowSystem;
              this.themeFollowSystem = next;
              AppService.theme.setFollowSystem(next);
              if (next) {
                this.selectedKey = AppService.theme.isDark ? 'dark' : 'light';
              }
              this.afterThemeChange();
            })
          }
          .width('100%')
          .padding(16)

          Text(I18n.tx(this.appLocale, 'themeSettings.setTheme'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 8 })
          Row() {
            this.themeCard('#FFFFFF', I18n.tx(this.appLocale, 'themeSettings.lightMode'), 'light', false)
            this.themeCard('#131313', I18n.tx(this.appLocale, 'themeSettings.darkMode'), 'dark', false)
            this.themeCard(this.placeholder, I18n.tx(this.appLocale, 'themeSettings.customMode'), 'custom', true)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 24 })
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .id(`theme-${this.appLocale}`)
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  themeCard(previewColor: string, title: string, key: string, isCustom: boolean) {
    Column() {
      Column() {
        if (isCustom) {
          if (this.bgUrl.length > 0) {
            Image(this.bgUrl)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
              .syncLoad(true)
          } else {
            IconImg({ name: 'plus', iconSize: 28, color: this.textSecondary })
          }
        }
      }
      .width(64)
      .height(64)
      .borderRadius(8)
      .backgroundColor(previewColor)
      .justifyContent(FlexAlign.Center)
      .clip(true)

      Text(title)
        .fontSize(12)
        .fontColor(this.selectedKey === key ? this.primary : this.textColor)
        .margin({ top: 6 })
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width(76)
    .padding(4)
    .margin({ right: 12 })
    .border({
      width: 2,
      color: this.selectedKey === key ? this.primary : '#00000000',
      radius: 12
    })
    .onClick(() => {
      this.chooseTheme(key);
    })
  }
}

@Component
export struct AboutPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('divider') divider: string = '#1AFFFFFF';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;

  private async openSource(): Promise<void> {
    const ctx = AppService.context;
    if (ctx === null) {
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: 'https://github.com/maotoumao/MusicFree'
    };
    try {
      await ctx.startAbility(want);
    } catch (_e) {
    }
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.tx(this.appLocale, 'about.title'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          Image($r('app.media.app_icon'))
            .width(88)
            .height(88)
            .borderRadius(18)
            .margin({ top: 28 })
            .onClick(() => {
              UpdateService.showResult(true);
            })
          Text('MusicFree')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ top: 12 })
          Text(`${I18n.tx(this.appLocale, 'about.harmonyVersion')}  ${APP_VERSION}`)
            .fontSize(13)
            .fontColor(this.textSecondary)
            .margin({ top: 4 })
          Text(I18n.tx(this.appLocale, 'sidebar.checkUpdate'))
            .fontSize(14)
            .fontColor(this.primary)
            .margin({ top: 14 })
            .onClick(() => {
              UpdateService.showResult(true);
            })

          Column() {
            this.infoRow(I18n.tx(this.appLocale, 'about.authorLabel'), I18n.tx(this.appLocale, 'about.authorName'))
            Divider().color(this.divider).strokeWidth(1)
            this.infoRow(I18n.tx(this.appLocale, 'about.originalAuthorLabel'), I18n.tx(this.appLocale, 'about.originalAuthorName'))
          }
          .width('100%')
          .backgroundColor(this.backdrop)
          .borderRadius(12)
          .margin({ top: 28 })

          Text(I18n.tx(this.appLocale, 'about.statementTitle'))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textSecondary)
            .width('100%')
            .margin({ top: 20, bottom: 8 })
            .padding({ left: 4 })

          Column() {
            Text(I18n.tx(this.appLocale, 'about.intro'))
              .fontSize(13)
              .fontColor(this.textColor)
              .lineHeight(22)
              .width('100%')
            Text(I18n.tx(this.appLocale, 'about.licenseBody'))
              .fontSize(13)
              .fontColor(this.textColor)
              .lineHeight(22)
              .width('100%')
              .margin({ top: 12 })
            Row() {
              Text(I18n.tx(this.appLocale, 'about.sourceLabel'))
                .fontSize(13)
                .fontColor(this.textSecondary)
              Blank()
              Text(I18n.tx(this.appLocale, 'about.sourceUrl'))
                .fontSize(13)
                .fontColor(this.primary)
                .maxLines(1)
            }
            .width('100%')
            .margin({ top: 14 })
            .onClick(() => {
              this.openSource();
            })
            Divider().color(this.divider).strokeWidth(1).margin({ top: 16, bottom: 12 })
            Text(I18n.tx(this.appLocale, 'about.pluginHint'))
              .fontSize(12)
              .fontColor(this.textSecondary)
              .lineHeight(20)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.backdrop)
          .borderRadius(12)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 + this.gestureBarHeight })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .id(`about-${this.appLocale}`)
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.textSecondary)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(this.textColor)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@Component
export struct BackupPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;
  @State resumeMode: string = ResumeMode.APPEND;
  @State davUrl: string = '';
  @State davUser: string = '';
  @State davPass: string = '';
  @State busy: boolean = false;
  @State resumeUrl: string = '';
  @State showResumeMode: boolean = false;
  @State showUrlResume: boolean = false;
  @State showDav: boolean = false;

  aboutToAppear(): void {
    this.resumeMode = AppService.resumeMode;
    this.davUrl = AppService.webdavUrl;
    this.davUser = AppService.webdavUsername;
    this.davPass = AppService.webdavPassword;
  }

  private modeLabel(): string {
    if (this.resumeMode === ResumeMode.OVERWRITE) {
      return I18n.tx(this.appLocale, 'backupAndResume.resumeMode.overwrite');
    }
    if (this.resumeMode === ResumeMode.OVERWRITE_DEFAULT) {
      return I18n.tx(this.appLocale, 'backupAndResume.resumeMode.overwrite-default');
    }
    return I18n.tx(this.appLocale, 'backupAndResume.resumeMode.append');
  }

  private pickResumeMode(mode: string): void {
    this.resumeMode = mode;
    AppService.saveResumeMode(mode);
    this.showResumeMode = false;
  }

  async backupLocal(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const raw = AppService.buildBackupJson();
      const sandbox = `${AppStorageUtil.filesRoot()}/backup.json`;
      AppStorageUtil.writeText(sandbox, raw);
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = ['backup.json'];
      const documentViewPicker = new picker.DocumentViewPicker();
      const uris = await documentViewPicker.save(documentSaveOptions);
      if (uris.length > 0) {
        AppStorageUtil.writeTextToUri(uris[0], raw);
        promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backupSuccess'), duration: 2000 });
      } else {
        promptAction.showToast({ message: I18n.tx(this.appLocale, 'backup.savedToSandbox'), duration: 2500 });
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.backupFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  async resumeLocal(): Promise<void> {
    if (this.busy) {
      return;
    }
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker();
      const uris = await docPicker.select(documentSelectOptions);
      if (uris.length === 0) {
        return;
      }
      const raw = AppStorageUtil.readTextFromUri(uris[0]);
      if (raw.trim().length === 0) {
        promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backupFileNotFound'), duration: 2000 });
        return;
      }
      this.busy = true;
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'backupAndResume.resuming'), duration: 1500 });
      const msg = await AppService.restoreBackup(raw);
      promptAction.showToast({ message: msg, duration: 3000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.resumeFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  async resumeFromUrl(): Promise<void> {
    if (this.busy) {
      return;
    }
    const url = this.resumeUrl.trim();
    if (!url.endsWith('.json') && !url.endsWith('.txt')) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.resumeUrlInvalid'), duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      const raw = await HttpUtil.getText(url, undefined, 60000);
      if (raw.trim().length === 0) {
        promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backupFileNotFound'), duration: 2000 });
        this.busy = false;
        return;
      }
      const msg = await AppService.restoreBackup(raw);
      this.showUrlResume = false;
      promptAction.showToast({ message: msg, duration: 3000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.tx(this.appLocale, 'toast.resumeFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  async saveDav(): Promise<void> {
    await AppService.saveWebdav(this.davUrl.trim(), this.davUser.trim(), this.davPass);
    this.showDav = false;
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.saveSuccess'), duration: 1500 });
  }

  private davClient(): WebDavService {
    return new WebDavService(this.davUrl.trim(), this.davUser.trim(), this.davPass);
  }

  private davReady(): boolean {
    return this.davUrl.trim().length > 0 && this.davUser.trim().length > 0 && this.davPass.length > 0;
  }

  async backupWebdav(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!this.davReady()) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.resumePreCheckFailed'), duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      await AppService.saveWebdav(this.davUrl.trim(), this.davUser.trim(), this.davPass);
      await this.davClient().putBackup(AppService.buildBackupJson());
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backupSuccess'), duration: 2000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.tx(this.appLocale, 'backup.webdavBackupFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  async resumeWebdav(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!this.davReady()) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.resumePreCheckFailed'), duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      await AppService.saveWebdav(this.davUrl.trim(), this.davUser.trim(), this.davPass);
      const raw = await this.davClient().getBackup();
      const msg = await AppService.restoreBackup(raw);
      promptAction.showToast({ message: msg, duration: 3000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.tx(this.appLocale, 'backup.webdavResumeFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        AppNavBar({ title: I18n.tx(this.appLocale, 'sidebar.backupAndResume'), onBack: () => { AppService.pop(); } })
        Scroll() {
          Column() {
            this.sectionTitle(I18n.tx(this.appLocale, 'sidebar.backupAndResume'))
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.resumeMode'), this.modeLabel(), () => {
              this.showResumeMode = true;
            })
            this.sectionTitle(I18n.tx(this.appLocale, 'backupAndResume.localBackup'))
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.backupToLocal'), '', () => {
              this.backupLocal();
            })
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.resumeFromLocalFile'), '', () => {
              this.resumeLocal();
            })
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.resumeFromUrlDialogTitle'), '', () => {
              this.resumeUrl = '';
              this.showUrlResume = true;
            })
            this.sectionTitle(I18n.tx(this.appLocale, 'backupAndResume.webdavSettings'))
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.webdavSettings'), '', () => {
              this.showDav = true;
            })
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.backupToWebdav'), '', () => {
              this.backupWebdav();
            })
            this.actionRow(I18n.tx(this.appLocale, 'backupAndResume.resumeFromWebdav'), '', () => {
              this.resumeWebdav();
            })
          }
          .width('100%')
          .padding({ bottom: 32 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground)

      if (this.showResumeMode) {
        this.resumeModeOverlay()
      }
      if (this.showUrlResume) {
        this.urlResumeOverlay()
      }
      if (this.showDav) {
        this.davOverlay()
      }
    }
    .id(`backup-${this.appLocale}`)
    .width('100%')
    .height('100%')
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.textSecondary)
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 4 })
  }

  @Builder
  resumeModeOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showResumeMode = false;
        })
      Column() {
        Row() {
          Text(I18n.tx(this.appLocale, 'backupAndResume.setResumeMode'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .layoutWeight(1)
          Row() {
            IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showResumeMode = false;
          })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 8 })
        this.resumeModeRow(I18n.tx(this.appLocale, 'backupAndResume.resumeMode.append'), ResumeMode.APPEND)
        this.resumeModeRow(I18n.tx(this.appLocale, 'backupAndResume.resumeMode.overwrite-default'), ResumeMode.OVERWRITE_DEFAULT)
        this.resumeModeRow(I18n.tx(this.appLocale, 'backupAndResume.resumeMode.overwrite'), ResumeMode.OVERWRITE)
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
  resumeModeRow(label: string, mode: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.textColor)
        .layoutWeight(1)
      if (this.resumeMode === mode) {
        IconImg({ name: 'check', iconSize: 20, color: this.primary })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.pickResumeMode(mode);
    })
  }

  @Builder
  urlResumeOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showUrlResume = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'backupAndResume.resumeFromUrlDialogTitle'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ top: 16, bottom: 8 })
        TextInput({ placeholder: I18n.tx(this.appLocale, 'backupAndResume.resumeFromUrlDialogPlaceHolder'), text: this.resumeUrl })
          .width('92%')
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .onChange((v: string) => {
            this.resumeUrl = v;
          })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 16 })
            .onClick(() => {
              this.showUrlResume = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 16 })
            .onClick(() => {
              this.resumeFromUrl();
            })
        }
        .width('100%')
        .margin({ top: 8 })
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

  @Builder
  davOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showDav = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'backupAndResume.webdavSettings'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ top: 16, bottom: 8 })
        TextInput({ placeholder: I18n.tx(this.appLocale, 'backupAndResume.webdavUrl'), text: this.davUrl })
          .width('92%')
          .margin({ top: 8 })
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .onChange((v: string) => {
            this.davUrl = v;
          })
        TextInput({ placeholder: I18n.tx(this.appLocale, 'common.username'), text: this.davUser })
          .width('92%')
          .margin({ top: 8 })
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .onChange((v: string) => {
            this.davUser = v;
          })
        TextInput({ placeholder: I18n.tx(this.appLocale, 'common.password'), text: this.davPass })
          .width('92%')
          .margin({ top: 8 })
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .type(InputType.Password)
          .onChange((v: string) => {
            this.davPass = v;
          })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 16 })
            .onClick(() => {
              this.showDav = false;
            })
          Text(I18n.tx(this.appLocale, 'common.save'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 16 })
            .onClick(() => {
              this.saveDav();
            })
        }
        .width('100%')
        .margin({ top: 8 })
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

  @Builder
  actionRow(title: string, value: string, action: () => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.textColor).layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .maxLines(2)
          .textAlign(TextAlign.End)
          .constraintSize({ maxWidth: '48%' })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(action)
  }
}
