import { MusicItem } from '../common/Types';
import { IconImg } from './IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct MusicItemRow {
  @Prop item: MusicItem = new MusicItem();
  @Prop index: number = 0;
  @Prop parentHandlesMore: boolean = false;
  @Prop parentHandlesPlay: boolean = false;
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State showMore: boolean = false;
  onMore: (item: MusicItem) => void = (_item: MusicItem) => {
  };
  onPlay: (item: MusicItem) => void = (_item: MusicItem) => {
  };

  build() {
    Row() {
      if (this.item.artwork.length > 0) {
        Image(this.item.artwork)
          .width(48)
          .height(48)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor(this.placeholder)
      } else {
        Image($r('app.media.album_default'))
          .width(48)
          .height(48)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
      }
      Column() {
        Text(this.item.title.length > 0 ? this.item.title : I18n.t('common.unknownMusic'))
          .fontSize(15)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.item.artist}  ·  ${this.item.platform}`)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Row() {
        IconImg({ name: 'ellipsis-vertical', iconSize: 20, color: this.textSecondary })
      }
      .width(36)
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
    .padding({ left: 16, right: 8, top: 8, bottom: 8 })
    .onClick(() => {
      if (this.parentHandlesPlay) {
        this.onPlay(this.item);
      } else {
        AppService.player.playMusic(this.item);
      }
    })
    .bindSheet($$this.showMore, this.moreBuilder(), {
      height: 280,
      showClose: false,
      backgroundColor: this.backdrop.length > 0 ? this.backdrop : this.pageBackground,
      maskColor: this.maskColor
    })
  }

  @Builder
  sheetHeader() {
    Row() {
      Text(this.item.title.length > 0 ? this.item.title : I18n.t('common.unknownMusic'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Row() {
        IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.showMore = false;
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 8 })
  }

  @Builder
  moreBuilder() {
    Column() {
      this.sheetHeader()
      Column() {
        this.moreRow('motion-play', I18n.t('musicListEditor.addToNextPlay'), () => {
          AppService.player.addNext(this.item);
          this.showMore = false;
        })
        this.moreRow('heart-outline', I18n.t('common.addToFavorite'), () => {
          AppService.sheets.toggleFavorite(this.item);
          this.showMore = false;
        })
        this.moreRow('arrow-down-tray', I18n.t('common.download'), () => {
          AppService.downloader.download(this.item);
          this.showMore = false;
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(this.backdrop.length > 0 ? this.backdrop : this.pageBackground)
  }

  @Builder
  moreRow(icon: string, title: string, action: () => void) {
    Row() {
      IconImg({ name: icon, iconSize: 20, color: this.textColor })
      Text(title).fontSize(15).fontColor(this.textColor).margin({ left: 12 })
    }
    .width('100%')
    .height(48)
    .onClick(action)
  }
}
