import { IconImg } from './IconImg';
import { AppService } from '../core/AppService';

@Component
export struct AppNavBar {
  @StorageLink('appBar') appBar: string = '#262626';
  @StorageLink('appBarText') appBarText: string = '#FCFCFC';
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('backdrop') backdrop: string = '#303030';
  @StorageLink('statusBarHeight') statusBarHeight: number = 44;
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop menuTitles: string[] = [];
  onBack: () => void = () => {
  };
  onMenuAction: (index: number) => void = (_i: number) => {
  };
  @BuilderParam rightSlot: () => void = this.emptyRight;

  aboutToAppear(): void {
    AppService.theme.setAppBarStatusIcons(true);
  }

  aboutToDisappear(): void {
    AppService.theme.setAppBarStatusIcons(false);
  }

  menuCardColor(): string {
    if (this.backdrop.length > 0) {
      return this.backdrop;
    }
    return this.pageBackground;
  }

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          IconImg({ name: 'arrow-left', iconSize: 22, color: this.appBarText })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onBack();
        })
      }
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.appBarText)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.rightSlot()
      if (this.menuTitles.length > 0) {
        Row() {
          IconImg({ name: 'ellipsis-vertical', iconSize: 22, color: this.appBarText })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .bindMenu(this.themedMenu, {
          backgroundColor: this.menuCardColor(),
          backgroundBlurStyle: BlurStyle.NONE,
          borderRadius: 8
        })
      }
    }
    .width('100%')
    .height(48 + this.statusBarHeight)
    .padding({ left: 8, right: 12, top: this.statusBarHeight })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.appBar)
  }

  @Builder
  themedMenu() {
    Menu() {
      ForEach(this.menuTitles, (title: string, index: number) => {
        MenuItem({ content: title })
          .contentFontColor(this.textColor)
          .backgroundColor(this.menuCardColor())
          .onChange((selected: boolean) => {
            if (selected) {
              this.onMenuAction(index);
            }
          })
      }, (title: string, index: number) => `nav-menu-${index}-${title}`)
    }
    .backgroundColor(this.menuCardColor())
    .backgroundBlurStyle(BlurStyle.NONE)
    .fontColor(this.textColor)
    .radius(8)
  }

  @Builder
  emptyRight() {
  }
}
