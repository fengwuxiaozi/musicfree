import { MusicItem, SheetItem, AlbumItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { AppConfig, KEYS } from '../core/AppConfig';

@Component
export struct PluginSheetPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @State musics: MusicItem[] = [];
  @State sheet: SheetItem = new SheetItem();
  @State loading: boolean = true;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    if (AppService.params.sheet !== null) {
      this.sheet = AppService.params.sheet;
    }
    this.load();
  }

  async load(): Promise<void> {
    try {
      this.musics = await AppService.plugins.getSheetInfo(this.sheet, 1);
    } catch (_e) {
      this.musics = [];
    }
    this.loading = false;
  }

  build() {
    Column() {
      AppNavBar({
        title: this.sheet.title.length > 0 ? this.sheet.title : I18n.t('sheetDetail.title'),
        onBack: () => {
          AppService.pop();
        }
      })
      Row() {
        Button(I18n.t('playAllBar.title'))
          .backgroundColor(this.primary)
          .fontColor('#FEFEFE')
          .onClick(() => {
            if (this.musics.length > 0) {
              AppService.player.playMusic(this.musics[0], this.musics);
            }
          })
        Button(I18n.t('sheetDetail.starSheet'))
          .margin({ left: 12 })
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .onClick(() => {
            AppService.sheets.starSheet(this.sheet);
          })
      }
      .width('100%')
      .padding({ left: 16, bottom: 8 })

      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 }).color(this.primary)
        Blank()
      } else if (this.musics.length === 0) {
        EmptyView({ text: I18n.t('sheetDetail.pluginEmpty') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({ item: item, index: index })
            }
            .onClick(() => {
              AppService.player.playMusic(item, this.musics);
            })
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
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
}

@Component
export struct AlbumDetailPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @State musics: MusicItem[] = [];
  @State title: string = '';
  @State loading: boolean = true;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    const album = AppService.params.album;
    if (album === null) {
      this.loading = false;
      return;
    }
    this.title = album.title;
    this.load(album);
  }

  async load(album: AlbumItem): Promise<void> {
    try {
      this.musics = await AppService.plugins.getAlbumInfo(album, 1);
    } catch (_e) {
    }
    this.loading = false;
  }

  build() {
    Column() {
      AppNavBar({ title: this.title.length > 0 ? this.title : I18n.t('common.album'), onBack: () => { AppService.pop(); } })
      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 }).color(this.primary)
        Blank()
      } else if (this.musics.length === 0) {
        EmptyView({ text: I18n.t('common.noSongs') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({ item: item, index: index })
            }
            .onClick(() => {
              if (AppConfig.getString(KEYS.CLICK_ALBUM, 'playAlbum') === 'playMusic') {
                AppService.player.playMusic(item);
              } else {
                AppService.player.playMusic(item, this.musics);
              }
            })
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
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
}

@Component
export struct ArtistDetailPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @State musics: MusicItem[] = [];
  @State title: string = '';
  @State loading: boolean = true;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    const artist = AppService.params.artist;
    if (artist === null) {
      this.loading = false;
      return;
    }
    this.title = artist.name;
    this.load();
  }

  async load(): Promise<void> {
    const artist = AppService.params.artist;
    if (artist === null) {
      this.loading = false;
      return;
    }
    try {
      const raw = await AppService.plugins.getArtistWorks(artist, 1, 'music');
      const arr = JSON.parse(raw) as Object[];
      const list: MusicItem[] = [];
      for (let i = 0; i < arr.length; i++) {
        list.push(MusicItem.fromJson(JSON.stringify(arr[i])));
      }
      this.musics = list;
    } catch (_e) {
    }
    this.loading = false;
  }

  build() {
    Column() {
      AppNavBar({ title: this.title.length > 0 ? this.title : I18n.t('common.artist'), onBack: () => { AppService.pop(); } })
      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 }).color(this.primary)
        Blank()
      } else if (this.musics.length === 0) {
        EmptyView({ text: I18n.t('artistDetail.noWorks') })
      } else {
        List() {
          ForEach(this.musics, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({ item: item, index: index })
            }
            .onClick(() => {
              AppService.player.playMusic(item, this.musics);
            })
          }, (item: MusicItem, index: number) => `${item.key()}-${index}`)
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
}
