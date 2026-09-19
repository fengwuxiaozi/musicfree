import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppService } from '../core/AppService';
import { FloatingLyric } from '../core/FloatingLyric';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    await AppService.init(this.context);
    FloatingLyric.bind(this.context, windowStage);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return;
      }
    });
    windowStage.getMainWindow().then((win: window.Window) => {
      AppService.mainWindow = win;
      win.setWindowLayoutFullScreen(true);
      AppService.theme.apply(AppService.theme.isDark);
      try {
        const avoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        let top: number = px2vp(avoid.topRect.height);
        let bottom: number = px2vp(avoid.bottomRect.height);
        if (top < 24) {
          top = 44;
        }
        AppStorage.setOrCreate('statusBarHeight', top);
        AppStorage.setOrCreate('gestureBarHeight', bottom);
      } catch (_e) {
      }
    }).catch(() => {
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (AppService.theme.followSystem) {
      AppService.theme.apply(newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    }
  }

  onBackground(): void {
    AppService.player.refreshSession();
  }

  onForeground(): void {
    AppService.player.refreshSession();
  }
}
