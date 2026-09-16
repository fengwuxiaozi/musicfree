import { MusicItem, SheetItem } from '../common/Types';
import { HISTORY_SHEET_ID, LOCAL_SHEET_ID } from '../common/Constants';
import { AppNavBar } from '../components/AppNavBar';
import { IconImg } from '../components/IconImg';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { showToast } from '../core/HttpUtil';
import { I18n } from '../core/I18n';

class EditorRow {
  item: MusicItem = new MusicItem();
  checked: boolean = false;
}

@Component
export struct MusicListEditorPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('appBar') appBar: string = '#262626';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('mask') maskColor: string = '#CC212121';
  @State rows: EditorRow[] = [];
  @State changed: boolean = false;
  @State editorTitle: string = '';
  @State editorSheetId: string = '';
  @State showSheets: boolean = false;
  @State sheetOptions: SheetItem[] = [];
  @StorageLink('appLocale') appLocale: string = 'zh-CN';

  aboutToAppear(): void {
    this.editorTitle = AppService.params.editorTitle;
    this.editorSheetId = AppService.params.editorSheetId;
    const source = AppService.params.editorMusics.slice();
    const rows: EditorRow[] = [];
    for (let i = 0; i < source.length; i++) {
      const row = new EditorRow();
      row.item = source[i];
      row.checked = false;
      rows.push(row);
    }
    this.rows = rows;
    this.changed = false;
  }

  private selectedCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.rows.length; i++) {
      if (this.rows[i].checked) {
        n++;
      }
    }
    return n;
  }

  private allSelected(): boolean {
    return this.rows.length > 0 && this.selectedCount() === this.rows.length;
  }

  private canSave(): boolean {
    return this.changed && this.editorSheetId.length > 0;
  }

  private canDelete(): boolean {
    return this.editorSheetId.length > 0;
  }

  private selectedMusics(): MusicItem[] {
    const items: MusicItem[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      if (this.rows[i].checked) {
        items.push(this.rows[i].item);
      }
    }
    return items;
  }

  private musicList(): MusicItem[] {
    const items: MusicItem[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      items.push(this.rows[i].item);
    }
    return items;
  }

  private replaceRows(rows: EditorRow[]): void {
    this.rows = rows;
  }

  private copyRows(checked: boolean): EditorRow[] {
    const next: EditorRow[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      const row = new EditorRow();
      row.item = this.rows[i].item;
      row.checked = checked;
      next.push(row);
    }
    return next;
  }

  private toggleAt(index: number): void {
    const next: EditorRow[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      const row = new EditorRow();
      row.item = this.rows[i].item;
      row.checked = i === index ? !this.rows[i].checked : this.rows[i].checked;
      next.push(row);
    }
    this.replaceRows(next);
  }

  private toggleSelectAll(): void {
    if (this.allSelected()) {
      this.replaceRows(this.copyRows(false));
    } else {
      this.replaceRows(this.copyRows(true));
    }
  }

  private clearChecked(): void {
    this.replaceRows(this.copyRows(false));
  }

  private save(): void {
    if (!this.canSave()) {
      return;
    }
    const list = this.musicList();
    if (this.editorSheetId === HISTORY_SHEET_ID) {
      AppService.history.replaceAll(list);
    } else if (this.editorSheetId === LOCAL_SHEET_ID) {
      AppService.localMusics = list;
      AppService.saveLocalMusics();
    } else {
      AppService.sheets.replaceMusics(this.editorSheetId, list);
    }
    this.changed = false;
    showToast(I18n.t('toast.saveSuccess'));
    AppService.pop();
  }

  private playNext(): void {
    const items = this.selectedMusics();
    for (let i = 0; i < items.length; i++) {
      AppService.player.addNext(items[i]);
    }
    if (items.length > 0) {
      this.clearChecked();
    }
  }

  private openSheets(): void {
    if (this.selectedCount() === 0) {
      return;
    }
    this.sheetOptions = AppService.sheets.sheets.slice();
    this.showSheets = true;
  }

  private addToSheet(sheet: SheetItem): void {
    const items = this.selectedMusics();
    if (items.length === 0) {
      return;
    }
    AppService.sheets.addMusics(sheet.id, items);
    this.showSheets = false;
    this.clearChecked();
    showToast(I18n.t('toast.addedToSheet'));
  }

  private downloadSelected(): void {
    const items = this.selectedMusics();
    for (let i = 0; i < items.length; i++) {
      AppService.downloader.download(items[i]);
    }
    if (items.length > 0) {
      this.clearChecked();
    }
  }

  private deleteSelected(): void {
    if (!this.canDelete() || this.selectedCount() === 0) {
      return;
    }
    const next: EditorRow[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      if (!this.rows[i].checked) {
        const row = new EditorRow();
        row.item = this.rows[i].item;
        row.checked = false;
        next.push(row);
      }
    }
    this.replaceRows(next);
    this.changed = true;
  }

  build() {
    Column() {
      AppNavBar({
        title: this.editorTitle.length > 0 ? this.editorTitle : I18n.t('common.batchEdit'),
        onBack: () => {
          AppService.pop();
        }
      })
      Row() {
        Text(this.allSelected() ? I18n.t('musicListEditor.unselectAllCount').replace('{count}', `${this.selectedCount()}`) : I18n.t('musicListEditor.selectAllCount').replace('{count}', `${this.selectedCount()}`))
          .fontSize(13)
          .fontColor(this.primary)
          .onClick(() => {
            this.toggleSelectAll();
          })
        Blank()
        Text(I18n.t('common.save'))
          .fontSize(13)
          .fontColor(this.canSave() ? this.primary : this.textSecondary)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.rows.length === 0) {
        EmptyView({ text: I18n.t('musicListEditor.empty') })
      } else {
        List() {
          ForEach(this.rows, (row: EditorRow, index: number) => {
            ListItem() {
              Row() {
                Checkbox()
                  .select(row.checked)
                  .selectedColor(this.primary)
                  .unselectedColor(this.textColor)
                  .width(20)
                  .height(20)
                  .hitTestBehavior(HitTestMode.None)
                Column() {
                  Text(row.item.title.length > 0 ? row.item.title : I18n.t('common.unknownMusic'))
                    .fontSize(15)
                    .fontColor(this.textColor)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(row.item.artist.length > 0 ? row.item.artist : I18n.t('common.unknownArtist'))
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
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .onClick(() => {
                this.toggleAt(index);
              })
            }
          }, (row: EditorRow, index: number) => `${row.item.key()}-${index}-${row.checked ? '1' : '0'}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }

      Row() {
        this.bottomBtn('motion-play', I18n.t('musicListEditor.addToNextPlay'), true, () => {
          this.playNext();
        })
        this.bottomBtn('folder-plus', I18n.t('musicListEditor.addToSheet'), true, () => {
          this.openSheets();
        })
        this.bottomBtn('arrow-down-tray', I18n.t('common.download'), true, () => {
          this.downloadSelected();
        })
        this.bottomBtn('trash-outline', I18n.t('common.delete'), this.canDelete(), () => {
          this.deleteSelected();
        })
      }
      .width('100%')
      .height(72)
      .backgroundColor(this.appBar)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
    .bindSheet($$this.showSheets, this.sheetPicker(), {
      height: 360,
      showClose: false,
      backgroundColor: this.backdrop.length > 0 ? this.backdrop : this.pageBackground,
      maskColor: this.maskColor
    })
  }

  @Builder
  bottomBtn(icon: string, title: string, enabled: boolean, action: () => void) {
    Column() {
      IconImg({ name: icon, iconSize: 22, color: this.appBarText })
      Text(title)
        .fontSize(11)
        .fontColor(this.appBarText)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .opacity(enabled ? 1 : 0.4)
    .onClick(() => {
      if (enabled) {
        action();
      }
    })
  }

  @Builder
  sheetPicker() {
    Column() {
      Row() {
        Text(I18n.t('musicListEditor.addToSheet'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .layoutWeight(1)
        Row() {
          IconImg({ name: 'x-mark', iconSize: 18, color: this.textSecondary })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showSheets = false;
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 8 })
      if (this.sheetOptions.length === 0) {
        Text(I18n.t('musicListEditor.noSheets'))
          .fontSize(14)
          .fontColor(this.textSecondary)
          .margin({ top: 24 })
      } else {
        List() {
          ForEach(this.sheetOptions, (sheet: SheetItem) => {
            ListItem() {
              Text(sheet.title.length > 0 ? sheet.title : I18n.t('common.unknownName'))
                .fontSize(15)
                .fontColor(this.textColor)
                .padding(14)
                .width('100%')
            }
            .onClick(() => {
              this.addToSheet(sheet);
            })
          }, (sheet: SheetItem) => sheet.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdrop.length > 0 ? this.backdrop : this.pageBackground)
  }
}
