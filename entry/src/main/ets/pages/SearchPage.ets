import { MusicItem, AlbumItem, ArtistItem, SheetItem, PluginMeta } from '../common/Types';
import { ROUTES } from '../common/Constants';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { AppConfig, KEYS } from '../core/AppConfig';
import { I18n } from '../core/I18n';
import { promptAction } from '@kit.ArkUI';

class SearchBucket {
  hash: string = '';
  platform: string = '';
  page: number = 0;
  ended: boolean = false;
  loaded: boolean = false;
  loading: boolean = false;
  musics: MusicItem[] = [];
  albums: AlbumItem[] = [];
  artists: ArtistItem[] = [];
  sheets: SheetItem[] = [];
}

@Component
export struct SearchPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('textHint') textHint: string = '#99FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('appBar') appBar: string = '#262626';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @State query: string = '';
  @State typeIndex: number = 0;
  @State pluginIndex: number = 0;
  @State pluginNames: string[] = [];
  @State searching: boolean = false;
  @State loadingMore: boolean = false;
  @State searched: boolean = false;
  @State musics: MusicItem[] = [];
  @State albums: AlbumItem[] = [];
  @State artists: ArtistItem[] = [];
  @State sheets: SheetItem[] = [];
  @State history: string[] = [];
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;
  private searchSeq: number = 0;
  private buckets: SearchBucket[] = [];

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
      I18n.tx(this.appLocale, 'common.singleMusic'),
      I18n.tx(this.appLocale, 'common.album'),
      I18n.tx(this.appLocale, 'common.artist'),
      I18n.tx(this.appLocale, 'common.sheet')
    ];
    return labels;
  }

  private currentType(): string {
    return this.types()[this.typeIndex];
  }

  async doSearch(q: string): Promise<void> {
    const text = q.trim();
    if (text.length === 0) {
      return;
    }
    const plugins = AppService.plugins.searchablePlugins(this.currentType());
    if (plugins.length === 0) {
      promptAction.showToast({ message: I18n.tx(this.appLocale, 'toast.noPluginInstalled'), duration: 2500 });
      return;
    }
    AppService.addSearchHistory(text);
    this.history = AppService.searchHistory.slice();
    this.query = text;
    this.searchSeq += 1;
    this.searched = true;
    this.rebuildBuckets(plugins);
    this.pluginIndex = 0;
    this.applyBucket();
    this.searchBucket(0, 1, this.searchSeq);
  }

  private rebuildBuckets(plugins: PluginMeta[]): void {
    const next: SearchBucket[] = [];
    const names: string[] = [];
    for (let i = 0; i < plugins.length; i++) {
      const bucket = new SearchBucket();
      bucket.hash = plugins[i].hash;
      bucket.platform = plugins[i].platform;
      next.push(bucket);
      names.push(plugins[i].platform);
    }
    this.buckets = next;
    this.pluginNames = names;
  }

  private selectPlugin(index: number): void {
    if (index < 0 || index >= this.buckets.length) {
      return;
    }
    this.pluginIndex = index;
    this.applyBucket();
    const bucket = this.buckets[index];
    if (!bucket.loaded && !bucket.loading) {
      this.searchBucket(index, 1, this.searchSeq);
    }
  }

  private loadMore(): void {
    if (this.pluginIndex < 0 || this.pluginIndex >= this.buckets.length) {
      return;
    }
    const bucket = this.buckets[this.pluginIndex];
    if (bucket.loading || bucket.ended || !bucket.loaded) {
      return;
    }
    this.searchBucket(this.pluginIndex, bucket.page + 1, this.searchSeq);
  }

  private searchBucket(index: number, page: number, seq: number): void {
    if (index < 0 || index >= this.buckets.length) {
      return;
    }
    const bucket = this.buckets[index];
    bucket.loading = true;
    if (page === 1) {
      this.searching = index === this.pluginIndex;
    } else if (index === this.pluginIndex) {
      this.loadingMore = true;
    }
    const type = this.currentType();
    AppService.plugins.searchOne(bucket.hash, this.query, page, type).then((raw: string) => {
      if (seq !== this.searchSeq) {
        return;
      }
      this.mergeBucket(bucket, type, raw, page);
      bucket.loading = false;
      if (index === this.pluginIndex) {
        this.searching = false;
        this.loadingMore = false;
        this.applyBucket();
      }
    }).catch((_e: Error) => {
      if (seq !== this.searchSeq) {
        return;
      }
      bucket.loaded = true;
      bucket.ended = true;
      bucket.loading = false;
      if (index === this.pluginIndex) {
        this.searching = false;
        this.loadingMore = false;
        this.applyBucket();
      }
    });
  }

  private mergeBucket(bucket: SearchBucket, type: string, raw: string, page: number): void {
    bucket.page = page;
    bucket.loaded = true;
    if (type === 'music') {
      const extra = this.parseMusics(raw);
      bucket.musics = page === 1 ? extra : bucket.musics.concat(extra);
      bucket.ended = extra.length === 0;
    } else if (type === 'album') {
      const extra = this.parseAlbums(raw);
      bucket.albums = page === 1 ? extra : bucket.albums.concat(extra);
      bucket.ended = extra.length === 0;
    } else if (type === 'artist') {
      const extra = this.parseArtists(raw);
      bucket.artists = page === 1 ? extra : bucket.artists.concat(extra);
      bucket.ended = extra.length === 0;
    } else {
      const extra = this.parseSheets(raw);
      bucket.sheets = page === 1 ? extra : bucket.sheets.concat(extra);
      bucket.ended = extra.length === 0;
    }
  }

  private applyBucket(): void {
    if (this.pluginIndex < 0 || this.pluginIndex >= this.buckets.length) {
      this.musics = [];
      this.albums = [];
      this.artists = [];
      this.sheets = [];
      this.searching = false;
      this.loadingMore = false;
      return;
    }
    const bucket = this.buckets[this.pluginIndex];
    this.musics = bucket.musics.slice();
    this.albums = bucket.albums.slice();
    this.artists = bucket.artists.slice();
    this.sheets = bucket.sheets.slice();
    this.searching = bucket.loading && bucket.page <= 1;
    this.loadingMore = bucket.loading && bucket.page > 1;
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

  private currentEmpty(): boolean {
    if (this.typeIndex === 0) {
      return this.musics.length === 0;
    }
    if (this.typeIndex === 1) {
      return this.albums.length === 0;
    }
    if (this.typeIndex === 2) {
      return this.artists.length === 0;
    }
    return this.sheets.length === 0;
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
          IconImg({ name: 'magnifying-glass', iconSize: 16, color: this.textHint })
          TextInput({ placeholder: I18n.tx(this.appLocale, 'searchPage.searchPlaceHolder'), text: this.query })
            .layoutWeight(1)
            .height(36)
            .backgroundColor('#00000000')
            .fontColor(this.textColor)
            .placeholderColor(this.textHint)
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
              IconImg({ name: 'x-mark', iconSize: 16, color: this.textHint })
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
        Text(I18n.tx(this.appLocale, 'common.search'))
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
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.searched) {
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
        .padding({ left: 16, right: 16, bottom: 4 })

        if (this.pluginNames.length > 0) {
          Scroll() {
            Row() {
              ForEach(this.pluginNames, (name: string, index: number) => {
                Text(name)
                  .fontSize(13)
                  .fontColor(this.pluginIndex === index ? this.primary : this.textSecondary)
                  .fontWeight(this.pluginIndex === index ? FontWeight.Medium : FontWeight.Normal)
                  .padding({ left: 10, right: 10, top: 4, bottom: 6 })
                  .border({
                    width: { bottom: this.pluginIndex === index ? 2 : 0 },
                    color: this.primary
                  })
                  .onClick(() => {
                    this.selectPlugin(index);
                  })
              }, (name: string, index: number) => `${name}-${index}`)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .padding({ left: 6, right: 6, bottom: 6 })
        }
      }

      if (!this.searched) {
        this.historyPanel()
      } else {
        Column() {
          if (this.searching) {
            Row() {
              LoadingProgress().width(16).height(16).color(this.primary)
              Text(I18n.tx(this.appLocale, 'searchPage.searching'))
                .fontColor(this.textSecondary)
                .fontSize(12)
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 16, top: 6, bottom: 6 })
            .justifyContent(FlexAlign.Start)
          }
          this.resultList()
        }
        .layoutWeight(1)
        .width('100%')
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  historyPanel() {
    Column() {
      Row() {
        Text(I18n.tx(this.appLocale, 'searchPage.history'))
          .fontSize(14)
          .fontColor(this.textSecondary)
        Blank()
        Text(I18n.tx(this.appLocale, 'common.clear'))
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
        EmptyView({ text: I18n.tx(this.appLocale, 'searchPage.historyEmpty') })
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
    if (this.currentEmpty()) {
      if (!this.searching) {
        EmptyView({ text: I18n.tx(this.appLocale, 'searchPage.noResult') })
      }
    } else if (this.typeIndex === 0) {
      List() {
        ForEach(this.musics, (item: MusicItem, index: number) => {
          ListItem() {
            MusicItemRow({
              item: item,
              index: index,
              parentHandlesPlay: true,
              onPlay: (m: MusicItem) => {
                this.playSearchMusic(m);
              }
            })
          }
        }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
        if (this.loadingMore) {
          ListItem() {
            Row() {
              LoadingProgress().width(16).height(16).color(this.primary)
              Text(I18n.tx(this.appLocale, 'searchPage.searching'))
                .fontSize(12)
                .fontColor(this.textSecondary)
                .margin({ left: 8 })
            }
            .width('100%')
            .height(48)
            .justifyContent(FlexAlign.Center)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .onReachEnd(() => {
        this.loadMore();
      })
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
    .onReachEnd(() => {
      this.loadMore();
    })
  }

  @Builder
  artistList() {
    List() {
      ForEach(this.artists, (item: ArtistItem) => {
        ListItem() {
          Row() {
            if (item.avatar.length > 0) {
              Image(item.avatar).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
            } else {
              Image($r('app.media.album_default')).width(48).height(48).borderRadius(24)
            }
            Column() {
              Text(item.name.length > 0 ? item.name : I18n.tx(this.appLocale, 'common.unknownArtist'))
                .fontSize(15)
                .fontColor(this.textColor)
              Text(item.platform)
                .fontSize(12)
                .fontColor(this.textSecondary)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
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
    .onReachEnd(() => {
      this.loadMore();
    })
  }

  @Builder
  sheetList() {
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
            AppService.params.sheetKind = 'sheet';
            item.kind = 'sheet';
            AppService.params.sheet = item;
            AppService.push(ROUTES.PLUGIN_SHEET);
          })
        }
      }, (item: SheetItem) => `${item.platform}-${item.id}`)
    }
    .layoutWeight(1)
    .width('100%')
    .onReachEnd(() => {
      this.loadMore();
    })
  }
}
