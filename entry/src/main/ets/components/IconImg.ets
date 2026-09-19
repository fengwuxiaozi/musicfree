import { drawing } from '@kit.ArkGraphics2D';

@Component
export struct IconImg {
  @Prop name: string = 'musical-note';
  @Prop iconSize: number = 22;
  @Prop hitSize: number = 0;
  @Prop color: string = '#FCFCFC';

  private boxSize(): number {
    return this.hitSize > this.iconSize ? this.hitSize : this.iconSize;
  }

  private tintFilter(): drawing.ColorFilter {
    const argb: number[] = this.parseArgb(this.color);
    return drawing.ColorFilter.createBlendModeColorFilter(
      argb[0] * 16777216 + argb[1] * 65536 + argb[2] * 256 + argb[3],
      drawing.BlendMode.SRC_IN
    );
  }

  private parseArgb(hex: string): number[] {
    let h: string = hex.trim();
    if (h.startsWith('#')) {
      h = h.substring(1);
    }
    if (h.length === 6) {
      return [255, this.hexByte(h, 0), this.hexByte(h, 2), this.hexByte(h, 4)];
    }
    if (h.length === 8) {
      return [this.hexByte(h, 0), this.hexByte(h, 2), this.hexByte(h, 4), this.hexByte(h, 6)];
    }
    return [255, 252, 252, 252];
  }

  private hexByte(h: string, start: number): number {
    const value: number = Number.parseInt(h.substring(start, start + 2), 16);
    return Number.isNaN(value) ? 0 : value;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile(`icons/${this.name}.svg`))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .supportSvg2(true)
        .fillColor(this.color)
        .colorFilter(this.tintFilter())
        .autoResize(false)
        .hitTestBehavior(HitTestMode.None)
        .id(`icon-${this.name}-${this.color}`)
    }
    .width(this.boxSize())
    .height(this.boxSize())
    .hitTestBehavior(HitTestMode.None)
    .id(`icon-box-${this.name}`)
  }
}

@Component
export struct PlayTapIcon {
  @Prop name: string = 'play';
  @Prop iconSize: number = 22;
  @Prop iconColor: string = '#FCFCFC';
  @Prop label: string = '';
  onAction: () => void = () => {
  };

  build() {
    Column() {
      IconImg({ name: this.name, iconSize: this.iconSize, color: this.iconColor })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityText(this.label)
    .accessibilityLevel('yes')
  }
}
