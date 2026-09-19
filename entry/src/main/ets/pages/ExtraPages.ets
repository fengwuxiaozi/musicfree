import {
  MusicItem,
  PluginMeta,
  SheetItem,
  RecommendTag,
  RecommendTagGroup
} from '../common/Types';
import { HISTORY_SHEET_ID, LOCAL_SHEET_ID, ROUTES } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { showToast } from '../core/HttpUtil';
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
      AppNavBar({
        title: I18n.tx(this.appLocale, 'history.title'),
        menuTitles: [
          I18n.tx(this.appLocale, 'history.clearHistory'),
          I18n.tx(this.appLocale, 'common.edit')
        ],
        onBack: () => {
          AppService.pop();
        },
        onMenuAction: (index: number) => {
          if (index === 0) {
            AppService.history.clear();
          } else if (index === 1) {
            AppService.openMusicListEditor(I18n.tx(this.appLocale, 'history.title'), HISTORY_SHEET_ID, this.list);
          }
        }
      })
      if (this.list.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'history.empty') })
      } else {
        List() {
          ForEach(this.list, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                showIndex: true,
                sheetId: HISTORY_SHEET_ID,
                parentHandlesPlay: true,
                onPlay: (m: MusicItem) => {
                  AppService.player.playMusic(m, this.list);
                }
              })
            }
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
  @StorageLink('localMusicTick') @Watch('onLocalTick') localMusicTick: number = 0;
  @State list: MusicItem[] = [];

  aboutToAppear(): void {
    this.refreshLocal();
  }

  onPageShow(): void {
    this.refreshLocal();
  }

  onLocalTick(): void {
    this.refreshLocal();
  }

  private refreshLocal(): void {
    this.list = AppService.localMusics.slice();
  }

  async pickFiles(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const uris = await docPicker.select({
        maxSelectNumber: 50,
        fileSuffixFilters: ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg']
      });
      let ok = 0;
      for (let i = 0; i < uris.length; i++) {
        if (await AppService.addLocalMusic('', uris[i])) {
          ok += 1;
        }
      }
      this.list = AppService.localMusics.slice();
      if (ok > 0) {
        showToast(I18n.tx(this.appLocale, 'toast.localImported').replace('{count}', `${ok}`));
      } else if (uris.length > 0) {
        showToast(I18n.tx(this.appLocale, 'toast.localImportFail'));
      }
    } catch (_e) {
    }
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.tx(this.appLocale, 'home.localMusic'),
        menuTitles: [
          I18n.tx(this.appLocale, 'localMusic.scanLocalMusic'),
          I18n.tx(this.appLocale, 'common.batchEdit'),
          I18n.tx(this.appLocale, 'localMusic.downloadList')
        ],
        onBack: () => {
          AppService.pop();
        },
        onMenuAction: (index: number) => {
          if (index === 0) {
            this.pickFiles();
          } else if (index === 1) {
            AppService.openMusicListEditor(I18n.tx(this.appLocale, 'home.localMusic'), LOCAL_SHEET_ID, this.list);
          } else if (index === 2) {
            AppService.push(ROUTES.DOWNLOADING);
          }
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
            AppService.openSearchMusicList(I18n.tx(this.appLocale, 'home.localMusic'), this.list);
          })
        }
      }
      if (this.list.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'localMusic.empty') })
      } else {
        List() {
          ForEach(this.list, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({
                item: item,
                index: index,
                showIndex: true,
                sheetId: LOCAL_SHEET_ID,
                parentHandlesPlay: true,
                onPlay: (m: MusicItem) => {
                  AppService.player.playMusic(m, this.list);
                }
              })
            }
          }, (item: MusicItem, index: number) => `${item.key()}-${index}-${this.localMusicTick}`)
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
  private loadGen: number = 0;

  aboutToAppear(): void {
    this.platforms = AppService.plugins.enabledPlugins().filter((p: PluginMeta) => p.methods.indexOf('getTopLists') >= 0);
    if (this.platforms.length > 0) {
      this.current = this.platforms[0].platform;
      this.load();
    }
  }

  async load(): Promise<void> {
    const gen = this.loadGen + 1;
    this.loadGen = gen;
    const platform = this.current;
    this.loading = true;
    this.groups = [];
    try {
      const raw = await AppService.plugins.getTopLists(platform);
      if (gen !== this.loadGen) {
        return;
      }
      const arr = JSON.parse(raw) as Object[];
      const groups: TopGroup[] = [];
      for (let i = 0; i < arr.length; i++) {
        const obj = arr[i] as Record<string, Object>;
        const g = new TopGroup();
        g.title = obj['title'] ? `${obj['title']}` : '';
        const data = obj['data'] as Object[];
        if (Array.isArray(data)) {
          for (let j = 0; j < data.length; j++) {
            const item = SheetItem.fromJson(JSON.stringify(data[j]));
            if (item.platform.length === 0) {
              item.platform = platform;
            }
            item.kind = 'topList';
            item.rawJson = item.toPluginJson();
            g.data.push(item);
          }
        }
        groups.push(g);
      }
      this.groups = groups;
    } catch (_e) {
      if (gen !== this.loadGen) {
        return;
      }
    }
    if (gen === this.loadGen) {
      this.loading = false;
    }
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.tx(this.appLocale, 'topList.title'), onBack: () => { AppService.pop(); } })
      if (this.platforms.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'topList.unsupported') })
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
          EmptyView({ text: I18n.tx(this.appLocale, 'topList.empty') })
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
                        if (sheet.platform.length === 0) {
                          sheet.platform = this.current;
                        }
                        sheet.kind = 'topList';
                        AppService.params.sheetKind = 'topList';
                        AppService.params.sheet = sheet;
                        AppService.push(ROUTES.PLUGIN_SHEET);
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
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('card') card: string = '#88333333';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State platforms: PluginMeta[] = [];
  @State current: string = '';
  @State sheets: SheetItem[] = [];
  @State pinned: RecommendTag[] = [];
  @State tagGroups: RecommendTagGroup[] = [];
  @State selectedTag: RecommendTag = new RecommendTag();
  @State firstTag: RecommendTag = new RecommendTag();
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State showTagSheet: boolean = false;
  private page: number = 1;
  private sheetsEnd: boolean = false;
  private lastPageSize: number = 0;
  private requestGen: number = 0;
  private tagGen: number = 0;

  aboutToAppear(): void {
    this.selectedTag = this.makeDefaultTag();
    this.firstTag = this.makeDefaultTag();
    this.platforms = AppService.plugins.enabledPlugins().filter((p: PluginMeta) => p.methods.indexOf('getRecommendSheetsByTag') >= 0);
    if (this.platforms.length > 0) {
      this.current = this.platforms[0].platform;
      this.loadTags();
      this.loadSheets(true);
    }
  }

  private makeDefaultTag(): RecommendTag {
    const tag = new RecommendTag();
    tag.id = '';
    tag.title = I18n.tx(this.appLocale, 'common.default');
    return tag;
  }

  private cloneTag(src: RecommendTag): RecommendTag {
    const tag = new RecommendTag();
    tag.id = src.id;
    tag.title = src.title.length > 0 ? src.title : I18n.tx(this.appLocale, 'common.unknownName');
    tag.urlSlug = src.urlSlug;
    return tag;
  }

  private tagJson(): string {
    const payload: Record<string, string> = {
      'id': this.selectedTag.id,
      'title': this.selectedTag.title
    };
    if (this.selectedTag.urlSlug.length > 0) {
      payload['url_slug'] = this.selectedTag.urlSlug;
    }
    return JSON.stringify(payload);
  }

  private switchPlatform(platform: string): void {
    if (this.current === platform) {
      return;
    }
    this.current = platform;
    this.selectedTag = this.makeDefaultTag();
    this.firstTag = this.makeDefaultTag();
    this.showTagSheet = false;
    this.loadTags();
    this.loadSheets(true);
  }

  async loadTags(): Promise<void> {
    const gen = this.tagGen + 1;
    this.tagGen = gen;
    const platform = this.current;
    this.pinned = [];
    this.tagGroups = [];
    try {
      const raw = await AppService.plugins.getRecommendTags(platform);
      if (gen !== this.tagGen) {
        return;
      }
      const parsed = AppService.plugins.parseRecommendTags(raw);
      this.pinned = parsed.pinned;
      this.tagGroups = parsed.data;
    } catch (_e) {
      if (gen !== this.tagGen) {
        return;
      }
      this.pinned = [];
      this.tagGroups = [];
    }
  }

  private pickPinnedTag(tag: RecommendTag): void {
    this.selectedTag = this.cloneTag(tag);
    this.loadSheets(true);
  }

  private pickGroupTag(tag: RecommendTag): void {
    const next = this.cloneTag(tag);
    this.firstTag = next;
    this.selectedTag = this.cloneTag(tag);
    this.showTagSheet = false;
    this.loadSheets(true);
  }

  private markSheetsEnd(pageData: SheetItem[]): void {
    if (pageData.length === 0) {
      this.sheetsEnd = true;
      return;
    }
    if (this.lastPageSize > 0 && pageData.length * 2 < this.lastPageSize) {
      this.sheetsEnd = true;
    }
    this.lastPageSize = pageData.length;
  }

  async loadSheets(reset: boolean): Promise<void> {
    if (!reset && (this.sheetsEnd || this.loading || this.loadingMore)) {
      return;
    }
    const gen = this.requestGen + 1;
    this.requestGen = gen;
    if (reset) {
      this.page = 1;
      this.sheets = [];
      this.sheetsEnd = false;
      this.lastPageSize = 0;
      this.loading = true;
      this.loadingMore = false;
    } else {
      this.page += 1;
      this.loadingMore = true;
    }
    const page = this.page;
    const tagJson = this.tagJson();
    const platform = this.current;
    try {
      const list = await AppService.plugins.getRecommendSheets(platform, tagJson, page);
      if (gen !== this.requestGen) {
        return;
      }
      this.markSheetsEnd(list);
      if (reset) {
        this.sheets = list;
      } else if (list.length > 0) {
        const next: SheetItem[] = this.sheets.slice();
        for (let i = 0; i < list.length; i++) {
          next.push(list[i]);
        }
        this.sheets = next;
      }
    } catch (_e) {
      if (gen !== this.requestGen) {
        return;
      }
      if (reset) {
        this.sheets = [];
      }
      this.sheetsEnd = true;
    }
    if (gen === this.requestGen) {
      this.loading = false;
      this.loadingMore = false;
    }
  }

  private openSheet(sheet: SheetItem): void {
    if (sheet.platform.length === 0) {
      sheet.platform = this.current;
    }
    AppService.params.sheetKind = 'sheet';
    sheet.kind = 'sheet';
    AppService.params.sheet = sheet;
    AppService.push(ROUTES.PLUGIN_SHEET);
  }

  build() {
    Column() {
      AppNavBar({ title: I18n.tx(this.appLocale, 'recommendSheet.title'), onBack: () => { AppService.pop(); } })
      if (this.platforms.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'recommendSheet.unsupported') })
      } else {
        Scroll() {
          Row() {
            ForEach(this.platforms, (p: PluginMeta) => {
              Text(p.platform)
                .fontSize(13)
                .fontColor(this.current === p.platform ? this.primary : this.textSecondary)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.switchPlatform(p.platform);
                })
            }, (p: PluginMeta) => p.hash)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .height(40)
        .width('100%')

        Scroll() {
          Row() {
            Row() {
              Text(this.firstTag.title.length > 0 ? this.firstTag.title : I18n.tx(this.appLocale, 'common.default'))
                .fontSize(13)
                .fontColor(this.selectedTag.id === this.firstTag.id ? this.primary : this.textColor)
                .maxLines(1)
                .margin({ right: 4 })
              IconImg({
                name: 'bars-3',
                iconSize: 14,
                color: this.selectedTag.id === this.firstTag.id ? this.primary : this.textSecondary
              })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .borderWidth(1)
            .borderColor(this.placeholder)
            .backgroundColor(this.card)
            .margin({ left: 12, right: 8 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.showTagSheet = true;
            })
            ForEach(this.pinned, (tag: RecommendTag, index: number) => {
              Text(tag.title.length > 0 ? tag.title : I18n.tx(this.appLocale, 'common.unknownName'))
                .fontSize(13)
                .fontColor(this.selectedTag.id === tag.id ? this.primary : this.textColor)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(16)
                .borderWidth(1)
                .borderColor(this.placeholder)
                .backgroundColor(this.card)
                .margin({ right: 8 })
                .onClick(() => {
                  this.pickPinnedTag(tag);
                })
            }, (tag: RecommendTag, index: number) => `pinned-${tag.id}-${index}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .height(44)
        .width('100%')
        .margin({ bottom: 4 })

        if (this.loading && this.sheets.length === 0) {
          LoadingProgress().width(36).height(36).margin({ top: 40 }).color(this.primary)
          Blank()
        } else if (this.sheets.length === 0) {
          EmptyView({ text: I18n.tx(this.appLocale, 'recommendSheet.empty') })
        } else {
          List() {
            ForEach(this.sheets, (sheet: SheetItem, index: number) => {
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
                  this.openSheet(sheet);
                })
              }
            }, (sheet: SheetItem, index: number) => `${sheet.platform}-${sheet.id}-${index}`)
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
          .scrollBar(BarState.Off)
          .onReachEnd(() => {
            this.loadSheets(false);
          })
        }
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
    .bindSheet($$this.showTagSheet, this.tagGroupBuilder(), {
      height: SheetSize.LARGE,
      showClose: false,
      backgroundColor: this.backdrop,
      blurStyle: BlurStyle.NONE,
      maskColor: this.maskColor
    })
  }

  @Builder
  tagGroupBuilder() {
    Column() {
      Row() {
        Text(I18n.tx(this.appLocale, 'recommendSheet.title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .layoutWeight(1)
          .maxLines(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showTagSheet = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 8 })
      .alignItems(VerticalAlign.Center)
      Scroll() {
        Column() {
          Text(I18n.tx(this.appLocale, 'common.default'))
            .fontSize(13)
            .fontColor(this.selectedTag.id === '' ? this.primary : this.textColor)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .borderWidth(1)
            .borderColor(this.placeholder)
            .backgroundColor(this.card)
            .onClick(() => {
              this.pickGroupTag(this.makeDefaultTag());
            })
          ForEach(this.tagGroups, (group: RecommendTagGroup, gi: number) => {
            Column() {
              if (group.title.length > 0) {
                Text(group.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.textColor)
                  .width('100%')
                  .margin({ top: 16, bottom: 8 })
              }
              Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
                ForEach(group.data, (tag: RecommendTag, ti: number) => {
                  Text(tag.title.length > 0 ? tag.title : I18n.tx(this.appLocale, 'common.unknownName'))
                    .fontSize(13)
                    .fontColor(this.selectedTag.id === tag.id ? this.primary : this.textColor)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(16)
                    .borderWidth(1)
                    .borderColor(this.placeholder)
                    .backgroundColor(this.card)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => {
                      this.pickGroupTag(tag);
                    })
                }, (tag: RecommendTag, ti: number) => `${gi}-${tag.id}-${ti}`)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (group: RecommendTagGroup, gi: number) => `group-${gi}-${group.title}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdrop)
  }
}
