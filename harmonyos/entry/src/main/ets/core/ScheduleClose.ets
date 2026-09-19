import { formatTime } from './HttpUtil';
import { I18n } from './I18n';

/**
 * 定时关闭：与原版一致。
 * 快捷时间为 10/20/30/45/60 分钟或自定义；到时退出应用。
 * 勾选「播放完歌曲再关闭」后，倒计时结束会等当前曲播完再退出。
 */
export class ScheduleClose {
  static deadline: number = 0;
  static waitingPlayEnd: boolean = false;
  static closeAfterPlay: boolean = false;
  static remainLabel: string = '';
  static pauseAndExit: (exit: boolean) => void = (_exit: boolean) => {
  };

  private static timeoutId: number = -1;
  private static intervalId: number = -1;

  static init(): void {
    ScheduleClose.publish('');
  }

  static isActive(): boolean {
    return ScheduleClose.deadline > Date.now() || ScheduleClose.waitingPlayEnd;
  }

  static setCloseAfterPlay(on: boolean): void {
    ScheduleClose.closeAfterPlay = on;
  }

  static setMinutes(minutes: number): void {
    if (minutes <= 0) {
      return;
    }
    ScheduleClose.clearTimers();
    ScheduleClose.waitingPlayEnd = false;
    ScheduleClose.deadline = Date.now() + minutes * 60000;
    const delay = ScheduleClose.deadline - Date.now();
    ScheduleClose.timeoutId = setTimeout(() => {
      ScheduleClose.fire(false);
    }, delay);
    ScheduleClose.startTicker();
    ScheduleClose.publishRemain();
  }

  static cancel(): void {
    ScheduleClose.clearTimers();
    ScheduleClose.deadline = 0;
    ScheduleClose.waitingPlayEnd = false;
    ScheduleClose.publish('');
  }

  static onPlayEnded(): boolean {
    if (!ScheduleClose.waitingPlayEnd) {
      return false;
    }
    ScheduleClose.fire(true);
    return true;
  }

  private static fire(fromPlayEnd: boolean): void {
    if (!fromPlayEnd && ScheduleClose.closeAfterPlay) {
      ScheduleClose.clearTimers();
      ScheduleClose.deadline = 0;
      ScheduleClose.waitingPlayEnd = true;
      ScheduleClose.publish(I18n.t('panel.timingClose.closeAfterPlay'));
      return;
    }
    ScheduleClose.cancel();
    ScheduleClose.pauseAndExit(true);
  }

  private static startTicker(): void {
    ScheduleClose.clearIntervalOnly();
    ScheduleClose.intervalId = setInterval(() => {
      if (ScheduleClose.deadline <= Date.now()) {
        ScheduleClose.clearIntervalOnly();
        return;
      }
      ScheduleClose.publishRemain();
    }, 1000);
  }

  private static publishRemain(): void {
    const left = Math.max(ScheduleClose.deadline - Date.now(), 0) / 1000;
    ScheduleClose.publish(formatTime(left));
  }

  private static publish(label: string): void {
    ScheduleClose.remainLabel = label;
    AppStorage.setOrCreate('scheduleRemain', label);
  }

  private static clearTimers(): void {
    if (ScheduleClose.timeoutId >= 0) {
      clearTimeout(ScheduleClose.timeoutId);
      ScheduleClose.timeoutId = -1;
    }
    ScheduleClose.clearIntervalOnly();
  }

  private static clearIntervalOnly(): void {
    if (ScheduleClose.intervalId >= 0) {
      clearInterval(ScheduleClose.intervalId);
      ScheduleClose.intervalId = -1;
    }
  }
}
