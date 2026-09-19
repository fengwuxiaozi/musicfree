import { MusicItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { LyricExtra } from '../core/LyricExtra';
import { showToast } from '../core/HttpUtil';
import { I18n } from '../core/I18n';

@Component
export struct SearchLyricPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @State query: string = '';
  @State searching: boolean = false;
  @State searched: boolean = false;
  @State results: MusicItem[] = [];
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.query = AppService.params.lyricQuery;
    if (this.query.trim().length > 0) {
      this.doSearch(this.query);
    }
  }

  async doSearch(q: string): Promise<void> {
    const text = q.trim();
    if (text.length === 0) {
      return;
    }
    if (AppService.plugins.searchablePlugins('lyric').length === 0) {
      showToast(I18n.tx(this.appLocale, 'searchLyric.noResult'));
      return;
    }
    this.query = text;
    this.searching = true;
    this.searched = true;
    try {
      this.results = await AppService.plugins.searchLyric(text, 1);
    } catch (_e) {
      this.results = [];
      showToast(I18n.tx(this.appLocale, 'searchPage.fail'));
    }
    this.searching = false;
  }

  private associate(item: MusicItem): void {
    const current = AppService.player.current;
    if (current === null) {
      showToast(I18n.tx(this.appLocale, 'toast.noPlayingSong'));
      return;
    }
    LyricExtra.setAssociated(current, item);
    AppService.player.reloadLyric();
    showToast(I18n.tx(this.appLocale, 'toast.lyricAssociated'));
    AppService.pop();
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.tx(this.appLocale, 'lyric.searchLyric'),
        showBack: true,
        onBack: () => {
          AppService.pop();
        }
      })
      Row() {
        TextInput({ placeholder: I18n.tx(this.appLocale, 'searchLyric.placeholder'), text: this.query })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .onChange((v: string) => {
            this.query = v;
          })
          .onSubmit(() => {
            this.doSearch(this.query);
          })
        Text(I18n.tx(this.appLocale, 'common.search'))
          .fontColor(this.primary)
          .fontSize(15)
          .margin({ left: 12 })
          .onClick(() => {
            this.doSearch(this.query);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.searching) {
        Column() {
          LoadingProgress().width(40).height(40).color(this.primary).margin({ top: 80 })
          Text(I18n.tx(this.appLocale, 'searchPage.searching')).fontColor(this.textSecondary).margin({ top: 12 })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (!this.searched) {
        EmptyView({ text: I18n.tx(this.appLocale, 'searchLyric.hint') })
      } else if (this.results.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'searchLyric.noResult') })
      } else {
        List() {
          ForEach(this.results, (item: MusicItem, index: number) => {
            ListItem() {
              Row() {
                if (item.artwork.length > 0) {
                  Image(item.artwork)
                    .width(48)
                    .height(48)
                    .borderRadius(6)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor(this.placeholder)
                } else {
                  Image($r('app.media.album_default'))
                    .width(48)
                    .height(48)
                    .borderRadius(6)
                    .objectFit(ImageFit.Cover)
                }
                Column() {
                  Text(item.title.length > 0 ? item.title : I18n.tx(this.appLocale, 'common.unknownMusic'))
                    .fontSize(15)
                    .fontColor(this.textColor)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${item.artist}  ·  ${item.platform}`)
                    .fontSize(12)
                    .fontColor(this.textSecondary)
                    .margin({ top: 4 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            }
            .onClick(() => {
              this.associate(item);
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
