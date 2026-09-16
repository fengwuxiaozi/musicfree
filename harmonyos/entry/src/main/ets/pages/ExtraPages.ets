import { MusicItem, PluginMeta, SheetItem } from '../common/Types';
import { HISTORY_SHEET_ID, LOCAL_SHEET_ID } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { picker } from '@kit.CoreFileKit';

class TopGroup {
  title: string = '';
  data: SheetItem[] = [];
}

@Component
export struct HistoryPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State list: MusicItem[] = [];

  aboutToAppear(): void {
    this.refreshHistory();
    AppService.history.onChange(() => {
      this.refreshHistory();
    });
  }

  onPageShow(): void {
    this.refreshHistory();
  }

  private refreshHistory(): void {
    this.list = AppService.history.list.slice();
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.t('history.title'), onBack: () => { AppService.pop(); } }) {
        Row() {
          Row() {
            IconImg({ name: 'magnifying-glass', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openSearchMusicList(I18n.t('history.title'), this.list);
          })
          Row() {
            IconImg({ name: 'pencil-outline', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openMusicListEditor(I18n.t('history.title'), HISTORY_SHEET_ID, this.list);
          })
        }
      }
      Row() {
        Text(I18n.t('history.clearHistory'))
          .fontSize(13)
          .fontColor(this.primary)
          .onClick(() => {
            AppService.history.clear();
          })
      }
      .width('100%')
      .padding({ left: 16, bottom: 8 })
      if (this.list.length === 0) {
        EmptyView({ text: I18n.t('history.empty') })
      } else {
        List() {
          ForEach(this.list, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({ item: item, index: index })
            }
            .onClick(() => {
              AppService.player.playMusic(item, this.list);
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
export struct LocalMusicPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State list: MusicItem[] = [];

  aboutToAppear(): void {
    this.refreshLocal();
  }

  onPageShow(): void {
    this.refreshLocal();
  }

  private refreshLocal(): void {
    this.list = AppService.localMusics.slice();
  }

  async pickFiles(): Promise<void> {
    const docPicker = new picker.DocumentViewPicker();
    const uris = await docPicker.select({
      maxSelectNumber: 50,
      fileSuffixFilters: ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg']
    });
    for (let i = 0; i < uris.length; i++) {
      const uri = uris[i];
      AppService.addLocalMusic('', uri);
    }
    this.list = AppService.localMusics.slice();
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.t('home.localMusic'), onBack: () => { AppService.pop(); } }) {
        Row() {
          Row() {
            IconImg({ name: 'magnifying-glass', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openSearchMusicList(I18n.t('home.localMusic'), this.list);
          })
          Row() {
            IconImg({ name: 'pencil-outline', iconSize: 22, color: this.appBarText })
          }
          .width(36)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            AppService.openMusicListEditor(I18n.t('home.localMusic'), LOCAL_SHEET_ID, this.list);
          })
        }
      }
      Row() {
        Button(I18n.t('localMusic.importFiles'))
          .backgroundColor(this.primary)
          .fontColor('#FEFEFE')
          .onClick(() => {
            this.pickFiles();
          })
      }
      .width('100%')
      .padding({ left: 16, bottom: 8 })
      if (this.list.length === 0) {
        EmptyView({ text: I18n.t('localMusic.empty') })
      } else {
        List() {
          ForEach(this.list, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({ item: item, index: index })
            }
            .onClick(() => {
              AppService.player.playMusic(item, this.list);
            })
          }, (item: MusicItem, index: number) => item.id)
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
export struct TopListPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State platforms: PluginMeta[] = [];
  @State current: string = '';
  @State groups: TopGroup[] = [];
  @State loading: boolean = false;

  aboutToAppear(): void {
    this.platforms = AppService.plugins.enabledPlugins().filter((p: PluginMeta) => p.methods.indexOf('getTopLists') >= 0);
    if (this.platforms.length > 0) {
      this.current = this.platforms[0].platform;
      this.load();
    }
  }

  async load(): Promise<void> {
    this.loading = true;
    this.groups = [];
    try {
      const raw = await AppService.plugins.getTopLists(this.current);
      const arr = JSON.parse(raw) as Object[];
      const groups: TopGroup[] = [];
      for (let i = 0; i < arr.length; i++) {
        const obj = arr[i] as Record<string, Object>;
        const g = new TopGroup();
        g.title = obj['title'] ? `${obj['title']}` : '';
        const data = obj['data'] as Object[];
        if (Array.isArray(data)) {
          for (let j = 0; j < data.length; j++) {
            g.data.push(SheetItem.fromJson(JSON.stringify(data[j])));
          }
        }
        groups.push(g);
      }
      this.groups = groups;
    } catch (_e) {
    }
    this.loading = false;
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.t('home.topList'), onBack: () => { AppService.pop(); } })
      if (this.platforms.length === 0) {
        EmptyView({ text: I18n.t('topList.unsupported') })
      } else {
        Scroll() {
          Row() {
            ForEach(this.platforms, (p: PluginMeta) => {
              Text(p.platform)
                .fontSize(13)
                .fontColor(this.current === p.platform ? this.primary : this.textSecondary)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.current = p.platform;
                  this.load();
                })
            }, (p: PluginMeta) => p.hash)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .height(40)
        .width('100%')

        if (this.loading) {
          LoadingProgress().width(36).height(36).margin({ top: 40 }).color(this.primary)
          Blank()
        } else if (this.groups.length === 0) {
          EmptyView({ text: I18n.t('topList.empty') })
        } else {
          List() {
            ForEach(this.groups, (g: TopGroup) => {
              ListItemGroup({ header: this.groupHeader(g.title) }) {
                ForEach(g.data, (sheet: SheetItem) => {
                  ListItem() {
                    Text(sheet.title)
                      .fontSize(15)
                      .fontColor(this.textColor)
                      .padding(14)
                      .width('100%')
                      .onClick(() => {
                        AppService.params.sheet = sheet;
                        AppService.push('plugin-sheet-detail');
                      })
                  }
                }, (sheet: SheetItem) => `${sheet.platform}-${sheet.id}`)
              }
            }, (g: TopGroup) => g.title)
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  groupHeader(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.textColor)
      .padding({ left: 16, top: 12, bottom: 8 })
  }
}

@Component
export struct RecommendPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State platforms: PluginMeta[] = [];
  @State current: string = '';
  @State sheets: SheetItem[] = [];
  @State loading: boolean = false;

  aboutToAppear(): void {
    this.platforms = AppService.plugins.enabledPlugins().filter((p: PluginMeta) => p.methods.indexOf('getRecommendSheetsByTag') >= 0);
    if (this.platforms.length > 0) {
      this.current = this.platforms[0].platform;
      this.load();
    }
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      this.sheets = await AppService.plugins.getRecommendSheets(this.current, JSON.stringify({ 'id': '', 'title': I18n.t('home.recommendSheet') }), 1);
    } catch (_e) {
      this.sheets = [];
    }
    this.loading = false;
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.t('home.recommendSheet'), onBack: () => { AppService.pop(); } })
      if (this.platforms.length === 0) {
        EmptyView({ text: I18n.t('recommendSheet.unsupported') })
      } else {
        Scroll() {
          Row() {
            ForEach(this.platforms, (p: PluginMeta) => {
              Text(p.platform)
                .fontSize(13)
                .fontColor(this.current === p.platform ? this.primary : this.textSecondary)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.current = p.platform;
                  this.load();
                })
            }, (p: PluginMeta) => p.hash)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .height(40)

        if (this.loading) {
          LoadingProgress().width(36).height(36).margin({ top: 40 }).color(this.primary)
          Blank()
        } else if (this.sheets.length === 0) {
          EmptyView({ text: I18n.t('recommendSheet.empty') })
        } else {
          List() {
            ForEach(this.sheets, (sheet: SheetItem) => {
              ListItem() {
                Row() {
                  if (sheet.coverImg.length > 0) {
                    Image(sheet.coverImg).width(56).height(56).borderRadius(6).objectFit(ImageFit.Cover)
                  } else {
                    Image($r('app.media.album_default')).width(56).height(56).borderRadius(6)
                  }
                  Column() {
                    Text(sheet.title).fontSize(15).fontColor(this.textColor).maxLines(1)
                    Text(sheet.artist).fontSize(12).fontColor(this.textSecondary).margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 12 })
                }
                .padding(12)
                .width('100%')
                .onClick(() => {
                  AppService.params.sheet = sheet;
                  AppService.push('plugin-sheet-detail');
                })
              }
            }, (sheet: SheetItem) => `${sheet.platform}-${sheet.id}`)
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}
