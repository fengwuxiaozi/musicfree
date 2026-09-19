import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { MusicItem, SheetItem } from '../common/Types';
import { HISTORY_SHEET_ID, LOCAL_SHEET_ID } from '../common/Constants';
import { IconImg } from './IconImg';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';
import { MediaCache } from '../core/MediaCache';
import { LyricExtra } from '../core/LyricExtra';
import { showToast } from '../core/HttpUtil';

@Component
export struct MusicOptionsSheet {
  @Prop item: MusicItem = new MusicItem();
  @Prop sheetId: string = '';
  @Prop fromDetail: boolean = false;
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('placeholder') placeholder: string = '#424242';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State pickingSheet: boolean = false;
  @State sheetOptions: SheetItem[] = [];
  onClose: () => void = () => {
  };
  onTimingClose: () => void = () => {
  };

  private sheetBackground(): string {
    return this.backdrop.length > 0 ? this.backdrop : this.pageBackground;
  }

  private headerSubtitle(): string {
    if (this.item.album.length > 0) {
      return `${this.item.artist} - ${this.item.album}`;
    }
    return this.item.artist;
  }

  private downloaded(): boolean {
    return AppService.isDownloaded(this.item);
  }

  private showAlbumOption(): boolean {
    return this.item.album.length > 0;
  }

  private associated(): MusicItem | null {
    return LyricExtra.getAssociated(this.item);
  }

  private associateTitle(): string {
    const linked = this.associated();
    if (linked === null) {
      return I18n.tx(this.appLocale, 'panel.musicItemOptions.associateLyric');
    }
    return I18n.tx(this.appLocale, 'panel.musicItemOptions.associatedLyric')
      .replace('{platform}', linked.platform)
      .replace('{id}', linked.id);
  }

  private showCommentOption(): boolean {
    const plugin = AppService.plugins.findByPlatform(this.item.platform);
    if (plugin === null) {
      return false;
    }
    return AppService.plugins.hasMethod(plugin, 'getMusicComments');
  }

  private openComments(): void {
    this.onClose();
    AppService.openComments(this.item);
  }

  private copyText(text: string): void {
    try {
      const board = pasteboard.getSystemPasteboard();
      board.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
      showToast(I18n.tx(this.appLocale, 'toast.copiedToClipboard'));
    } catch (_e) {
      showToast(I18n.tx(this.appLocale, 'toast.copiedToClipboardFailed'));
    }
  }

  private copyId(): void {
    MediaCache.set(this.item);
    const payload: Record<string, string> = {};
    payload['platform'] = this.item.platform;
    payload['id'] = this.item.id;
    this.copyText(JSON.stringify(payload));
  }

  private startPickSheet(): void {
    this.sheetOptions = AppService.sheets.sheets.slice();
    this.pickingSheet = true;
  }

  private pickSheet(sheet: SheetItem): void {
    AppService.sheets.addMusics(sheet.id, [this.item]);
    showToast(I18n.tx(this.appLocale, 'toast.addedToSheet'));
    this.onClose();
  }

  private deleteFromSheet(): void {
    if (this.sheetId === HISTORY_SHEET_ID) {
      AppService.history.removeItems([this.item]);
    } else if (this.sheetId === LOCAL_SHEET_ID) {
      AppService.removeLocalDownload(this.item);
    } else if (this.sheetId.length > 0) {
      AppService.sheets.removeMusics(this.sheetId, [this.item]);
    }
    showToast(I18n.tx(this.appLocale, 'toast.deleteSuccess'));
    this.onClose();
  }

  private confirmDeleteLocal(): void {
    promptAction.showDialog({
      title: I18n.tx(this.appLocale, 'panel.musicItemOptions.deleteLocalDownload'),
      message: I18n.tx(this.appLocale, 'panel.musicItemOptions.deleteLocalDownloadConfirm'),
      buttons: [
        { text: I18n.tx(this.appLocale, 'common.cancel'), color: this.textSecondary },
        { text: I18n.tx(this.appLocale, 'common.confirm'), color: this.primary }
      ]
    }).then((result) => {
      if (result.index === 1) {
        AppService.removeLocalDownload(this.item);
        showToast(I18n.tx(this.appLocale, 'toast.deleteSuccess'));
        this.onClose();
      }
    }).catch(() => {
      showToast(I18n.tx(this.appLocale, 'panel.musicItemOptions.deleteFailed'));
    });
  }

  build() {
    Column() {
      this.sheetHeader()
      Row() {}
        .width('100%')
        .height(1)
        .backgroundColor(this.placeholder)
      if (this.pickingSheet) {
        this.sheetPickerBody()
      } else {
        Scroll() {
          Column() {
            this.moreRow('identification', `ID: ${this.item.key()}`, () => {
              this.copyId();
            })
            this.moreRow('user', I18n.tx(this.appLocale, 'panel.musicItemOptions.author').replace('{artist}', this.item.artist), () => {
              this.copyText(this.item.artist);
            })
            if (this.showAlbumOption()) {
              this.moreRow('album-outline', I18n.tx(this.appLocale, 'panel.musicItemOptions.album').replace('{album}', this.item.album), () => {
                this.copyText(this.item.album);
              })
            }
            this.moreRow('motion-play', I18n.tx(this.appLocale, 'musicListEditor.addToNextPlay'), () => {
              AppService.player.addNext(this.item);
              this.onClose();
            })
            this.moreRow('folder-plus', I18n.tx(this.appLocale, 'musicListEditor.addToSheet'), () => {
              this.startPickSheet();
            })
            if (!this.downloaded()) {
              this.moreRow('arrow-down-tray', I18n.tx(this.appLocale, 'common.download'), () => {
                AppService.downloader.download(this.item);
                this.onClose();
              })
            } else {
              this.moreRow('check-circle-outline', I18n.tx(this.appLocale, 'panel.musicItemOptions.downloaded'), () => {
              })
            }
            if (this.sheetId.length > 0) {
              this.moreRow('trash-outline', I18n.tx(this.appLocale, 'common.delete'), () => {
                this.deleteFromSheet();
              })
            }
            if (this.downloaded()) {
              this.moreRow('trash-outline', I18n.tx(this.appLocale, 'panel.musicItemOptions.deleteLocalDownload'), () => {
                this.confirmDeleteLocal();
              })
            }
            if (this.showCommentOption()) {
              this.moreRow('chat-bubble-oval-left-ellipsis', I18n.tx(this.appLocale, 'panel.musicItemOptions.readComment'), () => {
                this.openComments();
              })
            }
            this.moreRow('link', this.associateTitle(), () => {
              this.onClose();
              AppService.openSearchLyric(this.item.title);
            })
            if (this.associated() !== null) {
              this.moreRow('link-slash', I18n.tx(this.appLocale, 'panel.musicItemOptions.unassociateLyric'), () => {
                LyricExtra.clearAssociated(this.item);
                showToast(I18n.tx(this.appLocale, 'panel.musicItemOptions.unassociateLyricSuccess'));
                this.onClose();
              })
            }
            if (this.fromDetail) {
              this.moreRow('alarm-outline', I18n.tx(this.appLocale, 'panel.musicItemOptions.timingClose'), () => {
                this.onClose();
                this.onTimingClose();
              })
            }
            this.moreRow('archive-box-x-mark', I18n.tx(this.appLocale, 'panel.musicItemOptions.clearPluginCache'), () => {
              MediaCache.remove(this.item);
              showToast(I18n.tx(this.appLocale, 'panel.musicItemOptions.cacheCleared'));
            })
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetBackground())
  }

  @Builder
  sheetHeader() {
    Row() {
      if (this.item.artwork.length > 0) {
        Image(this.item.artwork)
          .width(70)
          .height(70)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor(this.placeholder)
      } else {
        Image($r('app.media.album_default'))
          .width(70)
          .height(70)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      }
      Column() {
        Text(this.item.title.length > 0 ? this.item.title : I18n.tx(this.appLocale, 'common.unknownMusic'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.headerSubtitle())
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 6 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceAround)
      .layoutWeight(1)
      .height(70)
      .margin({ left: 18 })
    }
    .width('100%')
    .height(100)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  sheetPickerBody() {
    Column() {
      this.moreRow('arrow-left', I18n.tx(this.appLocale, 'common.cancel'), () => {
        this.pickingSheet = false;
      })
      if (this.sheetOptions.length === 0) {
        Text(I18n.tx(this.appLocale, 'musicListEditor.noSheets'))
          .fontSize(14)
          .fontColor(this.textSecondary)
          .margin({ top: 24 })
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        List() {
          ForEach(this.sheetOptions, (sheet: SheetItem, index: number) => {
            ListItem() {
              Row() {
                IconImg({ name: 'folder-outline', iconSize: 20, color: this.textColor })
                Text(sheet.title.length > 0 ? sheet.title : I18n.tx(this.appLocale, 'common.unknownName'))
                  .fontSize(15)
                  .fontColor(this.textColor)
                  .margin({ left: 12 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .height(48)
              .alignItems(VerticalAlign.Center)
            }
            .onClick(() => {
              this.pickSheet(sheet);
            })
          }, (sheet: SheetItem, index: number) => `${sheet.id}-${index}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, bottom: 24 })
  }

  @Builder
  moreRow(icon: string, title: string, action: () => void) {
    Row() {
      IconImg({ name: icon, iconSize: 18, color: this.textColor })
      Text(title)
        .fontSize(15)
        .fontColor(this.textColor)
        .margin({ left: 12 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }
}
