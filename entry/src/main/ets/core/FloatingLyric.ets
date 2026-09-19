import { window } from '@kit.ArkUI';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { AppStorageUtil } from './AppStorageUtil';
import { AppConfig, KEYS } from './AppConfig';
import { I18n } from './I18n';

const PREF_KEY: string = 'lyric.showStatusBarLyric';

/**
 * 桌面/悬浮歌词。
 *
 * HarmonyOS NEXT 对第三方应用的系统悬浮窗限制较严：
 * `ohos.permission.SYSTEM_FLOAT_WINDOW` 属于 system_basic 权限，普通应用通常无法获得，
 * 因此无法在其它应用之上绘制真正的 overlay。
 *
 * 实现策略：
 * 1. 打开开关时申请权限，并尝试创建应用子窗口（WindowStage.createSubWindow）显示歌词；
 * 2. 若权限被拒或子窗口创建失败，则回退为应用内可拖动顶栏歌词条（见 FloatingLyricBar）。
 */
export class FloatingLyric {
  static enabled: boolean = false;
  static inApp: boolean = true;
  static text: string = '';

  private static context: common.UIAbilityContext | null = null;
  private static stage: window.WindowStage | null = null;
  private static subWin: window.Window | null = null;
  private static showing: boolean = false;

  static bind(context: common.UIAbilityContext, stage: window.WindowStage): void {
    FloatingLyric.context = context;
    FloatingLyric.stage = stage;
    if (FloatingLyric.enabled) {
      FloatingLyric.show();
    }
  }

  static async load(): Promise<void> {
    FloatingLyric.enabled = await AppStorageUtil.getBool(PREF_KEY, false);
    FloatingLyric.publish();
    FloatingLyric.publishStyle();
  }

  static isEnabled(): boolean {
    return FloatingLyric.enabled;
  }

  static publishStyle(): void {
    AppStorage.setOrCreate('lyricColor', AppConfig.getString(KEYS.LYRIC_COLOR, '#FFE9D2FF'));
    AppStorage.setOrCreate('lyricBg', AppConfig.getString(KEYS.LYRIC_BG, '#84888153'));
    AppStorage.setOrCreate('lyricAlign', AppConfig.getNumber(KEYS.LYRIC_ALIGN, 1));
    AppStorage.setOrCreate('lyricFont', AppConfig.getNumber(KEYS.LYRIC_FONT, 16));
    AppStorage.setOrCreate('lyricWidth', AppConfig.getNumber(KEYS.LYRIC_WIDTH, 0.5));
    AppStorage.setOrCreate('lyricLeft', AppConfig.getNumber(KEYS.LYRIC_LEFT, 0.5));
    AppStorage.setOrCreate('lyricTop', AppConfig.getNumber(KEYS.LYRIC_TOP, 0));
  }

  static async setEnabled(on: boolean): Promise<void> {
    FloatingLyric.enabled = on;
    await AppStorageUtil.setBool(PREF_KEY, on);
    FloatingLyric.publish();
    if (on) {
      await FloatingLyric.requestFloatPermission();
      await FloatingLyric.show();
    } else {
      await FloatingLyric.hide();
    }
  }

  static update(text: string): void {
    const next = text.length > 0 ? text : I18n.t('lyric.noLyric');
    if (next === FloatingLyric.text) {
      return;
    }
    FloatingLyric.text = next;
    AppStorage.setOrCreate('floatingLyricText', next);
  }

  private static publish(): void {
    AppStorage.setOrCreate('floatingLyricOn', FloatingLyric.enabled);
    AppStorage.setOrCreate('floatingLyricInApp', FloatingLyric.inApp);
    AppStorage.setOrCreate('floatingLyricText', FloatingLyric.text);
  }

  private static async requestFloatPermission(): Promise<boolean> {
    if (FloatingLyric.context === null) {
      return false;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const perms: Array<Permissions> = ['ohos.permission.SYSTEM_FLOAT_WINDOW'];
      const result = await atManager.requestPermissionsFromUser(FloatingLyric.context, perms);
      if (result.authResults && result.authResults.length > 0) {
        return result.authResults[0] === 0;
      }
    } catch (_e) {
      // 第三方包通常拿不到该权限，忽略错误并走应用内歌词条。
    }
    return false;
  }

  static async show(): Promise<void> {
    if (!FloatingLyric.enabled) {
      return;
    }
    const overlayOk = await FloatingLyric.tryCreateSubWindow();
    FloatingLyric.inApp = !overlayOk;
    FloatingLyric.showing = true;
    FloatingLyric.publish();
  }

  static async hide(): Promise<void> {
    FloatingLyric.showing = false;
    FloatingLyric.inApp = true;
    await FloatingLyric.destroySubWindow();
    FloatingLyric.publish();
  }

  private static async tryCreateSubWindow(): Promise<boolean> {
    if (FloatingLyric.stage === null) {
      return false;
    }
    await FloatingLyric.destroySubWindow();
    try {
      const win = await FloatingLyric.stage.createSubWindow('MusicFreeLyric');
      FloatingLyric.subWin = win;
      await win.resize(720, 96);
      await win.moveWindowTo(80, 160);
      win.setWindowBackgroundColor('#CC000000');
      await win.setUIContent('pages/LyricFloatPage');
      await win.showWindow();
      return true;
    } catch (_e) {
      await FloatingLyric.destroySubWindow();
      return false;
    }
  }

  private static async destroySubWindow(): Promise<void> {
    if (FloatingLyric.subWin === null) {
      return;
    }
    try {
      await FloatingLyric.subWin.destroyWindow();
    } catch (_e) {
    }
    FloatingLyric.subWin = null;
  }
}

@Component
export struct FloatingLyricBar {
  @StorageLink('floatingLyricOn') floatingLyricOn: boolean = false;
  @StorageLink('floatingLyricInApp') floatingLyricInApp: boolean = true;
  @StorageLink('floatingLyricText') floatingLyricText: string = I18n.t('lyric.noLyric');
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('lyricColor') lyricColor: string = '#FFE9D2FF';
  @StorageLink('lyricBg') lyricBg: string = '#84888153';
  @StorageLink('lyricAlign') lyricAlign: number = 1;
  @StorageLink('lyricFont') lyricFont: number = 16;
  @StorageLink('lyricWidth') lyricWidth: number = 0.5;
  @StorageLink('lyricLeft') lyricLeft: number = 0.5;
  @StorageLink('lyricTop') lyricTop: number = 0;
  @State barX: number = 16;
  @State barY: number = 52;
  private startX: number = 16;
  private startY: number = 52;

  aboutToAppear(): void {
    this.applyPercents();
  }

  private applyPercents(): void {
    this.barX = Math.max(0, this.lyricLeft * 300);
    this.barY = 8 + this.lyricTop * 220;
    this.startX = this.barX;
    this.startY = this.barY;
  }

  private alignMode(): TextAlign {
    if (this.lyricAlign === 0) {
      return TextAlign.Start;
    }
    if (this.lyricAlign === 2) {
      return TextAlign.End;
    }
    return TextAlign.Center;
  }

  build() {
    if (this.floatingLyricOn && this.floatingLyricInApp) {
      Row() {
        Text(this.floatingLyricText)
          .fontSize(this.lyricFont)
          .fontColor(this.lyricColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(this.alignMode())
          .width('100%')
      }
      .width(`${Math.floor(this.lyricWidth * 70 + 20)}%`)
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(18)
      .backgroundColor(this.lyricBg)
      .position({ x: this.barX, y: this.barY })
      .zIndex(999)
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.startX = this.barX;
            this.startY = this.barY;
          })
          .onActionUpdate((event: GestureEvent) => {
            const nx = this.startX + event.offsetX;
            const ny = this.startY + event.offsetY;
            this.barX = nx < 0 ? 0 : nx;
            this.barY = ny < 8 ? 8 : ny;
          })
      )
    }
  }
}
