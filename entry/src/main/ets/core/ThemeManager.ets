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
    this.applyInner(dark);
  }

  private applyInner(dark: boolean): void {
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
      AppStorage.setOrCreate(STORE_KEYS.textHint, '#99FCFCFC');
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
      AppStorage.setOrCreate(STORE_KEYS.textHint, '#99333333');
      AppStorage.setOrCreate(STORE_KEYS.appBar, '#FFFFFF');
      AppStorage.setOrCreate(STORE_KEYS.appBarText, '#333333');
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
    this.bumpThemeRev();
    this.syncSystemBars(true);
  }

  setAppBarStatusIcons(onAppBar: boolean): void {
    this.syncSystemBars(onAppBar);
  }

  private storageColor(key: string, fallback: string): string {
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

  private toArgb(color: string): string {
    const text = color.trim();
    if (text.length === 7 && text.startsWith('#')) {
      return `#FF${text.substring(1)}`;
    }
    if (text.length === 9 && text.startsWith('#')) {
      if (text.substring(1, 3).toUpperCase() === '00') {
        return `#FF${text.substring(3)}`;
      }
      return text;
    }
    return text;
  }

  private syncSystemBars(onAppBar: boolean): void {
    const win = AppService.mainWindow;
    if (win === null) {
      return;
    }
    const pageBg = this.storageColor(STORE_KEYS.pageBackground, this.isDark ? '#202020' : '#FAFAFA');
    const appBar = this.storageColor(STORE_KEYS.appBar, this.isDark ? '#262626' : '#FFFFFF');
    const appBarText = this.storageColor(STORE_KEYS.appBarText, this.isDark ? '#FCFCFC' : '#333333');
    const barBg = onAppBar ? appBar : pageBg;
    const barText = onAppBar ? appBarText : (this.isDark ? '#FCFCFC' : '#333333');
    try {
      win.setWindowBackgroundColor(this.toArgb(pageBg));
    } catch (_bg) {
    }
    try {
      const sysBar: window.SystemBarProperties = {
        statusBarColor: this.toArgb(barBg),
        statusBarContentColor: this.toArgb(barText),
        isStatusBarLightIcon: this.isDark,
        navigationBarColor: this.toArgb(pageBg)
      };
      win.setWindowSystemBarProperties(sysBar);
    } catch (_e) {
    }
  }

  private bumpThemeRev(): void {
    const raw = AppStorage.get<number>(STORE_KEYS.themeRev);
    let next = 1;
    if (raw !== undefined && raw !== null) {
      next = Number(`${raw}`) + 1;
      if (Number.isNaN(next)) {
        next = 1;
      }
    }
    AppStorage.setOrCreate(STORE_KEYS.themeRev, next);
  }

  async load(): Promise<void> {
    const mode = await AppStorageUtil.getString('theme.selectedTheme', 'p-dark');
    this.followSystem = await AppStorageUtil.getBool('theme.followSystem', false);
    this.selectedTheme = mode.length > 0 ? mode : 'p-dark';
    AppStorage.setOrCreate('themeFollowSystem', this.followSystem);
    AppStorage.setOrCreate('themeSelected', this.selectedTheme);
    if (this.followSystem) {
      this.applyInner(this.isSystemDark());
    } else {
      this.applyInner(mode !== 'p-light');
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

  private persistTheme(): void {
    this.saveTheme();
  }

  private async saveTheme(): Promise<void> {
    await AppStorageUtil.setBool('theme.followSystem', this.followSystem);
    await AppStorageUtil.setString('theme.selectedTheme', this.selectedTheme);
  }

  setFollowSystem(on: boolean): void {
    this.followSystem = on;
    AppStorage.setOrCreate('themeFollowSystem', on);
    if (on) {
      this.applyInner(this.isSystemDark());
    } else {
      this.bumpThemeRev();
    }
    this.persistTheme();
  }

  setDark(dark: boolean): void {
    this.followSystem = false;
    this.selectedTheme = dark ? 'p-dark' : 'p-light';
    AppStorage.setOrCreate('themeFollowSystem', false);
    AppStorage.setOrCreate('themeSelected', this.selectedTheme);
    this.applyInner(dark);
    this.syncBg();
    this.persistTheme();
  }

  selectCustom(): void {
    this.followSystem = false;
    this.selectedTheme = 'custom';
    AppStorage.setOrCreate('themeFollowSystem', false);
    AppStorage.setOrCreate('themeSelected', 'custom');
    this.bumpThemeRev();
    this.persistTheme();
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
  AppStorage.setOrCreate(STORE_KEYS.textHint, '#99FCFCFC');
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
  AppStorage.setOrCreate(STORE_KEYS.themeRev, 0);
  AppStorage.setOrCreate('floatingLyricOn', false);
  AppStorage.setOrCreate('floatingLyricText', I18n.t('lyric.noLyric'));
  AppStorage.setOrCreate('floatingLyricInApp', true);
  AppStorage.setOrCreate('scheduleRemain', '');
  AppStorage.setOrCreate('statusBarHeight', 44);
  AppStorage.setOrCreate('gestureBarHeight', 16);
  AppStorage.setOrCreate('localMusicTick', 0);
  AppStorage.setOrCreate('lyricTick', 0);
  AppStorage.setOrCreate('lyricLoading', false);
  AppStorage.setOrCreate('musicDetailShowTick', 0);
  AppStorage.setOrCreate('playQuality', 'standard');
  AppStorage.setOrCreate('playRate', 100);
}
