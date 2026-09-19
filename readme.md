# MusicFree HarmonyOS NEXT

这是 MusicFree 的 **鸿蒙原生版**（ArkTS / ArkUI）。用 DevEco Studio 打开本仓库根目录即可编译运行。

## 和原版的对应关系

- 插件化播放器：本身不内置音源，通过安装 MusicFree 协议的 `.js` 插件完成搜索、播放、歌词、歌单等
- 插件在隐藏 WebView 沙箱中运行（ArkTS 不允许 `eval`），并提供 `axios` / `crypto-js` / `cheerio` / `dayjs` / `qs` 等常用依赖的兼容实现
- 播放使用系统 `AVPlayer` + `AVSession`，支持后台播放和锁屏控制
- 主题：深色 / 浅色 / 自定义背景（模糊与透明度），配色对齐原版（浅色主色 `#F17D34`，深色主色 `#3FA3B5`）
- 下载队列、WebDAV 备份恢复、定时关闭、插件订阅与排序、应用内悬浮歌词条
- 歌词偏移 / 翻译 / 搜索关联、歌单批量编辑与列表内搜索、检查更新、媒体缓存

## 已实现的页面

- 首页：侧边栏、搜索入口、推荐/榜单/历史/本地、我的歌单与收藏歌单、导入歌单、定时关闭、检查更新
- 搜索：单曲 / 专辑 / 作者 / 歌单（点击播放或替换播放列表）
- 播放详情：封面、歌词（字号 / 偏移 / 翻译 / 关联）、进度、循环模式、下载
- 搜索歌词、歌单批量编辑、列表内搜索
- 插件管理：网络/本地安装、订阅、排序、更新全部、启用/卸载
- 正在下载、本地音乐、播放历史、主题/自定义背景、基本设置、关于
- 备份与恢复：本地沙箱 + WebDAV，append / overwrite

## 环境要求

1. [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0 及以上
2. HarmonyOS SDK API 12（`5.0.0(12)`）或更高
3. 真机建议使用 HarmonyOS NEXT；模拟器需支持音频播放

## 打开与运行

1. 用 DevEco Studio 打开本仓库根目录
2. 等待 `ohpm` / `hvigor` 同步完成
3. 连接华为账号，配置调试签名（File → Project Structure → Signing Configs）
4. 选择真机或模拟器，点击 Run

包名：`fun.upup.musicfree.harmony`

## 使用插件

打开应用 → 侧边栏 → **插件管理**：

- 从网络安装：填入以 `.js` 结尾的插件地址，或以 `.json` 结尾的订阅地址
- 从本地安装：选择 `.js` / `.json` 文件

插件协议与原版一致，可参考：[插件开发文档](https://musicfree.catcat.work/plugin/introduction.html)

示例插件仓库：https://github.com/maotoumao/MusicFreePlugins

> 请自行鉴别第三方插件安全性。插件产生的数据与版权问题与本软件无关。

## 协议

基于 AGPL 3.0 开源项目 MusicFree 修改。二次分发请保留出处：https://github.com/maotoumao/MusicFree
