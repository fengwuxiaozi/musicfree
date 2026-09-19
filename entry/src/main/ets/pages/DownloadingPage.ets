import { DownloadTask, DownloadStatus, downloadStatusText } from '../core/Downloader';
import { AppNavBar } from '../components/AppNavBar';
import { MusicBar } from '../components/MusicBar';
import { EmptyView } from '../components/EmptyView';
import { AppService } from '../core/AppService';
import { I18n } from '../core/I18n';

@Component
export struct DownloadingPage {
  @StorageLink('pageBackground') pageBackground: string = '#202020';
  @StorageLink('textColor') textColor: string = '#FCFCFC';
  @StorageLink('textSecondary') textSecondary: string = '#B3FCFCFC';
  @StorageLink('primary') primary: string = '#3FA3B5';
  @StorageLink('downloadTick') @Watch('reload') downloadTick: number = 0;
  @StorageLink('appLocale') appLocale: string = 'zh-CN';
  @State tasks: DownloadTask[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.tasks = AppService.downloader.listTasks();
  }

  private playCompleted(task: DownloadTask): void {
    if (task.status !== DownloadStatus.Completed) {
      return;
    }
    if (task.localItem.url.length > 0) {
      AppService.player.playMusic(task.localItem, AppService.localMusics);
      return;
    }
    if (task.localPath.length > 0) {
      const found = AppService.findLocalByPath(task.localPath);
      if (found !== null) {
        AppService.player.playMusic(found, AppService.localMusics);
      }
    }
  }

  build() {
    Column() {
      AppNavBar({
        title: I18n.tx(this.appLocale, 'downloading.title'),
        onBack: () => {
          AppService.pop();
        }
      })
      Row() {
        Text(I18n.tx(this.appLocale, 'downloading.clearCompleted'))
          .fontSize(13)
          .fontColor(this.primary)
          .onClick(() => {
            AppService.downloader.clearCompleted();
          })
      }
      .width('100%')
      .padding({ left: 16, bottom: 8 })

      if (this.tasks.length === 0) {
        EmptyView({ text: I18n.tx(this.appLocale, 'downloading.empty') })
      } else {
        List() {
          ForEach(this.tasks, (task: DownloadTask) => {
            ListItem() {
              Column() {
                Text(task.musicItem.title.length > 0 ? task.musicItem.title : I18n.tx(this.appLocale, 'common.unknownMusic'))
                  .fontSize(15)
                  .fontColor(this.textColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(downloadStatusText(task))
                  .fontSize(12)
                  .fontColor(task.status === DownloadStatus.Failed ? '#FC5F5F' : this.textSecondary)
                  .margin({ top: 4 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (task.status === DownloadStatus.Downloading && task.fileSize > 0) {
                  Progress({
                    value: task.downloadedSize,
                    total: task.fileSize,
                    type: ProgressType.Linear
                  })
                    .color(this.primary)
                    .width('100%')
                    .height(4)
                    .margin({ top: 8 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            }
            .onClick(() => {
              if (task.status === DownloadStatus.Failed) {
                AppService.downloader.retry(task);
                return;
              }
              this.playCompleted(task);
            })
          }, (task: DownloadTask) => `${task.key}-${this.downloadTick}`)
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
