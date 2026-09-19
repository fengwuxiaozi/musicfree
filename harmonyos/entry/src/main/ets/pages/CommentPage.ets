import { CommentItem, MusicItem } from '../common/Types';
import { AppNavBar } from '../components/AppNavBar';
import { EmptyView } from '../components/EmptyView';
import { IconImg } from '../components/IconImg';
import { MusicBar } from '../components/MusicBar';
import { AppService } from '../core/AppService';
import { CommentPageResult } from '../core/PluginManager';
import { showToast } from '../core/HttpUtil';
import { I18n } from '../core/I18n';

@Component
export struct CommentPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State music: MusicItem = new MusicItem();
  @State comments: CommentItem[] = [];
  @State loading: boolean = false;
  @State isEnd: boolean = false;
  private page: number = 0;

  aboutToAppear(): void {
    const item: MusicItem | null = AppService.params.commentMusic;
    if (item !== null) {
      this.music = item;
    }
    this.page = 0;
    this.isEnd = false;
    this.comments = [];
    this.loadPage();
  }

  private loadPage(): void {
    if (this.loading || this.isEnd) {
      return;
    }
    if (this.music.id.length === 0 && this.music.title.length === 0) {
      this.isEnd = true;
      return;
    }
    this.loading = true;
    const nextPage: number = this.page + 1;
    this.fetchComments(nextPage);
  }

  private async fetchComments(nextPage: number): Promise<void> {
    try {
      const result: CommentPageResult = await AppService.plugins.getMusicComments(this.music, nextPage);
      this.page = nextPage;
      const chunk: CommentItem[] = result.data !== undefined && result.data !== null ? result.data : [];
      if (chunk.length > 0) {
        const next: CommentItem[] = this.comments.slice();
        for (let i = 0; i < chunk.length; i++) {
          next.push(chunk[i]);
        }
        this.comments = next;
      }
      this.isEnd = result.isEnd !== false || chunk.length === 0;
    } catch (_e) {
      showToast(I18n.tx(this.appLocale, 'comment.loadFail'));
    }
    this.loading = false;
  }

  private formatDate(ts: number): string {
    if (ts <= 0) {
      return '';
    }
    const d: Date = new Date(ts);
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const mm: string = month < 10 ? `0${month}` : `${month}`;
    const dd: string = day < 10 ? `0${day}` : `${day}`;
    return `${d.getFullYear()}-${mm}-${dd}`;
  }

  private commentFooter(item: CommentItem): string {
    let text: string = '';
    if (item.createAt > 0) {
      text = this.formatDate(item.createAt);
    }
    if (item.location.length > 0) {
      if (text.length > 0) {
        text += ' ';
      }
      text += item.location;
    }
    return text;
  }

  private hasFooter(item: CommentItem): boolean {
    return item.createAt > 0 || item.location.length > 0 || item.like > 0;
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.tx(this.appLocale, 'common.comment'),
        onBack: () => {
          AppService.pop();
        }
      })
      Row() {
        if (this.music.artwork.length > 0) {
          Image(this.music.artwork)
            .width(52)
            .height(52)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
            .backgroundColor(this.placeholder)
        } else {
          Image($r('app.media.album_default'))
            .width(52)
            .height(52)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
        }
        Column() {
          Text(this.music.title.length > 0 ? this.music.title : I18n.tx(this.appLocale, 'common.unknownMusic'))
            .fontSize(15)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.music.artist)
            .fontSize(12)
            .fontColor(this.textSecondary)
            .margin({ top: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.loading && this.comments.length === 0) {
        LoadingProgress().width(36).height(36).margin({ top: 40 }).color(this.primary)
        Blank()
      } else if (this.comments.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'comment.empty') })
      } else {
        List() {
          ForEach(this.comments, (item: CommentItem, index: number) => {
            ListItem() {
              this.commentRow(item)
            }
          }, (item: CommentItem, index: number) => `${item.id}-${index}-${item.createAt}`)
          if (this.loading) {
            ListItem() {
              Row() {
                LoadingProgress().width(24).height(24).color(this.primary)
              }
              .width('100%')
              .height(48)
              .justifyContent(FlexAlign.Center)
            }
          } else if (this.isEnd) {
            ListItem() {
              Text(I18n.tx(this.appLocale, 'comment.end'))
                .fontSize(12)
                .fontColor(this.textSecondary)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 16 })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.loadPage();
        })
      }
      MusicBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }

  @Builder
  commentRow(item: CommentItem) {
    Column() {
      Row() {
        if (item.avatar.length > 0) {
          Image(item.avatar)
            .width(24)
            .height(24)
            .borderRadius(12)
            .objectFit(ImageFit.Cover)
            .backgroundColor(this.placeholder)
        } else {
          Row() {
            IconImg({ name: 'user', iconSize: 14, color: this.textSecondary })
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor(this.placeholder)
          .justifyContent(FlexAlign.Center)
        }
        Text(item.nickName.length > 0 ? item.nickName : I18n.tx(this.appLocale, 'common.unknownName'))
          .fontSize(13)
          .fontColor(this.textColor)
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(item.comment)
        .fontSize(13)
        .fontColor(this.textColor)
        .lineHeight(20)
        .width('100%')
        .margin({ top: 8, left: 32 })
      if (this.hasFooter(item)) {
        Row() {
          Text(this.commentFooter(item))
            .fontSize(12)
            .fontColor(this.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (item.like > 0) {
            Row() {
              IconImg({ name: 'hand-thumb-up', iconSize: 12, color: this.textSecondary })
              Text(`${item.like}`)
                .fontSize(12)
                .fontColor(this.textSecondary)
                .margin({ left: 4 })
            }
            .margin({ left: 8 })
            .alignItems(VerticalAlign.Center)
          }
        }
        .width('100%')
        .margin({ top: 8, left: 32 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }
}
