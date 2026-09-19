# 安装 MusicFree（鸿蒙）

HarmonyOS NEXT **不能像 Android 那样点一下 HAP 就装上**。本仓库也不走华为应用市场（上架要 APP 备案）。

请用下面两种方式之一，在自己的电脑上签名后装到真机。

包名：`fun.upup.musicfree.harmony`  
产品请选 **`default`（GitHub 完整版）**，才能用插件和在线搜索。`store` 是本地版，没有插件。

---

## 方法一：DevEco 打开工程直接运行（推荐）

适合第一次安装、以及换手机之后。

1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0 及以上，并配好 HarmonyOS SDK。
2. 克隆本仓库，用 DevEco **打开仓库根目录**（不要只打开某个子文件夹）。
3. 等 `ohpm` / `hvigor` 同步完成。
4. 手机打开开发者模式和 USB 调试（见文末），用数据线连电脑，弹窗点允许。
5. 登录华为账号：File → Project Structure → **Signing Configs** → 勾选自动签名。  
   调试证书会绑定**当前这台手机**的 UDID，换手机要重新签一次。
6. 工具栏 Product 选 **`default`**，选中真机，点 Run。

装好后打开应用 → 侧边栏 → **插件管理**，自行安装 `.js` 插件或 `.json` 订阅。本应用不内置音源。

---

## 方法二：自己编译 HAP，再用 hdc 安装

适合已经能编过包、想用命令行重装的人。HAP 必须是**你这台电脑签过名**的；别人电脑打出来的调试包，你的手机一般装不上。

### 1. 编译

仓库不带 `hvigorw`，用 DevEco 自带的。也可在 DevEco 里 Build → Build Hap(s)/APP(s) → Build Hap(s)。

```bash
# 把 DevEco 的 hvigor、node 加进 PATH 后，在仓库根目录执行
hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon
```

macOS 上 `hvigorw` 一般在：

```text
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
```

签过名的包一般在：

```text
entry/build/default/outputs/default/entry-default-signed.hap
```

没有 `*-signed.hap`、只有未签名包，说明 Signing Configs 没配好，回到方法一第 5 步。

### 2. 找到 hdc

`hdc` 在 DevEco 的 SDK 里，不是系统自带命令。

- macOS：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains`
- Windows：`DevEco Studio\sdk\default\openharmony\toolchains`

把该目录加入 `PATH`，或下面命令里写成绝对路径。

### 3. 连上手机

```bash
hdc list targets
```

有设备 ID 即可。无线调试时，先在手机「开发者选项 → 无线调试」里看 IP 和端口，再执行：

```bash
hdc tconn 手机IP:端口
hdc list targets
```

多台设备时，后面的命令都要加 `-t 设备ID`。

### 4. 安装并打开

把路径换成你的 HAP：

```bash
hdc -t 设备ID install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc -t 设备ID shell aa start -a EntryAbility -b fun.upup.musicfree.harmony
```

`-r` 表示覆盖安装。签名换过、覆盖失败时，先卸再装：

```bash
hdc -t 设备ID uninstall fun.upup.musicfree.harmony
hdc -t 设备ID install entry/build/default/outputs/default/entry-default-signed.hap
```

---

## 手机要打开的开关

1. 设置 → 关于本机 → 连续点击 **软件版本号**，直到提示已进入开发者模式。
2. 设置 → 系统和更新 → **开发者选项**：
   - 打开 USB 调试
   - 需要的话打开无线调试
3. 用数据线连电脑时，手机上允许调试。

---

## 常见问题

| 现象 | 处理 |
|---|---|
| `hdc list targets` 为空 | 换线、换口；`hdc kill` 后再 `hdc start`；无线则重新 `hdc tconn` |
| 安装失败 / 签名校验失败 / 设备不在证书中 | 必须用**这台手机**连着电脑时重新自动签名，不能拿别人的调试 HAP |
| 文件管理里点 HAP 没反应或无法安装 | 正常。NEXT 不支持随便旁加载，用 DevEco 或 hdc |
| 装上了但没有插件、搜不到歌 | 确认编的是 `default` 产品，不是 `store` |
| `ohpm install` / `hpm` 装不上播放器 | 本项目是 App，不是 ohpm 库。ohpm 只解决编译依赖 |

---

## 不要做的事

- 不要把 `build-profile.json5` 里的证书路径、密钥密码提交到 Git。
- 不要指望从 GitHub Release 下一份通用 HAP，在任意鸿蒙手机上点装——调试包按设备签名，换人换机都要自己编。
- 不上华为应用市场，也就没有商店搜索安装。若以后要上架，需要实名开发者账号和 [APP 备案](https://beian.miit.gov.cn/)，步骤见 [store-release.md](store-release.md)。
