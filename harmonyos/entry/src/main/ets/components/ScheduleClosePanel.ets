import { ScheduleClose } from '../core/ScheduleClose';
import { I18n } from '../core/I18n';
import { IconImg } from './IconImg';

@Component
export struct ScheduleClosePanel {
  onDismiss: () => void = () => {
  };
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('scheduleRemain') scheduleRemain: string = '';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State closeAfterPlay: boolean = false;
  @State showCustom: boolean = false;
  @State customMinutes: string = '';

  aboutToAppear(): void {
    this.closeAfterPlay = ScheduleClose.closeAfterPlay;
  }

  build() {
    Stack() {
      Column() {
        Text(this.scheduleRemain.length > 0 ?
          I18n.tx(this.appLocale, 'panel.timingClose.countdown').replace('{time}', this.scheduleRemain) :
          I18n.tx(this.appLocale, 'sidebar.scheduleClose'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })
        Row() {
          this.timeChip('10', () => {
            ScheduleClose.setMinutes(10);
          })
          this.timeChip('20', () => {
            ScheduleClose.setMinutes(20);
          })
          this.timeChip('30', () => {
            ScheduleClose.setMinutes(30);
          })
          this.timeChip('45', () => {
            ScheduleClose.setMinutes(45);
          })
          this.timeChip('60', () => {
            ScheduleClose.setMinutes(60);
          })
          this.timeChip(I18n.tx(this.appLocale, 'panel.timingClose.customize'), () => {
            this.customMinutes = '';
            this.showCustom = true;
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8 })
        .justifyContent(FlexAlign.SpaceBetween)

        Row() {
          IconImg({
            name: this.closeAfterPlay ? 'check-circle' : 'check-circle-outline',
            iconSize: 20,
            color: this.closeAfterPlay ? this.primary : this.textColor
          })
          Text(I18n.tx(this.appLocale, 'panel.timingClose.closeAfterPlay'))
            .fontSize(14)
            .fontColor(this.textColor)
            .margin({ left: 8 })
        }
        .width('90%')
        .margin({ top: 20 })
        .justifyContent(FlexAlign.Start)
        .onClick(() => {
          this.closeAfterPlay = !this.closeAfterPlay;
          ScheduleClose.setCloseAfterPlay(this.closeAfterPlay);
        })

        if (this.scheduleRemain.length > 0) {
          Text(I18n.tx(this.appLocale, 'panel.timingClose.cancelScheduleClose'))
            .fontSize(13)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .borderRadius(4)
            .backgroundColor('#99FF6666')
            .margin({ top: 16, bottom: 16 })
            .onClick(() => {
              ScheduleClose.cancel();
            })
        }
      }
      .width('100%')
      .backgroundColor(this.backdrop)

      if (this.showCustom) {
        this.customOverlay()
      }
    }
    .width('100%')
  }

  @Builder
  timeChip(label: string, action: () => void) {
    Text(label)
      .fontSize(13)
      .fontColor(this.textColor)
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .borderRadius(8)
      .backgroundColor(this.placeholder)
      .onClick(action)
  }

  @Builder
  customOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showCustom = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'panel.timingClose.customize'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        TextInput({ placeholder: I18n.tx(this.appLocale, 'panel.timingClose.customize'), text: this.customMinutes })
          .type(InputType.Number)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .backgroundColor(this.placeholder)
          .caretColor(this.primary)
          .margin({ left: 16, right: 16, top: 8 })
          .onChange((v: string) => {
            this.customMinutes = v;
          })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 16 })
            .onClick(() => {
              this.showCustom = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 16 })
            .onClick(() => {
              const minutes = Number.parseInt(this.customMinutes, 10);
              if (!Number.isNaN(minutes) && minutes > 0) {
                ScheduleClose.setMinutes(minutes);
                this.showCustom = false;
                this.onDismiss();
              }
            })
        }
        .width('100%')
      }
      .width('80%')
      .borderRadius(12)
      .backgroundColor(this.backdrop)
      .padding({ bottom: 8 })
    }
    .width('100%')
    .height(280)
  }
}
