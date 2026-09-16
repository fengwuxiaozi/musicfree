import { MusicItem, SheetItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct SheetDetailPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @State musics: MusicItem[] = [];
  @State sheet: SheetItem = new SheetItem();
  @State showMore: boolean = false;
  @State moreItem: MusicItem = new MusicItem();
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.refresh();
    AppService.sheets.onChange(() => {
      this.refresh();
    });
  }

  onPageShow(): void {
    this.refresh();
  }

  private refresh(): void {
    if (AppService.params.sheet !== null) {
      this.sheet = AppService.params.sheet;
    }
    const found = AppService.sheets.findSheet(AppService.params.sheetId);
    if (found !== null) {
      this.sheet = found;
    }
    this.musics = AppService.sheets.getMusics(this.sheet.id);
  }

  build() {
    Column() {
      AppNavBar({
        title: this.sheet.title,
        onBack: () => {
          AppService.pop();
        }
      }) {
        Row() {
          Row() {
            IconImg({ name: 'magnifying-glass', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openSearchMusicList(this.sheet.title, this.musics);
          })
          Row() {
            IconImg({ name: 'pencil-outline', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openMusicListEditor(this.sheet.title, this.sheet.id, this.musics);
          })
        }
      }
      Row() {
        Button(I18n.t('playAllBar.title'))
          .backgroundColor(this.primary)
          .onClick(() => {
            if (this.musics.length > 0) {
              AppService.player.playMusic(this.musics[0], this.musics);
            }
          })
        Text(I18n.t('sheetDetail.totalMusicCount').replace('{count}', `${this.musics.length}`))
          .fontSize(13)
          .fontColor(this.textSecondary)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.musics.length === 0) {
        EmptyView({ text: I18n.t('sheetDetail.empty') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                parentHandlesMore: true,
                onMore: (m: MusicItem) => {
                  this.moreItem = m;
                  this.showMore = true;
                }
              })
            }
            .onClick(() => {
              AppService.player.playMusic(item, this.musics);
            })
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
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
      Text(this.moreItem.title.length > 0 ? this.moreItem.title : I18n.t('common.unknownMusic'))
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
        this.moreRow('arrow-down-tray', I18n.t('common.download'), () => {
          AppService.downloader.download(this.moreItem);
          this.showMore = false;
        })
        this.moreRow('trash-outline', I18n.t('sheetDetail.removeFromSheet'), () => {
          AppService.sheets.removeMusics(this.sheet.id, [this.moreItem]);
          this.musics = AppService.sheets.getMusics(this.sheet.id);
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
