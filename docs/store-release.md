# 双渠道打包（可选）

当前对外安装方式是 **自己用 DevEco / hdc 装 GitHub 完整版**，见 [install.md](install.md)。不上华为应用市场。

仓库里仍保留两条产品线，给以后如果要上架用：

- **GitHub 完整版**（product = `default`）：插件搜索、在线播放、榜单、下载
- **应用市场版**（product = `store`）：只播本地音乐

两条线共用包名：`fun.upup.musicfree.harmony`。

日常请编 `default`。下面是上架备忘，需要华为开发者实名和 [工信部 APP 备案](https://beian.miit.gov.cn/)，本仓库维护者目前不做。

## 在 DevEco 里切换

1. 打开工程根目录
2. File → Project Structure → Signing Configs，配置签名
3. 工具栏 Product 选 `default` 或 `store`
4. Run 或 Build

`store` 编出来后，关于页版本号旁会显示「应用市场版」。首页没有推荐/榜单/插件入口，搜索只扫本地歌单。

## 命令行

```bash
# GitHub 完整版：调试 HAP（日常用这个）
hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon

# 应用市场版：发布 APP（必须用发布证书）
hvigorw assembleApp -p product=store -p buildMode=release --no-daemon
```

产物一般在 `build/outputs/` 或 `entry/build/default/outputs/default/`。上架只能交 **已签名 `.app`**，不要交调试 HAP。

当前版本：`versionName` 1.0.0，`versionCode` 10028。若提审，每次必须增大 `versionCode`。

## 若要上应用市场（需备案）

1. 华为开发者账号实名；网络应用通常还需 [工信部 APP 备案](https://beian.miit.gov.cn/)
2. [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建 HarmonyOS 应用，包名填 `fun.upup.musicfree.harmony`
3. 申请 **发布证书** `.cer` 和 **发布 Profile** `.p7b`，在 DevEco 配成 release（不要勾调试自动签名）
4. 隐私政策公开链接：  
   https://github.com/fengwuxiaozi/musicfree/blob/main/docs/privacy.md  
   应用内：关于 → 隐私政策
5. Product 选 `store`，Build → Build Hap(s)/APP(s) → Build APP(s)
6. 用发布签名在真机装一次，确认只能播本地歌、没有插件入口
7. AGC 上传 `.app`，填图标、介绍、截图、权限说明后提交审核

调试 HAP 按设备签名，不能当商店安装包，也不能指望任意手机点一下就装上。

## 不要提交的内容

`build-profile.json5` 里的证书路径、密钥密码只留在本机。仓库里的 `build-profile.example.json5` 是不含密钥的产品配置示例。
