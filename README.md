# Triple Gemini Browser（三栏浏览器）

横屏三栏 Web 浏览器，每栏独立 Cookie / 登录态，可同时登录三个 Gemini（或任意网页）。用巨魔（TrollStore）安装 IPA。

## 功能

- 强制横屏，左 / 中 / 右三栏等宽
- 每栏独立 `WKWebsiteDataStore`，账号不串号
- 地址栏、前进 / 后退 / 刷新、主页（Gemini）、桌面版 UA
- 进度条、弹出登录窗处理（Google 登录常用）
- 单栏清除 Cookie（退出登录）
- 记住每栏上次打开的网址

**说明：** 只做手动浏览壳，不要加自动刷三个号的脚本。

## 环境要求

- **不需要自己的 Mac**：用 GitHub Actions 云端打包（见下）
- 手机：巨魔可用系统（常见 iOS 14～17.0）
- App 部署目标：**iOS 15.0+**（iOS 17+ 用系统级多数据仓；15/16 用 Cookie 落盘隔离）

## 无 Mac：用 GitHub 打 IPA（推荐）

1. 把本仓库推到 GitHub（公开或私有都行）
2. 打开仓库页 → **Actions** → **Build TrollStore IPA** → **Run workflow**
3. 等几分钟变绿 → 点进这次运行 → **Artifacts** → 下载 `TripleGeminiBrowser-trollstore`
4. 解压得到 `.ipa` → 传到手机 → 巨魔安装

推送 `main`/`master` 时也会自动打包。

### 有 Mac 时本地编译

```bash
chmod +x scripts/build_trollstore_ipa.sh
./scripts/build_trollstore_ipa.sh
```

产物：`build/TripleGeminiBrowser-trollstore.ipa`

## 使用

1. 横持手机打开 App
2. 三栏会各自打开 `gemini.google.com`
3. 在左 / 中 / 右分别登录三个 Google 账号
4. 地址栏可改成任意网址（普通浏览器）

若某栏登录异常：点该栏「清除登录」后再登一次。
