import { PluginMeta } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { promptAction } from '@kit.ArkUI';

@Component
export struct PluginSortPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State plugins: PluginMeta[] = [];

  aboutToAppear(): void {
    this.refresh();
    AppService.plugins.onChange(() => {
      this.refresh();
    });
  }

  private refresh(): void {
    this.plugins = AppService.plugins.sortedPlugins();
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.t('pluginSetting.menu.sort'),
        onBack: () => {
          AppService.pop();
        }
      })

      Text(I18n.t('pluginSort.hint'))
        .fontSize(12)
        .fontColor(this.textSecondary)
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.plugins.length === 0) {
        EmptyView({ text: I18n.t('pluginPage.emptyList') })
      } else {
        List() {
          ForEach(this.plugins, (p: PluginMeta, index: number) => {
            ListItem() {
              Row() {
                Text(`${index + 1}`)
                  .fontSize(14)
                  .fontColor(this.textSecondary)
                  .width(28)
                Column() {
                  Text(p.platform.length > 0 ? p.platform : I18n.t('common.unknownPlugin'))
                    .fontSize(16)
                    .fontColor(this.textColor)
                  Text(p.version.length > 0 ? `v${p.version}` : '')
                    .fontSize(12)
                    .fontColor(this.textSecondary)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                IconImg({ name: 'arrow-up-tray', iconSize: 18, color: index === 0 ? this.textSecondary : this.textColor })
                  .opacity(index === 0 ? 0.3 : 1)
                  .onClick(() => {
                    AppService.plugins.movePlugin(index, -1);
                  })
                IconImg({ name: 'arrow-down-tray', iconSize: 18, color: index === this.plugins.length - 1 ? this.textSecondary : this.textColor })
                  .margin({ left: 16 })
                  .opacity(index === this.plugins.length - 1 ? 0.3 : 1)
                  .onClick(() => {
                    AppService.plugins.movePlugin(index, 1);
                  })
              }
              .width('100%')
              .padding(16)
            }
          }, (p: PluginMeta) => p.hash)
        }
        .layoutWeight(1)
        .width('100%')
      }

      Button(I18n.t('common.done'))
        .width('90%')
        .margin({ bottom: 24, top: 8 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .onClick(() => {
          promptAction.showToast({ message: I18n.t('toast.orderSaved'), duration: 1500 });
          AppService.pop();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}
