import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { AppNavBar } from '../components/AppNavBar';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct CustomThemePage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('bgUrl') bgUrl: string = '';
  @StorageLink('bgBlur') bgBlur: number = 20;
  @StorageLink('bgOpacity') bgOpacity: number = 0.6;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  async pickPhoto(): Promise<void> {
    try {
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      await AppService.theme.setBackgroundFromUri(result.photoUris[0]);
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backgroundSet'), duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pickImageFail'), duration: 2000 });
    }
  }

  async pickFile(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const uris = await docPicker.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['.jpg', '.jpeg', '.png', '.webp', '.gif']
      });
      if (uris.length === 0) {
        return;
      }
      await AppService.theme.setBackgroundFromUri(uris[0]);
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backgroundSet'), duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.pickFileFail'), duration: 2000 });
    }
  }

  async clearBg(): Promise<void> {
    await AppService.theme.clearBackground();
    promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.backgroundCleared'), duration: 1500 });
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.tx(this.appLocale, 'setCustomTheme.customizeBackground'), onBack: () => { AppService.pop(); } })
      Scroll() {
        Column() {
          if (this.bgUrl.length > 0) {
            Image(this.bgUrl)
              .width(180)
              .height(270)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .margin({ top: 16 })
              .syncLoad(true)
              .onClick(() => {
                this.pickPhoto();
              })
          } else {
            Column() {
              Text(I18n.tx(this.appLocale, 'setCustomTheme.clickToChoose'))
                .fontSize(14)
                .fontColor(this.textSecondary)
            }
            .width(180)
            .height(270)
            .borderRadius(12)
            .backgroundColor(this.placeholder)
            .justifyContent(FlexAlign.Center)
            .margin({ top: 16 })
            .onClick(() => {
              this.pickPhoto();
            })
          }

          Row() {
            Button(I18n.tx(this.appLocale, 'setCustomTheme.fromAlbum'))
              .backgroundColor(this.primary)
              .fontColor('#FEFEFE')
              .layoutWeight(1)
              .onClick(() => {
                this.pickPhoto();
              })
            Button(I18n.tx(this.appLocale, 'setCustomTheme.fromFile'))
              .backgroundColor(this.primary)
              .fontColor('#FEFEFE')
              .layoutWeight(1)
              .margin({ left: 12 })
              .onClick(() => {
                this.pickFile();
              })
          }
          .width('90%')
          .margin({ top: 20 })

          Button(I18n.tx(this.appLocale, 'setCustomTheme.clearBackground'))
            .width('90%')
            .margin({ top: 12 })
            .backgroundColor(this.placeholder)
            .fontColor(this.textColor)
            .onClick(() => {
              this.clearBg();
            })

          Row() {
            Text(I18n.tx(this.appLocale, 'setCustomTheme.blur'))
              .fontSize(14)
              .fontColor(this.textColor)
              .width(64)
            Slider({ value: this.bgBlur, min: 0, max: 30, step: 1 })
              .layoutWeight(1)
              .selectedColor(this.primary)
              .trackColor(this.placeholder)
              .blockColor(this.primary)
              .onChange((value: number, mode: SliderChangeMode) => {
                AppService.theme.previewBlur(value);
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  AppService.theme.setBackgroundBlur(value);
                }
              })
            Text(`${Math.floor(this.bgBlur)}`)
              .fontSize(13)
              .fontColor(this.textSecondary)
              .width(36)
              .textAlign(TextAlign.End)
          }
          .width('90%')
          .margin({ top: 28 })

          Row() {
            Text(I18n.tx(this.appLocale, 'setCustomTheme.opacity'))
              .fontSize(14)
              .fontColor(this.textColor)
              .width(64)
            Slider({ value: this.bgOpacity, min: 0.3, max: 1, step: 0.01 })
              .layoutWeight(1)
              .selectedColor(this.primary)
              .trackColor(this.placeholder)
              .blockColor(this.primary)
              .onChange((value: number, mode: SliderChangeMode) => {
                AppService.theme.previewOpacity(value);
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  AppService.theme.setBackgroundOpacity(value);
                }
              })
            Text(this.bgOpacity.toFixed(2))
              .fontSize(13)
              .fontColor(this.textSecondary)
              .width(36)
              .textAlign(TextAlign.End)
          }
          .width('90%')
          .margin({ top: 16, bottom: 32 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}
