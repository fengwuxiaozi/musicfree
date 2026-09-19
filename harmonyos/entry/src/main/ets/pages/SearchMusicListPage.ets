import { MusicItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { MusicItemRow } from '../components/MusicItemRow';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct SearchMusicListPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @State title: string = '';
  @State query: string = '';
  @State all: MusicItem[] = [];
  @State filtered: MusicItem[] = [];
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.title = AppService.params.searchListTitle;
    this.all = AppService.params.searchList.slice();
    this.query = '';
    this.applyFilter();
  }

  private applyFilter(): void {
    const q = this.query.trim().toLowerCase();
    if (q.length === 0) {
      this.filtered = this.all.slice();
      return;
    }
    const next: MusicItem[] = [];
    for (let i = 0; i < this.all.length; i++) {
      const title = this.all[i].title.toLowerCase();
      const artist = this.all[i].artist.toLowerCase();
      if (title.indexOf(q) >= 0 || artist.indexOf(q) >= 0) {
        next.push(this.all[i]);
      }
    }
    this.filtered = next;
  }

  build() {
    Column() {
      AppNavBar({
        title: this.title.length > 0 ? this.title : I18n.tx(this.appLocale, 'searchMusicList.title'),
        onBack: () => {
          AppService.pop();
        }
      })
      Row() {
        TextInput({ placeholder: I18n.tx(this.appLocale, 'searchMusicList.placeholder'), text: this.query })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.placeholder)
          .fontColor(this.textColor)
          .placeholderColor(this.textSecondary)
          .onChange((v: string) => {
            this.query = v;
            this.applyFilter();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.filtered.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'searchMusicList.noMatch') })
      } else {
        List() {
          ForEach(this.filtered, (item: MusicItem, index: number) => {
            ListItem() {
              MusicItemRow({ item: item, index: index })
            }
            .onClick(() => {
              AppService.player.playMusic(item, this.filtered);
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
  }
}
