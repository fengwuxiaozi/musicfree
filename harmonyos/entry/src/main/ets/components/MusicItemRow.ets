import { MusicItem } from '../common/Types';
import { IconImg } from './IconImg';
import { MusicOptionsSheet } from './MusicOptionsSheet';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct MusicItemRow {
  @Prop item: MusicItem = new MusicItem();
  @Prop index: number = 0;
  @Prop showIndex: boolean = false;
  @Prop parentHandlesMore: boolean = false;
  @Prop parentHandlesPlay: boolean = false;
  @Prop sheetId: string = '';
  @Prop fromDetail: boolean = false;
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('divider') divider: string = '#1AFFFFFF';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('downloadTick') downloadTick: number = 0;
  @State showMore: boolean = false;
  onMore: (item: MusicItem) => void = (_item: MusicItem) => {
  };
  onPlay: (item: MusicItem) => void = (_item: MusicItem) => {
  };
  onTimingClose: () => void = () => {
  };

  private downloaded(): boolean {
    return this.downloadTick >= 0 && AppService.isDownloaded(this.item);
  }

  private descText(): string {
    if (this.item.album.length > 0) {
      return `${this.item.artist} - ${this.item.album}`;
    }
    return this.item.artist;
  }

  build() {
    Row() {
      if (this.showIndex) {
        Text(`${this.index + 1}`)
          .width(36)
          .fontSize(14)
          .fontColor(this.textColor)
          .fontStyle(FontStyle.Italic)
          .textAlign(TextAlign.Center)
      }
      Column() {
        Row() {
          Text(this.item.title.length > 0 ? this.item.title : I18n.tx(this.appLocale, 'common.unknownMusic'))
            .fontSize(15)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.item.platform.length > 0) {
            Text(this.item.platform)
              .fontSize(10)
              .fontColor(this.textColor)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ left: 6 })
              .borderRadius(12)
              .border({ width: 1, color: this.divider })
              .backgroundColor(this.card)
              .constraintSize({ maxWidth: 88 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Row() {
          if (this.downloaded()) {
            IconImg({ name: 'check-circle', iconSize: 11, color: '#11659A' })
              .margin({ right: 4 })
          }
          Text(this.descText())
            .fontSize(12)
            .fontColor(this.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 6 })
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: this.showIndex ? 0 : 4 })
      .onClick(() => {
        if (this.parentHandlesPlay) {
          this.onPlay(this.item);
        } else {
          AppService.player.playMusic(this.item);
        }
      })

      Row() {
        IconImg({ name: 'ellipsis-vertical', iconSize: 18, color: this.textColor })
      }
      .width(24)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.parentHandlesMore) {
          this.onMore(this.item);
        } else {
          this.showMore = true;
        }
      })
    }
    .width('100%')
    .height(60)
    .padding({ left: 12, right: 12 })
    .bindSheet($$this.showMore, this.moreBuilder(), {
      height: SheetSize.LARGE,
      showClose: false,
      backgroundColor: this.backdrop,
      maskColor: this.maskColor,
      blurStyle: BlurStyle.NONE
    })
  }

  @Builder
  moreBuilder() {
    MusicOptionsSheet({
      item: this.item,
      sheetId: this.sheetId,
      fromDetail: this.fromDetail,
      onClose: () => {
        this.showMore = false;
      },
      onTimingClose: () => {
        this.onTimingClose();
      }
    })
  }
}
