import { MusicItem } from '../common/Types';
import { RepeatMode, ROUTES } from '../common/Constants';
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
  @StorageLink('textHint') textHint: string = '#99FCFCFC';
  @StorageLink('themeDark') themeDark: boolean = true;
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('gestureBarHeight') gestureBarHeight: number = 16;
  @State showList: boolean = false;
  @State repeat: RepeatMode = RepeatMode.QUEUE;
  @State listItems: MusicItem[] = [];

  private progress(): number {
    if (this.duration <= 0) {
      return 0;
    }
    return this.playPosition / this.duration;
  }

  private refreshSheet(): void {
    this.repeat = AppService.player.repeatMode;
    this.listItems = AppService.player.playList.slice();
  }

  private repeatIcon(): string {
    if (this.repeat === RepeatMode.SINGLE) {
      return 'repeat-song';
    }
    if (this.repeat === RepeatMode.SHUFFLE) {
      return 'shuffle';
    }
    return 'repeat-song-1';
  }

  private repeatLabel(): string {
    if (this.repeat === RepeatMode.SINGLE) {
      return I18n.tx(this.appLocale, 'repeatMode.SINGLE');
    }
    if (this.repeat === RepeatMode.SHUFFLE) {
      return I18n.tx(this.appLocale, 'repeatMode.SHUFFLE');
    }
    return I18n.tx(this.appLocale, 'repeatMode.QUEUE');
  }

  private countLabel(): string {
    return I18n.tx(this.appLocale, 'panel.playList.count').replace('{count}', `${this.listItems.length}`);
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
                .fontColor(this.textHint)
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
              .backgroundColor(this.themeDark ? '#33FCFCFC' : '#33333333')
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
            IconImg({ name: 'playlist', iconSize: 28, color: this.musicBarText })
          }
          .width(36)
          .height(36)
          .margin({ left: 18 })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.refreshSheet();
            this.showList = true;
          })
        }
        .width('100%')
        .height(64 + this.gestureBarHeight)
        .padding({ left: 12, right: 12, bottom: this.gestureBarHeight })
        .backgroundColor(this.musicBar)
      }
    }
    .id(`musicbar-${this.appLocale}`)
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
        Text() {
          Span(I18n.tx(this.appLocale, 'panel.playList.title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
          Span(this.countLabel())
            .fontSize(14)
            .fontColor(this.textSecondary)
        }
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          IconImg({ name: this.repeatIcon(), iconSize: 18, color: this.textColor })
          Text(this.repeatLabel())
            .fontSize(14)
            .fontColor(this.textColor)
            .margin({ left: 4 })
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          AppService.player.toggleRepeatMode();
          this.repeat = AppService.player.repeatMode;
        })

        Row() {
          IconImg({ name: 'trash-outline', iconSize: 18, color: this.textColor })
          Text(I18n.tx(this.appLocale, 'common.clear'))
            .fontSize(14)
            .fontColor(this.textColor)
            .margin({ left: 4 })
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          AppService.player.clearPlayList();
          this.refreshSheet();
        })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .margin({ top: 9, bottom: 6 })
      .alignItems(VerticalAlign.Center)

      List() {
        ForEach(this.listItems, (item: MusicItem, index: number) => {
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
