import { AppNavBar } from '../components/AppNavBar';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct PermissionsPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @State floatGranted: boolean = false;
  @State audioGranted: boolean = false;
  @State bgGranted: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.refreshStatus();
  }

  onPageShow(): void {
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

  async requestFloat(): Promise<void> {
    const ok = await this.requestOne('ohos.permission.SYSTEM_FLOAT_WINDOW');
    this.refreshStatus();
    if (!ok || !this.floatGranted) {
      promptAction.showToast({
        message: I18n.t('toast.floatDenied'),
        duration: 2500
      });
      return;
    }
    promptAction.showToast({ message: I18n.t('toast.floatGranted'), duration: 2000 });
  }

  async requestAudio(): Promise<void> {
    const ok = await this.requestOne('ohos.permission.READ_AUDIO');
    this.refreshStatus();
    promptAction.showToast({
      message: ok && this.audioGranted ? I18n.t('toast.audioGranted') : I18n.t('toast.audioDenied'),
      duration: 2000
    });
  }

  async requestBackground(): Promise<void> {
    const ok = await this.requestOne('ohos.permission.KEEP_BACKGROUND_RUNNING');
    this.refreshStatus();
    promptAction.showToast({
      message: ok && this.bgGranted ? I18n.t('toast.bgGranted') : I18n.t('toast.bgDenied'),
      duration: 2000
    });
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.t('permissionSetting.pageTitle'),
        onBack: () => {
          AppService.pop();
        }
      })
      Text(I18n.t('permissionSetting.pageHint'))
        .fontSize(13)
        .fontColor(this.textSecondary)
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      List() {
        ListItem() {
          this.permRow(
            'lyric',
            I18n.t('permissionSetting.floatDesktop'),
            I18n.t('permissionSetting.floatWindowHint'),
            this.floatGranted ? I18n.t('permissionSetting.granted') : I18n.t('permissionSetting.notGrantedLimited')
          )
        }
        .onClick(() => {
          this.requestFloat();
        })

        ListItem() {
          this.permRow(
            'musical-note',
            I18n.t('permissionSetting.audioRead'),
            I18n.t('permissionSetting.importLocalHint'),
            this.audioGranted ? I18n.t('permissionSetting.granted') : I18n.t('permissionSetting.notGranted')
          )
        }
        .onClick(() => {
          this.requestAudio();
        })

        ListItem() {
          this.permRow(
            'play-circle-outline',
            I18n.t('permissionSetting.background'),
            I18n.t('permissionSetting.keepPlayingHint'),
            this.bgGranted ? I18n.t('permissionSetting.granted') : I18n.t('permissionSetting.notGranted')
          )
        }
        .onClick(() => {
          this.requestBackground();
        })
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
  permRow(icon: string, title: string, desc: string, status: string) {
    Row() {
      IconImg({ name: icon, iconSize: 20, color: this.textColor })
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
      .margin({ left: 12 })
      Text(status)
        .fontSize(13)
        .fontColor(this.textSecondary)
        .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
  }
}
