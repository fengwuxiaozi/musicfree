import { MusicItem, SheetItem, SheetPageResult, AlbumItem, ArtistItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { AppConfig, KEYS } from '../core/AppConfig';
import { ROUTES } from '../common/Constants';

@Component
export struct PluginSheetPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @State musics: MusicItem[] = [];
  @State sheet: SheetItem = new SheetItem();
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State starred: boolean = false;
  @State descExpanded: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  private page: number = 1;
  private ended: boolean = false;
  private lastKind: string = '';
  private loadGen: number = 0;

  aboutToAppear(): void {
    this.reloadFromParams(true);
    AppService.sheets.onChange(() => {
      this.syncStarred();
    });
  }

  onPageShow(): void {
    this.reloadFromParams(false);
  }

  private reloadFromParams(force: boolean): void {
    if (AppService.params.sheet === null) {
      if (force) {
        this.loading = false;
      }
      return;
    }
    const next = AppService.params.sheet;
    const kind = AppService.params.sheetKind;
    if (!force && next.id === this.sheet.id && next.platform === this.sheet.platform &&
      kind === this.lastKind && (this.musics.length > 0 || this.loading)) {
      return;
    }
    this.sheet = next;
    this.lastKind = kind;
    this.syncStarred();
    this.page = 1;
    this.ended = false;
    this.musics = [];
    this.loading = true;
    this.loadingMore = false;
    this.load(true);
  }

  async load(reset: boolean): Promise<void> {
    if (!reset && (this.ended || this.loadingMore || this.loading)) {
      return;
    }
    const gen = this.loadGen + 1;
    this.loadGen = gen;
    if (reset) {
      this.page = 1;
      this.ended = false;
      this.loading = true;
      this.loadingMore = false;
    } else {
      this.page += 1;
      this.loadingMore = true;
    }
    const page = this.page;
    try {
      const result: SheetPageResult = await AppService.plugins.getSheetInfo(this.sheet, page, AppService.params.sheetKind);
      if (gen !== this.loadGen) {
        return;
      }
      this.applySheetMeta(result);
      this.ended = result.isEnd || result.musics.length === 0;
      if (reset) {
        this.musics = result.musics;
      } else if (result.musics.length > 0) {
        this.musics = this.musics.concat(result.musics);
      }
    } catch (_e) {
      if (gen !== this.loadGen) {
        return;
      }
      if (reset) {
        this.musics = [];
      }
      this.ended = true;
    }
    if (gen === this.loadGen) {
      this.loading = false;
      this.loadingMore = false;
    }
  }

  private applySheetMeta(result: SheetPageResult): void {
    if (result.title.length === 0 && result.coverImg.length === 0 &&
      result.description.length === 0 && result.worksNum <= 0) {
      return;
    }
    const next = new SheetItem();
    next.id = this.sheet.id;
    next.platform = this.sheet.platform;
    next.title = result.title.length > 0 ? result.title : this.sheet.title;
    next.artist = this.sheet.artist;
    next.coverImg = result.coverImg.length > 0 ? result.coverImg : this.sheet.coverImg;
    next.worksNum = result.worksNum > 0 ? result.worksNum : this.sheet.worksNum;
    next.description = result.description.length > 0 ? result.description : this.sheet.description;
    next.kind = this.sheet.kind.length > 0 ? this.sheet.kind : this.lastKind;
    next.rawJson = this.sheet.rawJson;
    this.sheet = next;
  }

  private musicCount(): number {
    if (this.sheet.worksNum > 0) {
      return this.sheet.worksNum;
    }
    return this.musics.length;
  }

  private sheetIsStarred(): boolean {
    const starredSheets: SheetItem[] = AppService.sheets.starred;
    for (let i = 0; i < starredSheets.length; i++) {
      const item: SheetItem = starredSheets[i];
      if (item.id === this.sheet.id && item.platform === this.sheet.platform) {
        return true;
      }
    }
    return false;
  }

  private syncStarred(): void {
    this.starred = this.sheetIsStarred();
  }

  private toggleStar(): void {
    this.sheet.kind = this.lastKind.length > 0 ? this.lastKind : AppService.params.sheetKind;
    if (this.sheetIsStarred()) {
      AppService.sheets.unstarSheet(this.sheet);
    } else {
      AppService.sheets.starSheet(this.sheet);
    }
    this.syncStarred();
  }

  private playAll(): void {
    if (this.musics.length > 0) {
      AppService.player.playMusic(this.musics[0], this.musics);
    }
  }

  build() {
    Column() {
      AppNavBar({
        title: this.sheet.title.length > 0 ? this.sheet.title : I18n.tx(this.appLocale, 'sheetDetail.title'),
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
            IconImg({ name: 'pencil-square', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openMusicListEditor(this.sheet.title, this.sheet.id, this.musics);
          })
        }
      }

      Column() {
        Row() {
          if (this.sheet.coverImg.length > 0) {
            Image(this.sheet.coverImg)
              .width(72)
              .height(72)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
              .backgroundColor(this.placeholder)
          } else {
            Image($r('app.media.album_default'))
              .width(72)
              .height(72)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
          }
          Column() {
            Text(this.sheet.title.length > 0 ? this.sheet.title : I18n.tx(this.appLocale, 'sheetDetail.title'))
              .fontSize(16)
              .fontColor(this.textColor)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(I18n.tx(this.appLocale, 'sheetDetail.totalMusicCount').replace('{count}', `${this.musicCount()}`))
              .fontSize(12)
              .fontColor(this.textSecondary)
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.sheet.description.length > 0) {
          Text(this.sheet.description)
            .fontSize(12)
            .fontColor(this.textSecondary)
            .margin({ top: 10 })
            .maxLines(this.descExpanded ? 99 : 6)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.descExpanded = !this.descExpanded;
            })
        }

        Row() {
          Row() {
            IconImg({ name: 'play-circle', iconSize: 21, color: this.textColor })
              .margin({ right: 6 })
            Text(I18n.tx(this.appLocale, 'playAllBar.title'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.playAll();
          })
          Row() {
            IconImg({
              name: this.starred ? 'heart' : 'heart-outline',
              iconSize: 21,
              color: this.starred ? '#e31639' : this.textColor
            })
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.toggleStar();
          })
        }
        .width('100%')
        .height(40)
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 4 })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.card)

      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 }).color(this.primary)
        Blank()
      } else if (this.musics.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'sheetDetail.pluginEmpty') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                showIndex: true,
                parentHandlesPlay: true,
                onPlay: (m: MusicItem) => {
                  AppService.player.playMusic(m, this.musics);
                }
              })
            }
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
          if (this.loadingMore) {
            ListItem() {
              Row() {
                LoadingProgress().width(24).height(24).color(this.primary)
              }
              .width('100%')
              .height(48)
              .justifyContent(FlexAlign.Center)
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .onReachEnd(() => {
          this.load(false);
        })
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}

@Component
export struct AlbumDetailPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('card') card: string = '#88333333';
  @State musics: MusicItem[] = [];
  @State album: AlbumItem = new AlbumItem();
  @State title: string = '';
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  private page: number = 1;
  private ended: boolean = false;

  aboutToAppear(): void {
    const album = AppService.params.album;
    if (album === null) {
      this.loading = false;
      return;
    }
    this.album = album;
    this.title = album.title;
    this.load(true);
  }

  async load(reset: boolean): Promise<void> {
    if (!reset && (this.ended || this.loadingMore || this.loading)) {
      return;
    }
    if (reset) {
      this.page = 1;
      this.ended = false;
      this.loading = true;
    } else {
      this.page += 1;
      this.loadingMore = true;
    }
    try {
      const extra = await AppService.plugins.getAlbumInfo(this.album, this.page);
      this.ended = extra.length === 0;
      if (reset) {
        this.musics = extra;
      } else if (extra.length > 0) {
        this.musics = this.musics.concat(extra);
      }
    } catch (_e) {
      this.ended = true;
    }
    this.loading = false;
    this.loadingMore = false;
  }

  private playAll(): void {
    if (this.musics.length > 0) {
      AppService.player.playMusic(this.musics[0], this.musics);
    }
  }

  build() {
    Column() {
      AppNavBar({ title: this.title.length > 0 ? this.title : I18n.tx(this.appLocale, 'common.album'), onBack: () => { AppService.pop(); } })
      Column() {
        if (this.album.artwork.length > 0) {
          Row() {
            Image(this.album.artwork)
              .width(72)
              .height(72)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
              .backgroundColor(this.placeholder)
            Column() {
              Text(this.album.title.length > 0 ? this.album.title : I18n.tx(this.appLocale, 'common.album'))
                .fontSize(16)
                .fontColor(this.textColor)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(I18n.tx(this.appLocale, 'sheetDetail.totalMusicCount').replace('{count}', `${this.musics.length}`))
                .fontSize(12)
                .fontColor(this.textSecondary)
                .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 8 })
        }
        Row() {
          IconImg({ name: 'play-circle', iconSize: 21, color: this.textColor })
            .margin({ right: 6 })
          Text(I18n.tx(this.appLocale, 'playAllBar.title'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
        }
        .width('100%')
        .height(40)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.playAll();
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 4 })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.card)

      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 }).color(this.primary)
        Blank()
      } else if (this.musics.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'common.noSongs') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                showIndex: true,
                parentHandlesPlay: true,
                onPlay: (m: MusicItem) => {
                  if (AppConfig.getString(KEYS.CLICK_ALBUM, 'playAlbum') === 'playMusic') {
                    AppService.player.playMusic(m);
                  } else {
                    AppService.player.playMusic(m, this.musics);
                  }
                }
              })
            }
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
        }
        .layoutWeight(1)
        .width('100%')
        .onReachEnd(() => {
          this.load(false);
        })
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}

@Component
export struct ArtistDetailPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @State musics: MusicItem[] = [];
  @State albums: AlbumItem[] = [];
  @State title: string = '';
  @State tab: string = 'music';
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  private artist: ArtistItem = new ArtistItem();
  private musicPage: number = 1;
  private albumPage: number = 1;
  private musicEnd: boolean = false;
  private albumEnd: boolean = false;

  aboutToAppear(): void {
    const artist = AppService.params.artist;
    if (artist === null) {
      this.loading = false;
      return;
    }
    this.artist = artist;
    this.title = artist.name;
    this.load(true);
  }

  private switchTab(next: string): void {
    if (this.tab === next) {
      return;
    }
    this.tab = next;
    if (next === 'music' && this.musics.length === 0 && !this.musicEnd) {
      this.load(true);
    } else if (next === 'album' && this.albums.length === 0 && !this.albumEnd) {
      this.load(true);
    }
  }

  async load(reset: boolean): Promise<void> {
    if (this.artist.id.length === 0 && this.artist.name.length === 0) {
      this.loading = false;
      return;
    }
    const isMusic = this.tab === 'music';
    if (!reset && ((isMusic && (this.musicEnd || this.loadingMore)) || (!isMusic && (this.albumEnd || this.loadingMore)))) {
      return;
    }
    if (reset) {
      this.loading = true;
      if (isMusic) {
        this.musicPage = 1;
        this.musicEnd = false;
      } else {
        this.albumPage = 1;
        this.albumEnd = false;
      }
    } else {
      this.loadingMore = true;
      if (isMusic) {
        this.musicPage += 1;
      } else {
        this.albumPage += 1;
      }
    }
    const page = isMusic ? this.musicPage : this.albumPage;
    const type = isMusic ? 'music' : 'album';
    try {
      const raw = await AppService.plugins.getArtistWorks(this.artist, page, type);
      if (isMusic) {
        const extra = this.parseMusics(raw);
        this.musicEnd = extra.length === 0;
        this.musics = reset ? extra : this.musics.concat(extra);
      } else {
        const extra = this.parseAlbums(raw);
        this.albumEnd = extra.length === 0;
        this.albums = reset ? extra : this.albums.concat(extra);
      }
    } catch (_e) {
      if (isMusic) {
        this.musicEnd = true;
      } else {
        this.albumEnd = true;
      }
    }
    this.loading = false;
    this.loadingMore = false;
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

  build() {
    Column() {
      AppNavBar({ title: this.title.length > 0 ? this.title : I18n.tx(this.appLocale, 'common.artist'), onBack: () => { AppService.pop(); } })
      Row() {
        Text(I18n.tx(this.appLocale, 'common.singleMusic'))
          .fontSize(14)
          .fontColor(this.tab === 'music' ? this.primary : this.textSecondary)
          .fontWeight(this.tab === 'music' ? FontWeight.Bold : FontWeight.Normal)
          .padding({ bottom: 6 })
          .margin({ right: 24 })
          .border({ width: { bottom: this.tab === 'music' ? 2 : 0 }, color: this.primary })
          .onClick(() => {
            this.switchTab('music');
          })
        Text(I18n.tx(this.appLocale, 'common.album'))
          .fontSize(14)
          .fontColor(this.tab === 'album' ? this.primary : this.textSecondary)
          .fontWeight(this.tab === 'album' ? FontWeight.Bold : FontWeight.Normal)
          .padding({ bottom: 6 })
          .border({ width: { bottom: this.tab === 'album' ? 2 : 0 }, color: this.primary })
          .onClick(() => {
            this.switchTab('album');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 }).color(this.primary)
        Blank()
      } else if (this.tab === 'music' && this.musics.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'artistDetail.noWorks') })
      } else if (this.tab === 'album' && this.albums.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'artistDetail.noWorks') })
      } else if (this.tab === 'music') {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                showIndex: true,
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
        .onReachEnd(() => {
          this.load(false);
        })
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
                  Text(item.artist).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
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
          this.load(false);
        })
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}
