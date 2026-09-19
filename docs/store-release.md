# 双渠道打包与应用市场上架

仓库同时保留两条分发线：

- **GitHub 完整版**（product = `default`）：插件搜索、在线播放、榜单、下载
- **应用市场版**（product = `store`）：只播本地音乐，便于过华为应用市场版权审核

两条线共用一个包名：`fun.upup.musicfree.harmony`。

## 在 DevEco 里切换

1. 打开工程根目录
2. File → Project Structure → Signing Configs，配置签名
3. 工具栏 Product 选 `default` 或 `store`
4. Run 或 Build

市场版编译后，关于页版本号旁会显示「应用市场版」。首页没有推荐/榜单/插件入口，搜索只扫本地歌单。

## 命令行

```bash
# GitHub 完整版：调试 HAP
hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon

# 应用市场版：发布 APP（必须用发布证书）
hvigorw assembleApp -p product=store -p buildMode=release --no-daemon
```

产物一般在 `build/outputs/` 下。上架提交 **已签名 `.app`**，不要交调试 HAP。

当前版本：`versionName` 1.0.0，`versionCode` 10028。之后每次提审必须增大 `versionCode`。

## 应用市场上架清单

1. 华为开发者账号实名；网络应用通常还需 [工信部 APP 备案](https://beian.miit.gov.cn/)
2. [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建 HarmonyOS 应用，包名填 `fun.upup.musicfree.harmony`
3. 申请 **发布证书** `.cer` 和 **发布 Profile** `.p7b`，在 DevEco 配成 release（不要勾调试自动签名）
4. 隐私政策公开链接（上架资料里填写）：  
   https://github.com/fengwuxiaozi/musicfree/blob/main/docs/privacy.md  
   应用内路径：关于 → 隐私政策
5. Product 选 `store`，Build → Build Hap(s)/APP(s) → Build APP(s)
6. 用发布签名在真机装一次，确认只能播本地歌、没有插件入口
7. AGC 上传 `.app`，填图标、介绍、截图、权限说明后提交审核

## GitHub 完整版怎么发

用 `default` 产品打 HAP，放到 GitHub Release。安装需要调试或已签名设备。插件协议与原版一致，请自行鉴别第三方插件。

## 不要提交的内容

`build-profile.json5` 里的证书路径、密钥密码只留在本机。仓库里的 `build-profile.example.json5` 是不含密钥的产品配置示例。
