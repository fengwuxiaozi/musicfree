import { RepeatMode } from '../common/Constants';
import { MusicItem, LyricLine } from '../common/Types';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { AppConfig, KEYS } from '../core/AppConfig';
import { formatTime, showToast } from '../core/HttpUtil';
import { LyricExtra } from '../core/LyricExtra';
import { FloatingLyric } from '../core/FloatingLyric';
import { I18n } from '../core/I18n';

@Component
export struct MusicDetailPage {
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('currentTitle') currentTitle: string = '';
  @StorageLink('currentArtist') currentArtist: string = '';
  @StorageLink('currentArtwork') currentArtwork: string = '';
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('position') playPosition: number = 0;
  @StorageLink('duration') duration: number = 0;
  @StorageLink('lyricLine') lyricLine: string = I18n.t('lyric.noLyric');
  @StorageLink('hasTranslation') hasTranslation: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;
  @State showLyric: boolean = false;
  @State showList: boolean = false;
  @State loved: boolean = false;
  @State lyrics: LyricLine[] = [];
  @State lyricIndex: number = -1;
  @State repeat: RepeatMode = RepeatMode.QUEUE;
  @State lyricFontSize: number = 16;
  @State showTranslation: boolean = false;
  @State hasAssociated: boolean = false;
  @State showOffset: boolean = false;
  @State offsetDraft: number = 0;
  private detailText: string = '#FCFCFC';
  private detailSecondary: string = '#B3FCFCFC';
  private detailSheetBg: string = '#303030';
  private timer: number = -1;

  aboutToAppear(): void {
    this.showLyric = AppConfig.getString(KEYS.DETAIL_DEFAULT, 'album') === 'lyric';
    this.sync();
    this.timer = setInterval(() => {
      this.sync();
    }, 400);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  private sync(): void {
    this.lyrics = AppService.player.lyrics.slice();
    this.lyricIndex = AppService.player.lyricIndex;
    this.repeat = AppService.player.repeatMode;
    this.lyricFontSize = LyricExtra.getFontSize();
    this.showTranslation = LyricExtra.isShowTranslation();
    this.hasTranslation = AppService.player.hasTranslation;
    const current = AppService.player.current;
    this.hasAssociated = current !== null && LyricExtra.getAssociated(current) !== null;
    FloatingLyric.update(this.lyricLine);
    if (current !== null) {
      this.loved = AppService.sheets.isFavorite(current);
    }
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

  private translationFontSize(): number {
    const size = this.lyricFontSize - 2;
    return size < 12 ? 12 : size;
  }

  private cycleFont(): void {
    const cur = LyricExtra.getFontSize();
    let next = 16;
    if (cur <= 14) {
      next = 16;
    } else if (cur <= 16) {
      next = 18;
    } else {
      next = 14;
    }
    LyricExtra.setFontSize(next);
    this.lyricFontSize = next;
  }

  private openOffset(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    this.offsetDraft = LyricExtra.getOffset(current);
    this.showOffset = true;
  }

  private applyOffset(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    LyricExtra.setOffset(current, this.offsetDraft);
    AppService.player.reloadLyric();
    this.showOffset = false;
    showToast(I18n.t('lyric.offsetUpdated'));
  }

  private offsetLabel(): string {
    if (this.offsetDraft === 0) {
      return I18n.t('panel.setLyricOffset.normal');
    }
    if (this.offsetDraft > 0) {
      return I18n.t('lyric.offsetAdvance').replace('{time}', this.offsetDraft.toFixed(1));
    }
    return I18n.t('lyric.offsetDelay').replace('{time}', (-this.offsetDraft).toFixed(1));
  }

  private searchLyric(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    AppService.openSearchLyric(current.title);
  }

  private toggleTranslation(): void {
    if (!this.hasTranslation) {
      showToast(I18n.t('lyric.noTranslation'));
      return;
    }
    const next = !LyricExtra.isShowTranslation();
    LyricExtra.setShowTranslation(next);
    this.showTranslation = next;
    AppService.player.refreshUi();
  }

  private clearAssociatedLyric(): void {
    const current = AppService.player.current;
    if (current === null) {
      return;
    }
    LyricExtra.clearAssociated(current);
    this.hasAssociated = false;
    AppService.player.reloadLyric();
    showToast(I18n.t('panel.musicItemOptions.unassociateLyricSuccess'));
  }

  build() {
    Column() {
      Row() {
        IconImg({ name: 'arrow-left', iconSize: 22, color: this.detailText })
          .onClick(() => {
            AppService.pop();
          })
        Column() {
          Text(this.currentTitle.length > 0 ? this.currentTitle : I18n.t('musicDetail.notPlaying'))
            .fontSize(16)
            .fontColor(this.detailText)
            .maxLines(1)
          Text(this.currentArtist)
            .fontSize(12)
            .fontColor(this.detailSecondary)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        IconImg({ name: 'arrow-down-tray', iconSize: 22, color: this.detailText })
          .onClick(() => {
            if (AppService.player.current !== null) {
              AppService.downloader.download(AppService.player.current);
            }
          })
        IconImg({
          name: this.loved ? 'heart' : 'heart-outline',
          iconSize: 22,
          color: this.loved ? '#FC5F5F' : this.detailText
        })
          .margin({ left: 16 })
          .onClick(() => {
            if (AppService.player.current !== null) {
              AppService.sheets.toggleFavorite(AppService.player.current);
              this.loved = AppService.sheets.isFavorite(AppService.player.current);
            }
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .margin({ top: this.statusBarHeight })

      if (this.showLyric) {
        this.lyricView()
        this.lyricOps()
      } else {
        Column() {
          if (this.currentArtwork.length > 0) {
            Image(this.currentArtwork)
              .width(280)
              .height(280)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .margin({ top: 24 })
          } else {
            Image($r('app.media.album_default'))
              .width(280)
              .height(280)
              .borderRadius(12)
              .margin({ top: 24 })
          }
          Text(this.lyricLine)
            .fontSize(14)
            .fontColor(this.detailSecondary)
            .margin({ top: 24 })
            .padding({ left: 24, right: 24 })
            .maxLines(2)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .onClick(() => {
          this.showLyric = true;
        })
      }

      Slider({
        value: this.duration > 0 ? this.playPosition : 0,
        min: 0,
        max: this.duration > 0 ? this.duration : 1,
        step: 0.5,
        style: SliderStyle.OutSet
      })
        .blockColor(this.detailText)
        .trackColor('#33FFFFFF')
        .selectedColor(this.primary)
        .showTips(false)
        .onChange((v: number) => {
          AppService.player.seekTo(v);
        })
        .width('88%')
        .margin({ top: 8 })

      Row() {
        Text(formatTime(this.playPosition)).fontSize(11).fontColor(this.detailSecondary)
        Blank()
        Text(formatTime(this.duration)).fontSize(11).fontColor(this.detailSecondary)
      }
      .width('88%')
      .margin({ bottom: 8 })

      Row() {
        IconImg({ name: this.repeatIcon(), iconSize: 24, color: this.detailText })
          .onClick(() => {
            AppService.player.toggleRepeatMode();
            this.repeat = AppService.player.repeatMode;
          })
        IconImg({ name: 'skip-left', iconSize: 32, color: this.detailText })
          .onClick(() => {
            AppService.player.skipToPrevious();
          })
        IconImg({ name: this.isPlaying ? 'pause' : 'play', iconSize: 48, color: this.detailText })
          .onClick(() => {
            AppService.player.toggle();
          })
        IconImg({ name: 'skip-right', iconSize: 32, color: this.detailText })
          .onClick(() => {
            AppService.player.skipToNext();
          })
        IconImg({ name: 'playlist', iconSize: 22, color: this.detailText })
          .onClick(() => {
            this.showList = true;
          })
      }
      .width('88%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 36, top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#141414')
    .bindSheet($$this.showOffset, this.offsetBuilder(), {
      height: 260,
      showClose: false,
      backgroundColor: this.detailSheetBg,
      blurStyle: BlurStyle.NONE
    })
    .bindSheet($$this.showList, this.playListBuilder(), {
      height: SheetSize.MEDIUM,
      showClose: false,
      backgroundColor: this.detailSheetBg,
      blurStyle: BlurStyle.NONE
    })
  }

  @Builder
  lyricView() {
    if (this.lyrics.length === 0) {
      Column() {
        Text(I18n.t('lyric.noLyric'))
          .fontSize(this.lyricFontSize)
          .fontColor(this.detailSecondary)
          .margin({ top: 80 })
      }
      .layoutWeight(1)
      .width('100%')
      .onClick(() => {
        this.showLyric = false;
      })
    } else {
      List() {
        ForEach(this.lyrics, (line: LyricLine, index: number) => {
          ListItem() {
            Column() {
              Text(line.text)
                .fontSize(this.lyricIndex === index ? this.lyricFontSize + 2 : this.lyricFontSize)
                .fontColor(this.lyricIndex === index ? this.primary : this.detailSecondary)
                .width('100%')
                .textAlign(TextAlign.Center)
              if (this.showTranslation && line.translation.length > 0) {
                Text(line.translation)
                  .fontSize(this.translationFontSize())
                  .fontColor(this.detailSecondary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .margin({ top: 4 })
              }
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }
          .onClick(() => {
            AppService.player.seekTo(line.time);
          })
        }, (line: LyricLine, index: number) => `${index}-${line.time}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 24, right: 24 })
    }
  }

  @Builder
  lyricOps() {
    Row() {
      IconImg({ name: 'font-size', iconSize: 22, color: this.detailText })
        .onClick(() => {
          this.cycleFont();
        })
      IconImg({ name: 'arrows-left-right', iconSize: 22, color: this.detailText })
        .onClick(() => {
          this.openOffset();
        })
      IconImg({ name: 'magnifying-glass', iconSize: 22, color: this.detailText })
        .onClick(() => {
          this.searchLyric();
        })
      IconImg({
        name: 'translation',
        iconSize: 22,
        color: this.showTranslation && this.hasTranslation ? this.primary : this.detailText
      })
        .onClick(() => {
          this.toggleTranslation();
        })
      if (this.hasAssociated) {
        IconImg({ name: 'link-slash', iconSize: 22, color: this.detailText })
          .onClick(() => {
            this.clearAssociatedLyric();
          })
      }
    }
    .width('88%')
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .margin({ top: 8, bottom: 4 })
  }

  @Builder
  offsetBuilder() {
    Column() {
      Row() {
        Text(I18n.t('lyric.offsetTitle'))
          .fontSize(16)
          .fontColor(this.detailText)
          .layoutWeight(1)
          .maxLines(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.detailText })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showOffset = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })
      .alignItems(VerticalAlign.Center)
      Text(this.offsetLabel())
        .fontSize(16)
        .fontColor(this.detailText)
        .margin({ top: 12, bottom: 8 })
      Slider({
        value: this.offsetDraft,
        min: -10,
        max: 10,
        step: 0.5,
        style: SliderStyle.OutSet
      })
        .blockColor(this.detailText)
        .trackColor('#33FFFFFF')
        .selectedColor(this.primary)
        .width('88%')
        .onChange((v: number) => {
          this.offsetDraft = v;
        })
      Button(I18n.t('common.confirm'))
        .width('88%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FEFEFE')
        .onClick(() => {
          this.applyOffset();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.detailSheetBg)
  }

  @Builder
  playListBuilder() {
    Column() {
      Row() {
        Text(I18n.t('panel.playList.title'))
          .fontSize(16)
          .fontColor(this.detailText)
          .layoutWeight(1)
          .maxLines(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.detailText })
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
                .fontColor(this.detailSecondary)
              Column() {
                Text(item.title)
                  .fontSize(14)
                  .fontColor(this.detailText)
                  .maxLines(1)
                Text(item.artist)
                  .fontSize(12)
                  .fontColor(this.detailSecondary)
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
    .backgroundColor(this.detailSheetBg)
  }
}
