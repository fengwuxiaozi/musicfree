import { ROUTES, APP_VERSION, ResumeMode, QUALITIES } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { AppConfig, KEYS } from '../core/AppConfig';
import { AppStorageUtil } from '../core/AppStorageUtil';
import { FloatingLyric } from '../core/FloatingLyric';
import { I18n } from '../core/I18n';
import { UpdateService } from '../core/UpdateService';
import { WebDavService } from '../core/WebDavService';
import { MediaCache } from '../core/MediaCache';
import { HttpUtil } from '../core/HttpUtil';
import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SettingPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  build() {
    Column() {
      AppNavBar({ title: I18n.t('common.setting'), onBack: () => { AppService.pop(); } })
      this.item('cog-8-tooth', I18n.t('sidebar.basicSettings'), () => { AppService.push(ROUTES.BASIC); })
      this.item('javascript', I18n.t('sidebar.pluginManagement'), () => { AppService.push(ROUTES.PLUGIN); })
      this.item('t-shirt-outline', I18n.t('sidebar.themeSettings'), () => { AppService.push(ROUTES.THEME); })
      this.item('circle-stack', I18n.t('sidebar.backupAndResume'), () => { AppService.push(ROUTES.BACKUP); })
      this.item('information-circle', I18n.t('common.about'), () => { AppService.push(ROUTES.ABOUT); })
      this.item('shield-keyhole-outline', I18n.t('sidebar.permissionManagement'), () => { AppService.push(ROUTES.PERMISSIONS); })
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
export struct BasicSettingPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State autoPlay: boolean = false;
  @State tryChangeSource: boolean = true;
  @State playQuality: string = 'standard';
  @State downloadQuality: string = 'standard';
  @State clickSearch: string = 'playMusic';
  @State autoUpdatePlugin: boolean = false;
  @State autoSearchLyric: boolean = false;
  @State desktopLyric: boolean = false;
  @State maxHistoryLen: number = 300;
  @State autoStopError: boolean = false;
  @State maxDownload: number = 3;
  @State clickAlbum: string = 'playAlbum';
  @State detailDefault: string = 'album';

  aboutToAppear(): void {
    this.reload();
  }

  async reload(): Promise<void> {
    await AppConfig.load();
    this.autoPlay = AppConfig.getBool(KEYS.AUTO_PLAY, false);
    this.tryChangeSource = AppConfig.getBool(KEYS.TRY_CHANGE_SOURCE, true);
    this.playQuality = AppConfig.getString(KEYS.PLAY_QUALITY, 'standard');
    this.downloadQuality = AppConfig.getString(KEYS.DOWNLOAD_QUALITY, 'standard');
    this.clickSearch = AppConfig.getString(KEYS.CLICK_SEARCH, 'playMusic');
    this.autoUpdatePlugin = AppConfig.getBool(KEYS.AUTO_UPDATE_PLUGIN, false);
    this.autoSearchLyric = AppConfig.getBool(KEYS.AUTO_SEARCH_LYRIC, false);
    this.maxHistoryLen = AppConfig.getNumber(KEYS.MAX_HISTORY, 300);
    this.desktopLyric = FloatingLyric.isEnabled();
    this.autoStopError = AppConfig.getBool(KEYS.AUTO_STOP_ERROR, false);
    this.maxDownload = AppConfig.getNumber(KEYS.MAX_DOWNLOAD, 3);
    this.clickAlbum = AppConfig.getString(KEYS.CLICK_ALBUM, 'playAlbum');
    this.detailDefault = AppConfig.getString(KEYS.DETAIL_DEFAULT, 'album');
    AppService.player.quality = this.playQuality;
    AppService.history.maxLength = this.maxHistoryLen;
  }

  private nextIn(list: string[], current: string): string {
    const idx = list.indexOf(current);
    return list[(idx + 1) % list.length];
  }

  private nextHistory(): number {
    const list: number[] = [50, 100, 200, 300, 500];
    let idx = -1;
    for (let i = 0; i < list.length; i++) {
      if (list[i] === this.maxHistoryLen) {
        idx = i;
        break;
      }
    }
    return list[(idx + 1) % list.length];
  }

  private clickSearchLabel(): string {
    return this.clickSearch === 'playMusicAndReplace' ?
      I18n.t('basicSettings.clickMusicInSearch.playMusicAndReplace') :
      I18n.t('basicSettings.clickMusicInSearch.playMusic');
  }

  private clickAlbumLabel(): string {
    return this.clickAlbum === 'playMusic' ?
      I18n.t('basicSettings.clickMusicInAlbum.playMusic') :
      I18n.t('basicSettings.clickMusicInAlbum.playAlbum');
  }

  private detailDefaultLabel(): string {
    return this.detailDefault === 'lyric' ?
      I18n.t('basicSettings.musicDetailDefault.lyric') :
      I18n.t('basicSettings.musicDetailDefault.album');
  }

  private qualityLabel(q: string): string {
    if (q === 'low') {
      return I18n.t('musicQuality.low');
    }
    if (q === 'high') {
      return I18n.t('musicQuality.high');
    }
    if (q === 'super') {
      return I18n.t('musicQuality.super');
    }
    return I18n.t('musicQuality.standard');
  }

  private nextDownload(): number {
    const list: number[] = [1, 3, 5];
    let idx = -1;
    for (let i = 0; i < list.length; i++) {
      if (list[i] === this.maxDownload) {
        idx = i;
        break;
      }
    }
    return list[(idx + 1) % list.length];
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.t('sidebar.basicSettings'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          this.valueRow(I18n.t('basicSettings.language'), I18n.localeLabel(I18n.locale()), () => {
            const locales: string[] = ['zh-CN', 'zh-TW', 'en-US'];
            const next: string = this.nextIn(locales, I18n.locale());
            I18n.setLocale(next);
          })
          this.sectionTitle(I18n.t('basicSettings.playback'))
          this.switchRow(I18n.t('basicSettings.autoPlayWhenAppStart'), I18n.t('basicSettings.autoPlayWhenAppStartHint'), this.autoPlay, (on: boolean) => {
            this.autoPlay = on;
            AppConfig.setBool(KEYS.AUTO_PLAY, on);
          })
          this.switchRow(I18n.t('basicSettings.tryChangeSourceWhenPlayFail'), '', this.tryChangeSource, (on: boolean) => {
            this.tryChangeSource = on;
            AppConfig.setBool(KEYS.TRY_CHANGE_SOURCE, on);
          })
          this.switchRow(I18n.t('basicSettings.autoStopWhenError'), '', this.autoStopError, (on: boolean) => {
            this.autoStopError = on;
            AppConfig.setBool(KEYS.AUTO_STOP_ERROR, on);
          })
          this.valueRow(I18n.t('basicSettings.defaultPlayQuality'), this.qualityLabel(this.playQuality), () => {
            const next = this.nextIn(QUALITIES, this.playQuality);
            this.playQuality = next;
            AppConfig.setString(KEYS.PLAY_QUALITY, next);
            AppService.player.quality = next;
            promptAction.showToast({ message: I18n.t('basicSettings.qualityToast').replace('{quality}', this.qualityLabel(next)), duration: 1500 });
          })
          this.valueRow(I18n.t('basicSettings.clickMusicInSearch'), this.clickSearchLabel(), () => {
            const next = this.clickSearch === 'playMusic' ? 'playMusicAndReplace' : 'playMusic';
            this.clickSearch = next;
            AppConfig.setString(KEYS.CLICK_SEARCH, next);
          })
          this.valueRow(I18n.t('basicSettings.clickMusicInAlbum'), this.clickAlbumLabel(), () => {
            const next = this.clickAlbum === 'playMusic' ? 'playAlbum' : 'playMusic';
            this.clickAlbum = next;
            AppConfig.setString(KEYS.CLICK_ALBUM, next);
          })
          this.valueRow(I18n.t('basicSettings.musicDetailDefault'), this.detailDefaultLabel(), () => {
            const next = this.detailDefault === 'album' ? 'lyric' : 'album';
            this.detailDefault = next;
            AppConfig.setString(KEYS.DETAIL_DEFAULT, next);
          })

          this.sectionTitle(I18n.t('basicSettings.download'))
          this.valueRow(I18n.t('basicSettings.defaultDownloadQuality'), this.qualityLabel(this.downloadQuality), () => {
            const next = this.nextIn(QUALITIES, this.downloadQuality);
            this.downloadQuality = next;
            AppConfig.setString(KEYS.DOWNLOAD_QUALITY, next);
          })
          this.valueRow(I18n.t('basicSettings.maxDownload'), `${this.maxDownload}`, () => {
            const next = this.nextDownload();
            this.maxDownload = next;
            AppConfig.setNumber(KEYS.MAX_DOWNLOAD, next);
          })

          this.sectionTitle(I18n.t('basicSettings.plugin'))
          this.switchRow(I18n.t('basicSettings.autoUpdatePlugin'), '', this.autoUpdatePlugin, (on: boolean) => {
            this.autoUpdatePlugin = on;
            AppConfig.setBool(KEYS.AUTO_UPDATE_PLUGIN, on);
          })

          this.sectionTitle(I18n.t('basicSettings.lyric'))
          this.switchRow(I18n.t('basicSettings.lyric.autoSearchLyric'), I18n.t('basicSettings.lyric.autoSearchLyricHint'), this.autoSearchLyric, (on: boolean) => {
            this.autoSearchLyric = on;
            AppConfig.setBool(KEYS.AUTO_SEARCH_LYRIC, on);
          })
          this.switchRow(
            I18n.t('basicSettings.lyric.showStatusBarLyric'),
            I18n.t('basicSettings.lyric.showStatusBarLyricHint'),
            this.desktopLyric,
            (on: boolean) => {
              this.desktopLyric = on;
              FloatingLyric.setEnabled(on);
              AppConfig.setBool(KEYS.SHOW_STATUS_BAR_LYRIC, on);
            }
          )

          this.sectionTitle(I18n.t('basicSettings.cache'))
          this.valueRow(I18n.t('basicSettings.cache.clearMediaCache'), I18n.t('basicSettings.cache.clearMediaCacheHint'), () => {
            MediaCache.clear();
            promptAction.showToast({ message: I18n.t('toast.mediaCacheCleared'), duration: 1500 });
          })

          this.sectionTitle(I18n.t('basicSettings.common'))
          this.valueRow(I18n.t('basicSettings.maxHistoryLength'), `${this.maxHistoryLen}`, () => {
            const next = this.nextHistory();
            this.maxHistoryLen = next;
            AppConfig.setNumber(KEYS.MAX_HISTORY, next);
            AppService.history.maxLength = next;
          })
        }
        .width('100%')
        .padding({ bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .id(`basic-${this.appLocale}`)
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.textSecondary)
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 4 })
  }

  @Builder
  switchRow(title: string, desc: string, isOn: boolean, onChange: (on: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor(this.textColor)
        if (desc.length > 0) {
          Text(desc).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.primary)
        .onChange(onChange)
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  valueRow(title: string, value: string, action: () => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.textColor)
      Blank()
      Text(value).fontSize(13).fontColor(this.textSecondary)
    }
    .width('100%')
    .padding(16)
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
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  build() {
    Column() {
      AppNavBar({ title: I18n.t('sidebar.themeSettings'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          Text(I18n.t('themeSettings.displayStyle'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 18 })
          Row() {
            Text(I18n.t('themeSettings.followSystemTheme')).fontSize(15).fontColor(this.textColor)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.themeFollowSystem })
              .selectedColor(this.primary)
              .onChange((on: boolean) => {
                AppService.theme.setFollowSystem(on);
              })
          }
          .width('100%')
          .padding(16)

          Text(I18n.t('themeSettings.setTheme'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .width('100%')
            .padding({ left: 16, top: 8 })
          Row() {
            this.themeCard('#FFFFFF', I18n.t('themeSettings.lightMode'), !this.themeDark && this.themeSelected !== 'custom', false, () => {
              AppService.theme.setFollowSystem(false);
              AppService.theme.setDark(false);
            })
            this.themeCard('#131313', I18n.t('themeSettings.darkMode'), this.themeDark && this.themeSelected !== 'custom', false, () => {
              AppService.theme.setFollowSystem(false);
              AppService.theme.setDark(true);
            })
            this.themeCard(this.placeholder, I18n.t('themeSettings.customMode'), this.themeSelected === 'custom', true, () => {
              AppService.theme.setFollowSystem(false);
              AppService.theme.selectCustom();
              AppService.push(ROUTES.SET_CUSTOM_THEME);
            })
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
  themeCard(previewColor: string, title: string, selected: boolean, isCustom: boolean, onPress: () => void) {
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
        .fontColor(selected ? this.primary : this.textColor)
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
      color: selected ? this.primary : '#00000000',
      radius: 12
    })
    .onClick(onPress)
  }
}

@Component
export struct AboutPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  build() {
    Column() {
      AppNavBar({ title: I18n.t('about.title'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          Image($r('app.media.app_icon'))
            .width(88)
            .height(88)
            .borderRadius(18)
            .margin({ top: 24 })
            .onClick(() => {
              UpdateService.showResult(true);
            })
          Text('MusicFree').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor).margin({ top: 12 })
          Text(`${I18n.t('about.harmonyVersion')}  ${APP_VERSION}`).fontSize(13).fontColor(this.textSecondary).margin({ top: 4 })
          Row() {
            IconImg({ name: 'arrow-path', iconSize: 18, color: this.textColor })
            Text(I18n.t('sidebar.checkUpdate')).fontSize(15).fontColor(this.textColor).margin({ left: 8 })
          }
          .margin({ top: 16 })
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .borderRadius(8)
          .onClick(() => {
            UpdateService.showResult(true);
          })
          Text(I18n.t('about.author')).fontSize(14).fontColor(this.textColor).margin({ top: 24 })
          Text(I18n.t('about.officialAccount')).fontSize(14).fontColor(this.textColor).margin({ top: 8 })
          Text(I18n.t('about.intro'))
            .fontSize(13)
            .fontColor(this.textSecondary)
            .margin({ top: 20, left: 24, right: 24 })
          Text(I18n.t('about.license'))
            .fontSize(13)
            .fontColor(this.textSecondary)
            .margin({ top: 12, left: 24, right: 24 })
          Text(I18n.t('about.website'))
            .fontSize(13)
            .fontColor(this.primary)
            .margin({ top: 16 })
          Text(I18n.t('about.agplHint'))
            .fontSize(12)
            .fontColor(this.textSecondary)
            .margin({ top: 16, bottom: 32 })
        }
        .width('100%')
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
}

@Component
export struct BackupPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State resumeMode: string = ResumeMode.APPEND;
  @State davUrl: string = '';
  @State davUser: string = '';
  @State davPass: string = '';
  @State busy: boolean = false;
  @State resumeUrl: string = '';
  @State showResumeMode: boolean = false;

  aboutToAppear(): void {
    this.resumeMode = AppService.resumeMode;
    this.davUrl = AppService.webdavUrl;
    this.davUser = AppService.webdavUsername;
    this.davPass = AppService.webdavPassword;
  }

  private modeLabel(): string {
    return this.resumeMode === ResumeMode.OVERWRITE ? I18n.t('backupAndResume.resumeMode.overwrite') : I18n.t('backupAndResume.resumeMode.append');
  }

  private pickResumeMode(mode: string): void {
    this.resumeMode = mode;
    AppService.saveResumeMode(mode);
    this.showResumeMode = false;
  }

  private backupLocal(): void {
    try {
      const path = `${AppStorageUtil.filesRoot()}/musicfree-backup.json`;
      AppStorageUtil.writeText(path, AppService.buildBackupJson());
      promptAction.showToast({ message: I18n.t('backup.savedToSandbox'), duration: 2500 });
    } catch (_e) {
      promptAction.showToast({ message: I18n.t('toast.backupFail'), duration: 2000 });
    }
  }

  async resumeLocal(): Promise<void> {
    if (this.busy) {
      return;
    }
    try {
      const docPicker = new picker.DocumentViewPicker();
      const uris = await docPicker.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['.json', '.txt']
      });
      if (uris.length === 0) {
        return;
      }
      const raw = AppStorageUtil.readText(uris[0]);
      if (raw.length === 0) {
        promptAction.showToast({ message: I18n.t('toast.backupFileNotFound'), duration: 2000 });
        return;
      }
      this.busy = true;
      AppService.restoreBackup(raw);
      promptAction.showToast({ message: I18n.t('toast.resumeSuccess'), duration: 2000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.t('toast.resumeFail');
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
      promptAction.showToast({ message: I18n.t('toast.resumeUrlInvalid'), duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      const raw = await HttpUtil.getText(url);
      if (raw.length === 0) {
        promptAction.showToast({ message: I18n.t('toast.backupFileNotFound'), duration: 2000 });
        this.busy = false;
        return;
      }
      AppService.restoreBackup(raw);
      promptAction.showToast({ message: I18n.t('toast.resumeSuccess'), duration: 2000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.t('toast.resumeFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  async saveDav(): Promise<void> {
    await AppService.saveWebdav(this.davUrl.trim(), this.davUser.trim(), this.davPass);
    promptAction.showToast({ message: I18n.t('toast.saveSuccess'), duration: 1500 });
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
      promptAction.showToast({ message: I18n.t('backup.webdavNeedConfig'), duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      await AppService.saveWebdav(this.davUrl.trim(), this.davUser.trim(), this.davPass);
      await this.davClient().putBackup(AppService.buildBackupJson());
      promptAction.showToast({ message: I18n.t('backup.savedToWebdav'), duration: 2000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.t('backup.webdavBackupFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  async resumeWebdav(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!this.davReady()) {
      promptAction.showToast({ message: I18n.t('backup.webdavNeedConfig'), duration: 2000 });
      return;
    }
    this.busy = true;
    try {
      await AppService.saveWebdav(this.davUrl.trim(), this.davUser.trim(), this.davPass);
      const raw = await this.davClient().getBackup();
      AppService.restoreBackup(raw);
      promptAction.showToast({ message: I18n.t('toast.resumeSuccess'), duration: 2000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : I18n.t('backup.webdavResumeFail');
      promptAction.showToast({ message: msg, duration: 2500 });
    }
    this.busy = false;
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.t('sidebar.backupAndResume'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          Text(I18n.t('backupAndResume.resumeMode'))
            .fontSize(13)
            .fontColor(this.textSecondary)
            .width('100%')
            .padding({ left: 16, top: 12, bottom: 4 })
          Row() {
            Column() {
              Text(I18n.t('backupAndResume.resumeMode')).fontSize(15).fontColor(this.textColor)
              Text(this.modeLabel()).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .onClick(() => {
            this.showResumeMode = true;
          })

          Text(I18n.t('backupAndResume.localBackup'))
            .fontSize(13)
            .fontColor(this.textSecondary)
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 4 })
          this.actionRow(I18n.t('backupAndResume.backupToLocal'), () => {
            this.backupLocal();
          })
          this.actionRow(I18n.t('backupAndResume.resumeFromLocalFile'), () => {
            this.resumeLocal();
          })
          TextInput({ placeholder: I18n.t('backupAndResume.resumeFromUrlDialogPlaceHolder'), text: this.resumeUrl })
            .width('92%')
            .margin({ top: 8 })
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .placeholderColor(this.textSecondary)
            .onChange((v: string) => {
              this.resumeUrl = v;
            })
          Button(I18n.t('backupAndResume.resumeFromUrlDialogTitle'))
            .width('90%')
            .margin({ top: 12, bottom: 8 })
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .enabled(!this.busy)
            .onClick(() => {
              this.resumeFromUrl();
            })

          Text(I18n.t('backupAndResume.webdavSettings'))
            .fontSize(13)
            .fontColor(this.textSecondary)
            .width('100%')
            .padding({ left: 16, top: 12, bottom: 4 })
          TextInput({ placeholder: I18n.t('backupAndResume.webdavUrl'), text: this.davUrl })
            .width('92%')
            .margin({ top: 8 })
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .placeholderColor(this.textSecondary)
            .onChange((v: string) => {
              this.davUrl = v;
            })
          TextInput({ placeholder: I18n.t('common.username'), text: this.davUser })
            .width('92%')
            .margin({ top: 8 })
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .placeholderColor(this.textSecondary)
            .onChange((v: string) => {
              this.davUser = v;
            })
          TextInput({ placeholder: I18n.t('common.password'), text: this.davPass })
            .width('92%')
            .margin({ top: 8 })
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .placeholderColor(this.textSecondary)
            .type(InputType.Password)
            .onChange((v: string) => {
              this.davPass = v;
            })
          Button(I18n.t('backupAndResume.saveWebdav'))
            .width('90%')
            .margin({ top: 16 })
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .enabled(!this.busy)
            .onClick(() => {
              this.saveDav();
            })
          Button(I18n.t('backupAndResume.backupToWebdav'))
            .width('90%')
            .margin({ top: 12 })
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .enabled(!this.busy)
            .onClick(() => {
              this.backupWebdav();
            })
          Button(I18n.t('backupAndResume.resumeFromWebdav'))
            .width('90%')
            .margin({ top: 12, bottom: 32 })
            .backgroundColor(this.primary)
            .fontColor('#FEFEFE')
            .enabled(!this.busy)
            .onClick(() => {
              this.resumeWebdav();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .id(`backup-${this.appLocale}`)
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
    .bindSheet($$this.showResumeMode, this.resumeModeBuilder(), {
      height: 240,
      showClose: false,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE
    })
  }

  @Builder
  resumeModeBuilder() {
    Column() {
      Row() {
        Text(I18n.t('backupAndResume.setResumeMode'))
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
      this.resumeModeRow(I18n.t('backupAndResume.resumeMode.append'), ResumeMode.APPEND)
      this.resumeModeRow(I18n.t('backupAndResume.resumeMode.overwrite'), ResumeMode.OVERWRITE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdrop)
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
  actionRow(title: string, action: () => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.textColor)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(action)
  }
}
