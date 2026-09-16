import { PluginSubscribeItem } from '../core/PluginManager';
import { AppNavBar } from '../components/AppNavBar';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';

@Component
export struct PluginSubscribePage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @State items: PluginSubscribeItem[] = [];
  @State showAdd: boolean = false;
  @State nameInput: string = '';
  @State urlInput: string = '';
  @State editing: number = -1;
  @State updating: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.items = AppService.plugins.getSubscribes();
  }

  private validUrl(url: string): boolean {
    return url.endsWith('.js') || url.endsWith('.json');
  }

  private submit(): void {
    const name = this.nameInput.trim().length > 0 ? this.nameInput.trim() : I18n.t('pluginSubscribe.defaultName');
    const url = this.urlInput.trim();
    if (!this.validUrl(url)) {
      promptAction.showToast({ message: I18n.t('toast.subscriptionHaveToEndWithJs'), duration: 2000 });
      return;
    }
    if (this.editing >= 0) {
      AppService.plugins.updateSubscribe(this.editing, name, url);
    } else {
      AppService.plugins.addSubscribe(name, url);
    }
    this.showAdd = false;
    this.reload();
  }

  async updateAll(): Promise<void> {
    if (this.items.length === 0) {
      promptAction.showToast({ message: I18n.t('toast.noSubscription'), duration: 2000 });
      return;
    }
    this.updating = true;
    try {
      const msg = await AppService.plugins.updateFromSubscribe();
      promptAction.showToast({ message: msg, duration: 2500 });
    } catch (e) {
      promptAction.showToast({ message: e instanceof Error ? e.message : I18n.t('toast.updateSubscribeFail'), duration: 2500 });
    }
    this.updating = false;
  }

  private copyUrl(url: string): void {
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      board.setData(data);
      promptAction.showToast({ message: I18n.t('toast.linkCopied'), duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: url, duration: 2000 });
    }
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.t('pluginSetting.menu.subscriptionSetting'),
        onBack: () => {
          AppService.pop();
        }
      })

      Row() {
        Button(this.updating ? I18n.t('pluginSubscribe.updating') : I18n.t('pluginSetting.fabOptions.updateSubscription'))
          .backgroundColor(this.primary)
          .fontColor('#FEFEFE')
          .enabled(!this.updating)
          .onClick(() => {
            this.updateAll();
          })
        Button(I18n.t('pluginSubscribe.add'))
          .margin({ left: 12 })
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .onClick(() => {
            this.editing = -1;
            this.nameInput = '';
            this.urlInput = '';
            this.showAdd = true;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Text(I18n.t('pluginSubscribe.hint'))
        .fontSize(12)
        .fontColor(this.textSecondary)
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.items.length === 0) {
        EmptyView({ text: I18n.t('pluginSubscribe.empty') })
      } else {
        List() {
          ForEach(this.items, (item: PluginSubscribeItem, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(16)
                    .fontColor(this.textColor)
                  Text(item.url)
                    .fontSize(12)
                    .fontColor(this.textSecondary)
                    .maxLines(2)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => {
                  this.editing = index;
                  this.nameInput = item.name;
                  this.urlInput = item.url;
                  this.showAdd = true;
                })
                IconImg({ name: 'share', iconSize: 18, color: this.textSecondary })
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.copyUrl(item.url);
                  })
                IconImg({ name: 'trash-outline', iconSize: 18, color: this.textSecondary })
                  .margin({ left: 12 })
                  .onClick(() => {
                    AppService.plugins.removeSubscribe(index);
                    this.reload();
                    promptAction.showToast({ message: I18n.t('toast.deleted'), duration: 1500 });
                  })
              }
              .width('100%')
              .padding(16)
            }
          }, (item: PluginSubscribeItem, index: number) => `${index}-${item.url}`)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
    .bindSheet($$this.showAdd, this.addBuilder(), {
      height: 320,
      showClose: false,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE,
      maskColor: this.maskColor
    })
  }

  @Builder
  addBuilder() {
    Column() {
      Row() {
        Text(this.editing >= 0 ? I18n.t('pluginSubscribe.edit') : I18n.t('pluginSubscribe.add'))
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
          this.showAdd = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 8 })
      TextInput({ placeholder: I18n.t('pluginSubscribe.namePlaceholder'), text: this.nameInput })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .onChange((v: string) => {
          this.nameInput = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      TextInput({ placeholder: I18n.t('pluginSubscribe.urlPlaceholder'), text: this.urlInput })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .onChange((v: string) => {
          this.urlInput = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(I18n.t('common.save'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .onClick(() => {
          this.submit();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdrop)
  }
}
