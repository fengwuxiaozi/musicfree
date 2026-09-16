import { MusicItem, AlbumItem, ArtistItem, SheetItem } from '../common/Types';
import { ROUTES } from '../common/Constants';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { AppConfig, KEYS } from '../core/AppConfig';
import { I18n } from '../core/I18n';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SearchPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('appBar') appBar: string = '#262626';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @State query: string = '';
  @State typeIndex: number = 0;
  @State searching: boolean = false;
  @State searched: boolean = false;
  @State musics: MusicItem[] = [];
  @State albums: AlbumItem[] = [];
  @State artists: ArtistItem[] = [];
  @State sheets: SheetItem[] = [];
  @State history: string[] = [];
  @State showMore: boolean = false;
  @State moreItem: MusicItem = new MusicItem();
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;

  aboutToAppear(): void {
    this.history = AppService.searchHistory.slice();
    AppService.theme.setAppBarStatusIcons(true);
  }

  aboutToDisappear(): void {
    AppService.theme.setAppBarStatusIcons(false);
  }

  private types(): string[] {
    return ['music', 'album', 'artist', 'sheet'];
  }

  private typeLabels(): string[] {
    const labels: string[] = [
      I18n.t('common.singleMusic'),
      I18n.t('common.album'),
      I18n.t('common.artist'),
      I18n.t('common.sheet')
    ];
    return labels;
  }

  async doSearch(q: string): Promise<void> {
    const text = q.trim();
    if (text.length === 0) {
      return;
    }
    if (AppService.plugins.enabledPlugins().length === 0) {
      promptAction.showToast({ message: I18n.t('toast.noPluginInstalled'), duration: 2500 });
      return;
    }
    AppService.addSearchHistory(text);
    this.history = AppService.searchHistory.slice();
    this.query = text;
    this.searching = true;
    this.searched = true;
    const type = this.types()[this.typeIndex];
    try {
      const raw = await AppService.plugins.search(text, 1, type);
      if (type === 'music') {
        this.musics = JSON.parse(raw) as Object[] ? this.parseMusics(raw) : [];
        this.albums = [];
        this.artists = [];
        this.sheets = [];
      } else if (type === 'album') {
        this.albums = this.parseAlbums(raw);
        this.musics = [];
      } else if (type === 'artist') {
        this.artists = this.parseArtists(raw);
        this.musics = [];
      } else {
        this.sheets = this.parseSheets(raw);
        this.musics = [];
      }
    } catch (_e) {
      promptAction.showToast({ message: I18n.t('searchPage.fail'), duration: 2000 });
    }
    this.searching = false;
  }

  private parseMusics(raw: string): MusicItem[] {
    const list: MusicItem[] = [];
    try {
      const arr = JSON.parse(raw) as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.push(MusicItem.fromJson(JSON.stringify(arr[i])));
      }
    } catch (_e) {
    }
    return list;
  }

  private parseAlbums(raw: string): AlbumItem[] {
    const list: AlbumItem[] = [];
    try {
      const arr = JSON.parse(raw) as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.push(AlbumItem.fromJson(JSON.stringify(arr[i])));
      }
    } catch (_e) {
    }
    return list;
  }

  private parseArtists(raw: string): ArtistItem[] {
    const list: ArtistItem[] = [];
    try {
      const arr = JSON.parse(raw) as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.push(ArtistItem.fromJson(JSON.stringify(arr[i])));
      }
    } catch (_e) {
    }
    return list;
  }

  private parseSheets(raw: string): SheetItem[] {
    const list: SheetItem[] = [];
    try {
      const arr = JSON.parse(raw) as Object[];
      for (let i = 0; i < arr.length; i++) {
        list.push(SheetItem.fromJson(JSON.stringify(arr[i])));
      }
    } catch (_e) {
    }
    return list;
  }

  private playSearchMusic(item: MusicItem): void {
    if (AppConfig.getString(KEYS.CLICK_SEARCH, 'playMusic') === 'playMusicAndReplace') {
      AppService.player.playMusic(item, this.musics);
    } else {
      AppService.player.playMusic(item);
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          IconImg({ name: 'arrow-left', iconSize: 22, color: this.appBarText })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          AppService.pop();
        })
        Row() {
          IconImg({ name: 'magnifying-glass', iconSize: 16, color: this.textSecondary })
          TextInput({ placeholder: I18n.t('searchPage.searchPlaceHolder'), text: this.query })
            .layoutWeight(1)
            .height(36)
            .backgroundColor('#00000000')
            .fontColor(this.textColor)
            .placeholderColor(this.textSecondary)
            .padding({ left: 4, right: 4 })
            .onChange((v: string) => {
              this.query = v;
              if (v.length === 0) {
                this.searched = false;
              }
            })
            .onSubmit(() => {
              this.doSearch(this.query);
            })
          if (this.query.length > 0) {
            Row() {
              IconImg({ name: 'x-mark', iconSize: 16, color: this.textSecondary })
            }
            .width(24)
            .height(24)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.query = '';
              this.searched = false;
            })
          }
        }
        .layoutWeight(1)
        .height(36)
        .padding({ left: 10, right: 10 })
        .borderRadius(18)
        .backgroundColor(this.pageBackground)
        Text(I18n.t('common.search'))
          .fontColor(this.appBarText)
          .fontSize(15)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.doSearch(this.query);
          })
      }
      .width('100%')
      .height(48 + this.statusBarHeight)
      .padding({ top: this.statusBarHeight, right: 4 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.appBar)

      Row() {
        ForEach(this.typeLabels(), (label: string, index: number) => {
          Text(label)
            .fontSize(14)
            .fontColor(this.typeIndex === index ? this.primary : this.textSecondary)
            .fontWeight(this.typeIndex === index ? FontWeight.Bold : FontWeight.Normal)
            .margin({ right: 20 })
            .padding({ bottom: 6 })
            .border({
              width: { bottom: this.typeIndex === index ? 2 : 0 },
              color: this.primary
            })
            .onClick(() => {
              this.typeIndex = index;
              if (this.searched && this.query.length > 0) {
                this.doSearch(this.query);
              }
            })
        }, (label: string, index: number) => `${label}-${index}`)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (!this.searched) {
        this.historyPanel()
      } else if (this.searching) {
        Column() {
          LoadingProgress().width(40).height(40).color(this.primary).margin({ top: 80 })
          Text(I18n.t('searchPage.searching')).fontColor(this.textSecondary).margin({ top: 12 })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        this.resultList()
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
    .bindSheet($$this.showMore, this.moreBuilder(), {
      height: 340,
      showClose: false,
      backgroundColor: this.backdrop.length > 0 ? this.backdrop : this.pageBackground,
      maskColor: this.maskColor
    })
  }

  @Builder
  historyPanel() {
    Column() {
      Row() {
        Text(I18n.t('searchPage.history'))
          .fontSize(14)
          .fontColor(this.textSecondary)
        Blank()
        Text(I18n.t('common.clear'))
          .fontSize(13)
          .fontColor(this.primary)
          .onClick(() => {
            AppService.clearSearchHistory();
            this.history = [];
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (this.history.length === 0) {
        EmptyView({ text: I18n.t('searchPage.historyEmpty') })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.history, (q: string) => {
            Row() {
              Text(q)
                .fontSize(13)
                .fontColor(this.textColor)
                .onClick(() => {
                  this.doSearch(q);
                })
              Text('×')
                .fontSize(14)
                .fontColor(this.textSecondary)
                .margin({ left: 8 })
                .onClick(() => {
                  AppService.removeSearchHistory(q);
                  this.history = AppService.searchHistory.slice();
                })
            }
            .backgroundColor(this.placeholder)
            .padding({ left: 12, right: 10, top: 6, bottom: 6 })
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
          }, (q: string) => q)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  resultList() {
    if (this.typeIndex === 0) {
      if (this.musics.length === 0) {
        EmptyView({ text: I18n.t('searchPage.noResult') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                parentHandlesMore: true,
                parentHandlesPlay: true,
                onMore: (m: MusicItem) => {
                  this.moreItem = m;
                  this.showMore = true;
                },
                onPlay: (m: MusicItem) => {
                  this.playSearchMusic(m);
                }
              })
            }
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    } else if (this.typeIndex === 1) {
      this.albumList()
    } else if (this.typeIndex === 2) {
      this.artistList()
    } else {
      this.sheetList()
    }
  }

  @Builder
  albumList() {
    if (this.albums.length === 0) {
      EmptyView({ text: I18n.t('searchPage.noResult') })
    } else {
      List() {
        ForEach(this.albums, (item: AlbumItem) => {
          ListItem() {
            Row() {
              if (item.artwork.length > 0) {
                Image(item.artwork).width(48).height(48).borderRadius(6).objectFit(ImageFit.Cover)
              } else {
                Image($r('app.media.album_default')).width(48).height(48).borderRadius(6)
              }
              Column() {
                Text(item.title).fontSize(15).fontColor(this.textColor).maxLines(1)
                Text(`${item.artist}  ·  ${item.platform}`).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })
            }
            .padding(12)
            .width('100%')
            .onClick(() => {
              AppService.params.album = item;
              AppService.push(ROUTES.ALBUM);
            })
          }
        }, (item: AlbumItem) => `${item.platform}-${item.id}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  artistList() {
    if (this.artists.length === 0) {
      EmptyView({ text: I18n.t('searchPage.noResult') })
    } else {
      List() {
        ForEach(this.artists, (item: ArtistItem) => {
          ListItem() {
            Row() {
              if (item.avatar.length > 0) {
                Image(item.avatar).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
              } else {
                Image($r('app.media.album_default')).width(48).height(48).borderRadius(24)
              }
              Text(item.name.length > 0 ? item.name : I18n.t('common.unknownArtist'))
                .fontSize(15)
                .fontColor(this.textColor)
                .margin({ left: 12 })
            }
            .padding(12)
            .width('100%')
            .onClick(() => {
              AppService.params.artist = item;
              AppService.push(ROUTES.ARTIST);
            })
          }
        }, (item: ArtistItem) => `${item.platform}-${item.id}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder
  sheetList() {
    if (this.sheets.length === 0) {
      EmptyView({ text: I18n.t('searchPage.noResult') })
    } else {
      List() {
        ForEach(this.sheets, (item: SheetItem) => {
          ListItem() {
            Row() {
              if (item.coverImg.length > 0) {
                Image(item.coverImg).width(48).height(48).borderRadius(6).objectFit(ImageFit.Cover)
              } else {
                Image($r('app.media.album_default')).width(48).height(48).borderRadius(6)
              }
              Column() {
                Text(item.title).fontSize(15).fontColor(this.textColor).maxLines(1)
                Text(item.platform).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })
            }
            .padding(12)
            .width('100%')
            .onClick(() => {
              AppService.params.sheet = item;
              AppService.push(ROUTES.PLUGIN_SHEET);
            })
          }
        }, (item: SheetItem) => `${item.platform}-${item.id}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
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
        this.moreRow('play', I18n.t('common.play'), () => {
          this.playSearchMusic(this.moreItem);
          this.showMore = false;
        })
        this.moreRow('motion-play', I18n.t('musicListEditor.addToNextPlay'), () => {
          AppService.player.addNext(this.moreItem);
          this.showMore = false;
        })
        this.moreRow('heart-outline', I18n.t('common.addToFavorite'), () => {
          AppService.sheets.toggleFavorite(this.moreItem);
          this.showMore = false;
        })
        this.moreRow('arrow-down-tray', I18n.t('common.download'), () => {
          AppService.downloader.download(this.moreItem);
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
