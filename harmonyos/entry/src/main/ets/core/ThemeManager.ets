import { ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { STORE_KEYS } from '../common/Constants';
import { AppService } from './AppService';
import { AppStorageUtil } from './AppStorageUtil';
import { I18n } from './I18n';

export class ThemeManager {
  isDark: boolean = true;
  followSystem: boolean = false;
  selectedTheme: string = 'p-dark';
  bgUrl: string = '';
  bgBlur: number = 20;
  bgOpacity: number = 0.6;

  isSystemDark(): boolean {
    const ctx = AppService.context;
    if (ctx === null) {
      return true;
    }
    return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  apply(dark: boolean): void {
    this.isDark = dark;
    AppStorage.setOrCreate(STORE_KEYS.themeDark, dark);
    if (this.selectedTheme !== 'custom') {
      this.selectedTheme = dark ? 'p-dark' : 'p-light';
      AppStorage.setOrCreate('themeSelected', this.selectedTheme);
    }
    if (dark) {
      AppStorage.setOrCreate(STORE_KEYS.primary, '#3FA3B5');
      AppStorage.setOrCreate(STORE_KEYS.pageBackground, '#202020');
      AppStorage.setOrCreate(STORE_KEYS.textColor, '#FCFCFC');
      AppStorage.setOrCreate(STORE_KEYS.textSecondary, '#B3FCFCFC');
      AppStorage.setOrCreate(STORE_KEYS.appBar, '#262626');
      AppStorage.setOrCreate(STORE_KEYS.appBarText, '#FCFCFC');
      AppStorage.setOrCreate(STORE_KEYS.musicBar, '#262626');
      AppStorage.setOrCreate(STORE_KEYS.musicBarText, '#FCFCFC');
      AppStorage.setOrCreate(STORE_KEYS.card, '#88333333');
      AppStorage.setOrCreate(STORE_KEYS.placeholder, '#424242');
      AppStorage.setOrCreate(STORE_KEYS.divider, '#1AFFFFFF');
      AppStorage.setOrCreate(STORE_KEYS.mask, '#CC212121');
      AppStorage.setOrCreate(STORE_KEYS.backdrop, '#303030');
      AppStorage.setOrCreate(STORE_KEYS.tabBar, '#303030');
      AppStorage.setOrCreate(STORE_KEYS.danger, '#FC5F5F');
    } else {
      AppStorage.setOrCreate(STORE_KEYS.primary, '#F17D34');
      AppStorage.setOrCreate(STORE_KEYS.pageBackground, '#FAFAFA');
      AppStorage.setOrCreate(STORE_KEYS.textColor, '#333333');
      AppStorage.setOrCreate(STORE_KEYS.textSecondary, '#B3333333');
      AppStorage.setOrCreate(STORE_KEYS.appBar, '#F17D34');
      AppStorage.setOrCreate(STORE_KEYS.appBarText, '#FEFEFE');
      AppStorage.setOrCreate(STORE_KEYS.musicBar, '#F2F2F2');
      AppStorage.setOrCreate(STORE_KEYS.musicBarText, '#333333');
      AppStorage.setOrCreate(STORE_KEYS.card, '#88E2E2E2');
      AppStorage.setOrCreate(STORE_KEYS.placeholder, '#EAEAEA');
      AppStorage.setOrCreate(STORE_KEYS.divider, '#1A000000');
      AppStorage.setOrCreate(STORE_KEYS.mask, '#33515151');
      AppStorage.setOrCreate(STORE_KEYS.backdrop, '#F0F0F0');
      AppStorage.setOrCreate(STORE_KEYS.tabBar, '#F0F0F0');
      AppStorage.setOrCreate(STORE_KEYS.danger, '#FC5F5F');
    }
    this.updateStatusBar(dark);
  }

  setAppBarStatusIcons(onAppBar: boolean): void {
    const win = AppService.mainWindow;
    if (win === null) {
      return;
    }
    try {
      const sysBar: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        statusBarContentColor: onAppBar || this.isDark ? '#FCFCFC' : '#333333'
      };
      win.setWindowSystemBarProperties(sysBar);
    } catch (_e) {
    }
  }

  private updateStatusBar(dark: boolean): void {
    const win = AppService.mainWindow;
    if (win === null) {
      return;
    }
    try {
      const sysBar: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        statusBarContentColor: dark ? '#FCFCFC' : '#333333'
      };
      win.setWindowSystemBarProperties(sysBar);
    } catch (_e) {
    }
  }

  async load(): Promise<void> {
    const mode = await AppStorageUtil.getString('theme.selectedTheme', 'p-dark');
    this.followSystem = await AppStorageUtil.getBool('theme.followSystem', false);
    this.selectedTheme = mode.length > 0 ? mode : 'p-dark';
    AppStorage.setOrCreate('themeFollowSystem', this.followSystem);
    AppStorage.setOrCreate('themeSelected', this.selectedTheme);
    if (this.followSystem) {
      this.apply(this.isSystemDark());
    } else {
      this.apply(mode !== 'p-light');
    }
    this.bgUrl = await AppStorageUtil.getString('theme.background', '');
    const blurRaw = await AppStorageUtil.getString('theme.backgroundBlur', '20');
    const opacityRaw = await AppStorageUtil.getString('theme.backgroundOpacity', '0.6');
    const blurNum = Number(blurRaw);
    const opacityNum = Number(opacityRaw);
    this.bgBlur = Number.isNaN(blurNum) ? 20 : blurNum;
    this.bgOpacity = Number.isNaN(opacityNum) ? 0.6 : opacityNum;
    this.syncBg();
  }

  async setFollowSystem(on: boolean): Promise<void> {
    this.followSystem = on;
    await AppStorageUtil.setBool('theme.followSystem', on);
    AppStorage.setOrCreate('themeFollowSystem', on);
    if (on) {
      this.apply(this.isSystemDark());
      await AppStorageUtil.setString('theme.selectedTheme', this.selectedTheme);
    }
  }

  async setDark(dark: boolean): Promise<void> {
    this.selectedTheme = dark ? 'p-dark' : 'p-light';
    await AppStorageUtil.setString('theme.selectedTheme', this.selectedTheme);
    AppStorage.setOrCreate('themeSelected', this.selectedTheme);
    this.apply(dark);
    this.syncBg();
  }

  async selectCustom(): Promise<void> {
    this.selectedTheme = 'custom';
    await AppStorageUtil.setString('theme.selectedTheme', 'custom');
    AppStorage.setOrCreate('themeSelected', 'custom');
  }

  syncBg(): void {
    AppStorage.setOrCreate(STORE_KEYS.bgUrl, this.bgUrl);
    AppStorage.setOrCreate(STORE_KEYS.bgBlur, this.bgBlur);
    AppStorage.setOrCreate(STORE_KEYS.bgOpacity, this.bgOpacity);
  }

  previewBlur(blur: number): void {
    this.bgBlur = blur;
    AppStorage.setOrCreate(STORE_KEYS.bgBlur, blur);
  }

  previewOpacity(opacity: number): void {
    this.bgOpacity = opacity;
    AppStorage.setOrCreate(STORE_KEYS.bgOpacity, opacity);
  }

  async setBackgroundUrl(url: string): Promise<void> {
    this.bgUrl = url;
    await AppStorageUtil.setString('theme.background', url);
    this.syncBg();
  }

  async setBackgroundBlur(blur: number): Promise<void> {
    this.previewBlur(blur);
    await AppStorageUtil.setString('theme.backgroundBlur', `${blur}`);
  }

  async setBackgroundOpacity(opacity: number): Promise<void> {
    this.previewOpacity(opacity);
    await AppStorageUtil.setString('theme.backgroundOpacity', `${opacity}`);
  }

  async setBackgroundFromUri(srcUri: string): Promise<void> {
    const dir = AppStorageUtil.themeBgDir();
    const name = `background_${Date.now()}.jpg`;
    const dest = `${dir}/${name}`;
    AppStorageUtil.copyUri(srcUri, dest);
    let url = `file://${dest}`;
    try {
      url = fileUri.getUriFromPath(dest);
    } catch (_e) {
    }
    await this.setBackgroundUrl(url);
    const olds = AppStorageUtil.listFiles(dir);
    for (let i = 0; i < olds.length; i++) {
      if (olds[i] !== name) {
        AppStorageUtil.removeFile(`${dir}/${olds[i]}`);
      }
    }
  }

  async clearBackground(): Promise<void> {
    const dir = AppStorageUtil.themeBgDir();
    const olds = AppStorageUtil.listFiles(dir);
    for (let i = 0; i < olds.length; i++) {
      AppStorageUtil.removeFile(`${dir}/${olds[i]}`);
    }
    await this.setBackgroundUrl('');
  }
}

export function initAppStorageDefaults(): void {
  AppStorage.setOrCreate(STORE_KEYS.currentTitle, '');
  AppStorage.setOrCreate(STORE_KEYS.currentArtist, '');
  AppStorage.setOrCreate(STORE_KEYS.currentArtwork, '');
  AppStorage.setOrCreate(STORE_KEYS.currentAlbum, '');
  AppStorage.setOrCreate(STORE_KEYS.isPlaying, false);
  AppStorage.setOrCreate(STORE_KEYS.position, 0);
  AppStorage.setOrCreate(STORE_KEYS.duration, 0);
  AppStorage.setOrCreate(STORE_KEYS.lyricLine, I18n.t('lyric.noLyric'));
  AppStorage.setOrCreate(STORE_KEYS.hasMusic, false);
  AppStorage.setOrCreate(STORE_KEYS.toastMsg, '');
  AppStorage.setOrCreate(STORE_KEYS.themeDark, true);
  AppStorage.setOrCreate(STORE_KEYS.primary, '#3FA3B5');
  AppStorage.setOrCreate(STORE_KEYS.pageBackground, '#202020');
  AppStorage.setOrCreate(STORE_KEYS.textColor, '#FCFCFC');
  AppStorage.setOrCreate(STORE_KEYS.textSecondary, '#B3FCFCFC');
  AppStorage.setOrCreate(STORE_KEYS.appBar, '#262626');
  AppStorage.setOrCreate(STORE_KEYS.appBarText, '#FCFCFC');
  AppStorage.setOrCreate(STORE_KEYS.musicBar, '#262626');
  AppStorage.setOrCreate(STORE_KEYS.musicBarText, '#FCFCFC');
  AppStorage.setOrCreate(STORE_KEYS.card, '#88333333');
  AppStorage.setOrCreate(STORE_KEYS.placeholder, '#424242');
  AppStorage.setOrCreate(STORE_KEYS.divider, '#1AFFFFFF');
  AppStorage.setOrCreate(STORE_KEYS.mask, '#CC212121');
  AppStorage.setOrCreate(STORE_KEYS.backdrop, '#303030');
  AppStorage.setOrCreate(STORE_KEYS.tabBar, '#303030');
  AppStorage.setOrCreate(STORE_KEYS.danger, '#FC5F5F');
  AppStorage.setOrCreate('themeFollowSystem', false);
  AppStorage.setOrCreate('themeSelected', 'p-dark');
  AppStorage.setOrCreate(STORE_KEYS.bgUrl, '');
  AppStorage.setOrCreate(STORE_KEYS.bgBlur, 20);
  AppStorage.setOrCreate(STORE_KEYS.bgOpacity, 0.6);
  AppStorage.setOrCreate('floatingLyricOn', false);
  AppStorage.setOrCreate('floatingLyricText', I18n.t('lyric.noLyric'));
  AppStorage.setOrCreate('floatingLyricInApp', true);
  AppStorage.setOrCreate('scheduleRemain', '');
  AppStorage.setOrCreate('statusBarHeight', 44);
  AppStorage.setOrCreate('gestureBarHeight', 16);
}
