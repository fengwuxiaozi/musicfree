import { AppNavBar } from '../components/AppNavBar';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { abilityAccessCtrl, Permissions, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct PermissionsPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('permPageRev') @Watch('onPermRev') permPageRev: number = 0;
  @State floatGranted: boolean = false;
  @State audioGranted: boolean = false;
  @State bgGranted: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  private opening: boolean = false;

  aboutToAppear(): void {
    this.refreshStatus();
  }

  onPageShow(): void {
    this.refreshStatus();
  }

  onPermRev(): void {
    this.refreshStatus();
  }

  private refreshStatus(): void {
    this.floatGranted = this.checkGranted('ohos.permission.SYSTEM_FLOAT_WINDOW');
    this.audioGranted = this.checkGranted('ohos.permission.READ_AUDIO');
    this.bgGranted = this.checkGranted('ohos.permission.KEEP_BACKGROUND_RUNNING');
  }

  private checkGranted(permission: Permissions): boolean {
    const ctx = AppService.context;
    if (ctx === null) {
      return false;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const status: abilityAccessCtrl.GrantStatus =
        atManager.checkAccessTokenSync(ctx.applicationInfo.accessTokenId, permission);
      return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (_e) {
      return false;
    }
  }

  private grantedOf(kind: number): boolean {
    if (kind === 0) {
      return this.floatGranted;
    }
    if (kind === 1) {
      return this.audioGranted;
    }
    return this.bgGranted;
  }

  private permissionOf(kind: number): Permissions {
    if (kind === 0) {
      return 'ohos.permission.SYSTEM_FLOAT_WINDOW';
    }
    if (kind === 1) {
      return 'ohos.permission.READ_AUDIO';
    }
    return 'ohos.permission.KEEP_BACKGROUND_RUNNING';
  }

  private async requestOne(permission: Permissions): Promise<boolean> {
    const ctx = AppService.context;
    if (ctx === null) {
      return false;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const perms: Array<Permissions> = [permission];
      const result = await atManager.requestPermissionsFromUser(ctx, perms);
      if (result.authResults && result.authResults.length > 0) {
        return result.authResults[0] === 0;
      }
    } catch (_e) {
    }
    return false;
  }

  private async openAppSettings(): Promise<boolean> {
    const ctx = AppService.context;
    if (ctx === null) {
      return false;
    }
    const bundle: string = ctx.abilityInfo.bundleName;
    const first: Want = {
      action: 'action.settings.app.info',
      parameters: {
        'settingsParamBundleName': bundle
      }
    };
    try {
      await ctx.startAbility(first);
      return true;
    } catch (_e1) {
    }
    const second: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'application_info_entry',
      parameters: {
        'pushParams': bundle
      }
    };
    try {
      await ctx.startAbility(second);
      return true;
    } catch (_e2) {
    }
    return false;
  }

  async handlePerm(kind: number): Promise<void> {
    if (this.opening) {
      return;
    }
    this.opening = true;
    try {
      if (this.grantedOf(kind)) {
        const opened = await this.openAppSettings();
        if (!opened) {
          promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.openSettingsFail'), duration: 2500 });
        }
        return;
      }
      await this.requestOne(this.permissionOf(kind));
      this.refreshStatus();
      if (!this.grantedOf(kind)) {
        const opened = await this.openAppSettings();
        if (!opened) {
          promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.openSettingsFail'), duration: 2500 });
        }
      }
    } finally {
      this.opening = false;
      this.refreshStatus();
    }
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.tx(this.appLocale, 'permissionSetting.title'),
        onBack: () => {
          AppService.pop();
        }
      })
      Text(I18n.tx(this.appLocale, 'permissionSetting.description'))
        .fontSize(13)
        .fontColor(this.textSecondary)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      List() {
        ListItem() {
          this.permRow(
            0,
            I18n.tx(this.appLocale, 'permissionSetting.floatWindow'),
            I18n.tx(this.appLocale, 'permissionSetting.floatWindowHint'),
            this.floatGranted
          )
        }
        ListItem() {
          this.permRow(
            1,
            I18n.tx(this.appLocale, 'permissionSetting.audio'),
            I18n.tx(this.appLocale, 'permissionSetting.audioHint'),
            this.audioGranted
          )
        }
        ListItem() {
          this.permRow(
            2,
            I18n.tx(this.appLocale, 'permissionSetting.background'),
            I18n.tx(this.appLocale, 'permissionSetting.backgroundHint'),
            this.bgGranted
          )
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  permRow(kind: number, title: string, desc: string, granted: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(this.textColor)
        Text(desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: granted })
        .id(`perm-switch-${kind}-${granted}-${this.permPageRev}`)
        .selectedColor(this.primary)
        .onChange((on: boolean) => {
          if (on === this.grantedOf(kind)) {
            return;
          }
          this.handlePerm(kind);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.handlePerm(kind);
    })
  }
}
