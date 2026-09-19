import { LyricLine } from '../common/Types';

export class LyricParser {
  static parseTimeTag(tag: string): number {
    const inner = tag.substring(1, tag.length - 1);
    const nums = inner.split(':');
    let result = 0;
    for (let i = 0; i < nums.length; i++) {
      result = result * 60 + Number(nums[i]);
    }
    if (Number.isNaN(result)) {
      return 0;
    }
    return result;
  }

  static parse(raw: string): LyricLine[] {
    const lines: LyricLine[] = [];
    if (!raw || raw.length === 0) {
      return lines;
    }
    const cleaned = raw.replace(/\r/g, '').trim();
    const timeReg = /\[[\d:.]+\]/g;
    const pieces = cleaned.split(timeReg);
    const times = cleaned.match(timeReg);
    if (times === null || times.length === 0) {
      const parts = cleaned.split('\n');
      for (let i = 0; i < parts.length; i++) {
        const text = parts[i].trim();
        if (text.length === 0) {
          continue;
        }
        const line = new LyricLine();
        line.time = 0;
        line.text = text;
        lines.push(line);
      }
      return lines;
    }
    const pending: number[] = [];
    for (let i = 0; i < times.length; i++) {
      pending.push(LyricParser.parseTimeTag(times[i]));
      let text = '';
      if (i + 1 < pieces.length) {
        text = pieces[i + 1].trim();
      }
      if (text.length === 0) {
        continue;
      }
      for (let j = 0; j < pending.length; j++) {
        const line = new LyricLine();
        line.time = pending[j];
        line.text = text;
        lines.push(line);
      }
      pending.length = 0;
    }
    lines.sort((a: LyricLine, b: LyricLine) => a.time - b.time);
    return lines;
  }

  /**
   * 解析原文与翻译并按时间对齐。
   * offsetSec 为正表示歌词提前，应用到 time：time = rawTime - offsetSec。
   * findIndex 直接使用已偏移过的 lines。
   */
  static parseWithTranslation(raw: string, translation: string, offsetSec: number): LyricLine[] {
    let origin = LyricParser.parse(raw);
    if (origin.length === 0 && translation.length > 0) {
      origin = LyricParser.parse(translation);
      for (let i = 0; i < origin.length; i++) {
        origin[i].time = origin[i].time - offsetSec;
      }
      return origin;
    }
    const transLines = LyricParser.parse(translation);
    if (transLines.length > 0) {
      let p1 = 0;
      let p2 = 0;
      while (p1 < origin.length) {
        const lrcItem = origin[p1];
        while (p2 < transLines.length - 1 && transLines[p2].time < lrcItem.time) {
          p2 += 1;
        }
        if (p2 < transLines.length && transLines[p2].time === lrcItem.time) {
          lrcItem.translation = transLines[p2].text;
        } else {
          lrcItem.translation = '';
        }
        p1 += 1;
      }
    }
    for (let i = 0; i < origin.length; i++) {
      origin[i].time = origin[i].time - offsetSec;
    }
    return origin;
  }

  static findIndex(lines: LyricLine[], position: number): number {
    if (lines.length === 0) {
      return -1;
    }
    let idx = 0;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].time <= position + 0.15) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }
}
