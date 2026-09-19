import { I18n } from '../core/I18n';

@Component
export struct EmptyView {
  @Prop text: string = I18n.t('common.emptyHere');
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  build() {
    Column() {
      Text(this.appLocale.length > 0 ? this.text : this.text)
        .fontSize(14)
        .fontColor(this.textSecondary)
        .margin({ top: 80 })
    }
    .width('100%')
    .layoutWeight(1)
  }
}
