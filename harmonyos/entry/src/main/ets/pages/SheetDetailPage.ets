import { MusicItem, SheetItem } from '../common/Types';
import { FAVORITE_SHEET_ID, RepeatMode } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { showToast } from '../core/HttpUtil';

@Component
export struct SheetDetailPage {
  @StorageLink('pageBackground') pageBackground: string = '#FF202020';
  @StorageLink('backdrop') backdrop: string = '#FF303030';
  @StorageLink('textColor') textColor: string = '#FFFCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('primary') primary: string = '#FF3FA3B5';
  @StorageLink('appBarText') appBarText: string = '#FFFCFCFC';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('placeholder') placeholder: string = '#FF424242';
  @State musics: MusicItem[] = [];
  @State sheet: SheetItem = new SheetItem();
  @State showRename: boolean = false;
  @State renameDraft: string = '';
  @State showSort: boolean = false;
  @State sortPick: number = -1;
  @State showDelete: boolean = false;
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

  private coverUrl(): string {
    if (this.sheet.coverImg.length > 0) {
      return this.sheet.coverImg;
    }
    if (this.musics.length > 0 && this.musics[0].artwork.length > 0) {
      return this.musics[0].artwork;
    }
    return '';
  }

  private playAll(): void {
    if (this.musics.length === 0) {
      return;
    }
    let start: MusicItem = this.musics[0];
    if (AppService.player.repeatMode === RepeatMode.SHUFFLE) {
      const idx: number = Math.floor(Math.random() * this.musics.length);
      start = this.musics[idx];
    }
    AppService.player.playMusic(start, this.musics);
  }

  private handleMenu(index: number): void {
    if (index === 0) {
      this.renameDraft = this.sheet.title;
      this.showRename = true;
    } else if (index === 1) {
      AppService.openMusicListEditor(this.sheet.title, this.sheet.id, this.musics);
    } else if (index === 2) {
      this.sortPick = -1;
      this.showSort = true;
    } else if (index === 3 && this.sheet.id !== FAVORITE_SHEET_ID) {
      this.showDelete = true;
    }
  }

  private confirmRename(): void {
    const name: string = this.renameDraft.trim();
    if (name.length === 0) {
      return;
    }
    AppService.sheets.renameSheet(this.sheet.id, name);
    this.showRename = false;
  }

  private compareText(left: string, right: string): number {
    return left.localeCompare(right);
  }

  private applySort(mode: number): void {
    if (!this.showSort) {
      return;
    }
    this.sortPick = mode;
    const sorted: MusicItem[] = this.musics.slice();
    if (mode === 0) {
      sorted.sort((a: MusicItem, b: MusicItem) => this.compareText(a.title, b.title));
    } else if (mode === 1) {
      sorted.sort((a: MusicItem, b: MusicItem) => this.compareText(a.artist, b.artist));
    } else if (mode === 2) {
      sorted.sort((a: MusicItem, b: MusicItem) => this.compareText(a.album, b.album));
    } else if (mode === 3) {
      sorted.reverse();
    }
    AppService.sheets.replaceMusics(this.sheet.id, sorted);
    this.musics = AppService.sheets.getMusics(this.sheet.id);
    this.showSort = false;
    showToast(I18n.tx(this.appLocale, 'toast.sortHasBeenUpdated'));
  }

  private confirmDelete(): void {
    const id: string = this.sheet.id;
    this.showDelete = false;
    if (id === FAVORITE_SHEET_ID) {
      return;
    }
    AppService.sheets.removeSheet(id);
    showToast(I18n.tx(this.appLocale, 'toast.deleteSuccess'));
    AppService.pop();
  }

  private sheetBg(): string {
    if (this.backdrop.length > 0) {
      return this.backdrop;
    }
    return this.pageBackground;
  }

  build() {
    Stack() {
      Column() {
        AppNavBar({
          title: I18n.tx(this.appLocale, 'common.sheet'),
          menuTitles: this.sheet.id === FAVORITE_SHEET_ID ? [
            I18n.tx(this.appLocale, 'sheetDetail.editSheetInfo'),
            I18n.tx(this.appLocale, 'sheetDetail.batchEditMusic'),
            I18n.tx(this.appLocale, 'sheetDetail.sortMusic')
          ] : [
            I18n.tx(this.appLocale, 'sheetDetail.editSheetInfo'),
            I18n.tx(this.appLocale, 'sheetDetail.batchEditMusic'),
            I18n.tx(this.appLocale, 'sheetDetail.sortMusic'),
            I18n.tx(this.appLocale, 'sheetDetail.deleteSheet')
          ],
          onBack: () => {
            AppService.pop();
          },
          onMenuAction: (index: number) => {
            this.handleMenu(index);
          }
        }) {
          Row() {
            IconImg({ name: 'magnifying-glass', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openSearchMusicList(this.sheet.title, this.musics);
          })
        }

        Column() {
          Row() {
            if (this.coverUrl().length > 0) {
              Image(this.coverUrl())
                .width(105)
                .height(105)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
                .backgroundColor(this.placeholder)
            } else {
              Image($r('app.media.album_default'))
                .width(105)
                .height(105)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
            }
            Column() {
              Text(this.sheet.title)
                .fontSize(16)
                .fontColor(this.textColor)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(I18n.tx(this.appLocale, 'sheetDetail.totalMusicCount').replace('{count}', `${this.musics.length}`))
                .fontSize(13)
                .fontColor(this.textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.SpaceBetween)
            .layoutWeight(1)
            .height(70)
            .margin({ left: 18 })
          }
          .width('100%')
          .height(150)
          .padding({ left: 12, right: 12 })
          .alignItems(VerticalAlign.Center)

          Row() {
            IconImg({ name: 'play-circle', iconSize: 21, color: this.textColor })
            Text(I18n.tx(this.appLocale, 'playAllBar.title'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .margin({ left: 6 })
          }
          .width('100%')
          .height(42)
          .padding({ left: 12, right: 12 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.playAll();
          })
        }
        .width('100%')
        .backgroundColor(this.card)

        if (this.musics.length === 0) {
          EmptyView({ text: I18n.tx(this.appLocale, 'sheetDetail.empty') })
        } else {
          List() {
            ForEach(this.musics, (item: MusicItem, index: number) => {
              ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                showIndex: true,
                sheetId: this.sheet.id,
                parentHandlesPlay: true,
                onPlay: (m: MusicItem) => {
                  AppService.player.playMusic(m, this.musics);
                }
              })
              }
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
      .bindSheet($$this.showRename, this.renameBuilder(), {
        height: 240,
        showClose: false,
        backgroundColor: this.sheetBg(),
        blurStyle: BlurStyle.NONE,
        maskColor: this.maskColor
      })
      .bindSheet($$this.showSort, this.sortBuilder(), {
        height: 360,
        showClose: false,
        backgroundColor: this.sheetBg(),
        blurStyle: BlurStyle.NONE,
        maskColor: this.maskColor
      })

      if (this.showDelete) {
        this.deleteOverlay()
      }
    }
    .id(`sheet-detail-${this.appLocale}`)
    .width('100%')
    .height('100%')
  }

  @Builder
  overlayHeader(title: string, onClose: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .onClick(onClose)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 8 })
  }

  @Builder
  renameBuilder() {
    Column() {
      this.overlayHeader(I18n.tx(this.appLocale, 'sheetDetail.editSheetInfo'), () => {
        this.showRename = false;
      })
      TextInput({ placeholder: I18n.tx(this.appLocale, 'home.sheetNamePlaceholder'), text: this.renameDraft })
        .fontColor(this.textColor)
        .placeholderColor(this.textSecondary)
        .backgroundColor(this.placeholder)
        .caretColor(this.primary)
        .onChange((v: string) => {
          this.renameDraft = v;
        })
        .margin({ left: 16, right: 16, top: 12 })
      Button(I18n.tx(this.appLocale, 'common.confirm'))
        .width('90%')
        .margin({ top: 16 })
        .backgroundColor(this.primary)
        .fontColor('#FFFEFEFE')
        .onClick(() => {
          this.confirmRename();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetBg())
  }

  @Builder
  sortBuilder() {
    Column() {
      this.overlayHeader(I18n.tx(this.appLocale, 'sheetDetail.sortMusic'), () => {
        this.showSort = false;
      })
      this.sortRow(I18n.tx(this.appLocale, 'sheetDetail.sortMusicOption.byTitle'), 0)
      this.sortRow(I18n.tx(this.appLocale, 'sheetDetail.sortMusicOption.byArtist'), 1)
      this.sortRow(I18n.tx(this.appLocale, 'sheetDetail.sortMusicOption.byAlbum'), 2)
      this.sortRow(I18n.tx(this.appLocale, 'sheetDetail.sortMusicOption.newest'), 3)
      this.sortRow(I18n.tx(this.appLocale, 'sheetDetail.sortMusicOption.oldest'), 4)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetBg())
  }

  @Builder
  sortRow(label: string, mode: number) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.textColor)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Radio({ value: `${mode}`, group: 'sheetMusicSort' })
        .checked(this.sortPick === mode)
        .width(20)
        .height(20)
        .radioStyle({
          checkedBackgroundColor: this.primary
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.applySort(mode);
    })
  }

  @Builder
  deleteOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor)
        .onClick(() => {
          this.showDelete = false;
        })
      Column() {
        Text(I18n.tx(this.appLocale, 'sheetDetail.deleteSheet'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 8 })
        Text(I18n.tx(this.appLocale, 'sheetDetail.deleteSheetContent').replace('{name}', this.sheet.title))
          .fontSize(14)
          .fontColor(this.textColor)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 16 })
        Row() {
          Text(I18n.tx(this.appLocale, 'common.cancel'))
            .fontSize(15)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showDelete = false;
            })
          Text(I18n.tx(this.appLocale, 'common.confirm'))
            .fontSize(15)
            .fontColor(this.primary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.confirmDelete();
            })
        }
        .width('100%')
      }
      .width('80%')
      .borderRadius(12)
      .backgroundColor(this.sheetBg())
    }
    .width('100%')
    .height('100%')
  }
}
