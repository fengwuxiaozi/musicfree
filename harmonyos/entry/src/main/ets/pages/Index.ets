import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { ROUTES } from '../common/Constants';
import { AppService } from '../core/AppService';
import { PluginJsBridge, PluginSandbox } from '../core/PluginSandbox';
import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { MusicDetailPage } from './MusicDetailPage';
import { CommentPage } from './CommentPage';
import { SheetDetailPage } from './SheetDetailPage';
import { PluginSheetPage, AlbumDetailPage, ArtistDetailPage } from './MediaDetailPages';
import { PluginPage } from './PluginPage';
import { SettingPage, ThemePage, AboutPage, BackupPage } from './SettingPages';
import { BasicSettingPage } from './BasicSettingPage';
import { HistoryPage, LocalMusicPage, TopListPage, RecommendPage } from './ExtraPages';
import { DownloadingPage } from './DownloadingPage';
import { CustomThemePage } from './CustomThemePage';
import { PluginSubscribePage } from './PluginSubscribePage';
import { PluginSortPage } from './PluginSortPage';
import { MusicListEditorPage } from './MusicListEditorPage';
import { SearchMusicListPage } from './SearchMusicListPage';
import { SearchLyricPage } from './SearchLyricPage';
import { PermissionsPage } from './PermissionsPage';
import { ImportSheetPage } from './ImportSheetPage';
import { FloatingLyricBar } from '../core/FloatingLyric';

@Entry
@Component
struct Index {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('themeRev') themeRev: number = 0;
  @StorageLink('toastMsg') @Watch('onToast') toastMsg: string = '';
  @StorageLink('bgUrl') bgUrl: string = '';
  @StorageLink('bgBlur') bgBlur: number = 20;
  @StorageLink('bgOpacity') bgOpacity: number = 0.6;
  @State showSplash: boolean = true;
  @State splashOpacity: number = 1;
  private pageInfos: NavPathStack = new NavPathStack();
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: PluginJsBridge = new PluginJsBridge();
  private splashHidden: boolean = false;
  private splashStarted: number = 0;

  aboutToAppear(): void {
    AppService.nav = this.pageInfos;
    webview.WebviewController.setWebDebuggingAccess(true);
    this.splashStarted = Date.now();
    setTimeout(() => {
      this.hideSplash();
    }, 2400);
  }

  private hideSplash(): void {
    if (this.splashHidden) {
      return;
    }
    const elapsed: number = Date.now() - this.splashStarted;
    const wait: number = elapsed >= 1200 ? 0 : (1200 - elapsed);
    setTimeout(() => {
      if (this.splashHidden) {
        return;
      }
      this.splashHidden = true;
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.splashOpacity = 0;
      });
      setTimeout(() => {
        this.showSplash = false;
      }, 420);
    }, wait);
  }

  onToast(): void {
    if (this.toastMsg.length > 0) {
      promptAction.showToast({ message: this.toastMsg, duration: 2000 });
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pageBackground)
        .id(`root-bg-${this.themeRev}`)
      if (this.bgUrl.length > 0) {
        Image(this.bgUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.bgOpacity)
          .blur(this.bgBlur)
          .syncLoad(true)
          .hitTestBehavior(HitTestMode.None)
      }
      Navigation(this.pageInfos) {
        HomePage()
      }
      .hideTitleBar(true)
      .hideBackButton(true)
      .navDestination(this.PageMap)
      .mode(NavigationMode.Stack)
      .backgroundColor(this.bgUrl.length > 0 ? '#00000000' : this.pageBackground)

      Web({ src: $rawfile('plugin_runtime.html'), controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .onlineImageAccess(true)
        .mixedMode(MixedMode.All)
        .javaScriptProxy({
          object: this.bridge,
          name: 'MusicFreeNative',
          methodList: ['onResult', 'onLog', 'http', 'mfHttp', 'takePayload'],
          controller: this.controller
        })
        .onControllerAttached(() => {
          PluginSandbox.instance().bind(this.controller);
          try {
            this.controller.registerJavaScriptProxy(this.bridge, 'MusicFreeNative', ['onResult', 'onLog', 'http', 'mfHttp', 'takePayload']);
          } catch (_e) {
          }
        })
        .onPageEnd(() => {
          PluginSandbox.instance().markReady();
          AppService.onSandboxReady();
          this.hideSplash();
        })
        .id('plugin-runtime-web')
        .width(16)
        .height(16)
        .opacity(0.01)
        .align(Alignment.BottomStart)
        .margin({ left: 4, bottom: 96 })
        .hitTestBehavior(HitTestMode.None)

      FloatingLyricBar()

      if (this.showSplash) {
        Column() {
          Blank()
          Image($r('app.media.logo'))
            .width(96)
            .height(96)
            .borderRadius(22)
            .objectFit(ImageFit.Cover)
          Blank()
          Image($r('app.media.splash_branding'))
            .width(200)
            .height(72)
            .objectFit(ImageFit.Contain)
            .margin({ bottom: 56 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#27282C')
        .opacity(this.splashOpacity)
        .hitTestBehavior(HitTestMode.Block)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PageMap(name: string) {
    if (name === ROUTES.SEARCH) {
      NavDestination() { SearchPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.MUSIC_DETAIL) {
      NavDestination() { MusicDetailPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
        .onShown(() => {
          const cur = AppStorage.get<number>('musicDetailShowTick');
          const n: number = cur !== undefined && cur !== null ? cur : 0;
          AppStorage.setOrCreate('musicDetailShowTick', n + 1);
        })
    } else if (name === ROUTES.MUSIC_COMMENT) {
      NavDestination() { CommentPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.SHEET_DETAIL) {
      NavDestination() { SheetDetailPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.PLUGIN_SHEET) {
      NavDestination() { PluginSheetPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.ALBUM) {
      NavDestination() { AlbumDetailPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.ARTIST) {
      NavDestination() { ArtistDetailPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.PLUGIN) {
      NavDestination() { PluginPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.SETTING) {
      NavDestination() { SettingPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.BASIC) {
      NavDestination() { BasicSettingPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.THEME) {
      NavDestination() { ThemePage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.ABOUT) {
      NavDestination() { AboutPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.BACKUP) {
      NavDestination() { BackupPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.HISTORY) {
      NavDestination() { HistoryPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.LOCAL) {
      NavDestination() { LocalMusicPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
        .onShown(() => {
          const cur = AppStorage.get<number>('localMusicTick');
          const n: number = cur !== undefined && cur !== null ? cur : 0;
          AppStorage.setOrCreate('localMusicTick', n + 1);
        })
    } else if (name === ROUTES.TOP_LIST) {
      NavDestination() { TopListPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.RECOMMEND) {
      NavDestination() { RecommendPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.DOWNLOADING) {
      NavDestination() { DownloadingPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.SET_CUSTOM_THEME) {
      NavDestination() { CustomThemePage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.PLUGIN_SUBSCRIBE) {
      NavDestination() { PluginSubscribePage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.PLUGIN_SORT) {
      NavDestination() { PluginSortPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.MUSIC_LIST_EDITOR) {
      NavDestination() { MusicListEditorPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.SEARCH_MUSIC_LIST) {
      NavDestination() { SearchMusicListPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.SEARCH_LYRIC) {
      NavDestination() { SearchLyricPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else if (name === ROUTES.PERMISSIONS) {
      NavDestination() { PermissionsPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
        .onShown(() => {
          const cur = AppStorage.get<number>('permPageRev');
          const n: number = cur !== undefined && cur !== null ? cur : 0;
          AppStorage.setOrCreate('permPageRev', n + 1);
        })
    } else if (name === ROUTES.IMPORT_SHEET) {
      NavDestination() { ImportSheetPage() }
        .hideTitleBar(true)
        .hideBackButton(true)
        .backgroundColor(this.pageBackground)
    } else {
      NavDestination() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.pageBackground)
      }
      .hideTitleBar(true)
      .hideBackButton(true)
      .backgroundColor(this.pageBackground)
    }
  }
}
