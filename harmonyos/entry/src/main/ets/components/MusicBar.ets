import { MusicItem } from '../common/Types';
import { ROUTES } from '../common/Constants';
import { IconImg } from './IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct MusicBar {
  @StorageLink('hasMusic') hasMusic: boolean = false;
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('currentTitle') currentTitle: string = '';
  @StorageLink('currentArtist') currentArtist: string = '';
  @StorageLink('currentArtwork') currentArtwork: string = '';
  @StorageLink('position') playPosition: number = 0;
  @StorageLink('duration') duration: number = 0;
  @StorageLink('musicBar') musicBar: string = '#262626';
  @StorageLink('musicBarText') musicBarText: string = '#FCFCFC';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('themeDark') themeDark: boolean = true;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;
  @State showList: boolean = false;

  private progress(): number {
    if (this.duration <= 0) {
      return 0;
    }
    return this.playPosition / this.duration;
  }

  build() {
    Column() {
      if (this.hasMusic) {
        Row() {
          Row() {
            if (this.currentArtwork.length > 0) {
              Image(this.currentArtwork)
                .width(44)
                .height(44)
                .borderRadius(6)
                .objectFit(ImageFit.Cover)
            } else {
              Image($r('app.media.album_default'))
                .width(44)
                .height(44)
                .borderRadius(6)
            }
            Column() {
              Text(this.currentTitle)
                .fontSize(14)
                .fontColor(this.musicBarText)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.currentArtist)
                .fontSize(11)
                .fontColor(this.textSecondary)
                .margin({ top: 2 })
                .maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 10 })
          }
          .layoutWeight(1)
          .height(64)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            AppService.push(ROUTES.MUSIC_DETAIL);
          })

          Stack() {
            Progress({ value: this.progress() * 100, total: 100, type: ProgressType.Ring })
              .width(36)
              .height(36)
              .color(this.musicBarText)
              .backgroundColor(this.themeDark ? '#33FFFFFF' : '#33000000')
              .style({ strokeWidth: 2 })
            IconImg({
              name: this.isPlaying ? 'pause' : 'play',
              iconSize: 16,
              color: this.musicBarText
            })
          }
          .width(36)
          .height(36)
          .onClick(() => {
            AppService.player.toggle();
          })

          Row() {
            IconImg({ name: 'playlist', iconSize: 22, color: this.musicBarText })
          }
          .width(36)
          .height(36)
          .margin({ left: 8 })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showList = true;
          })
        }
        .width('100%')
        .height(64 + this.gestureBarHeight)
        .padding({ left: 12, right: 12, bottom: this.gestureBarHeight })
        .backgroundColor(this.musicBar)
      }
    }
    .bindSheet($$this.showList, this.playListBuilder(), {
      height: SheetSize.MEDIUM,
      showClose: false,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE
    })
  }

  @Builder
  playListBuilder() {
    Column() {
      Row() {
        Text(I18n.t('panel.playList.title'))
          .fontSize(16)
          .fontColor(this.textColor)
          .layoutWeight(1)
          .maxLines(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.textColor })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showList = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })
      .alignItems(VerticalAlign.Center)
      List() {
        ForEach(AppService.player.playList, (item: MusicItem, index: number) => {
          ListItem() {
            Row() {
              Text(`${index + 1}`)
                .width(28)
                .fontSize(12)
                .fontColor(this.textSecondary)
              Column() {
                Text(item.title)
                  .fontSize(14)
                  .fontColor(this.textColor)
                  .maxLines(1)
                Text(item.artist)
                  .fontSize(12)
                  .fontColor(this.textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .onClick(() => {
              AppService.player.playListAt(index);
              this.showList = false;
            })
          }
        }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdrop)
  }
}
