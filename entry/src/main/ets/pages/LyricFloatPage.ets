@Entry
@Component
export struct LyricFloatPage {
  @StorageLink('floatingLyricText') floatingLyricText: string = '暂无歌词';

  build() {
    Row() {
      Text(this.floatingLyricText)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#CC111111')
    .justifyContent(FlexAlign.Center)
  }
}
