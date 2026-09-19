import BuildProfile from 'BuildProfile';

export class AppChannel {
  static isStore(): boolean {
    return `${BuildProfile.PRODUCT_NAME}` === 'store';
  }
}
