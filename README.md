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

## 使用（保证三栏各登各的号）

1. 横持手机打开 App  
2. 每一栏点钥匙图标（登录 Google）→ 进入账号添加页  
3. 左 / 中 / 右各登一个不同的 Google 账号  
4. 登录完成后会回到 Gemini；三栏 Cookie 相互隔离，不会串号  

若提示浏览器不安全：确认该栏是**桌面 UA**（电脑图标为蓝色），再点登录。  
若某栏要换号：点「清除登录」图标，再点钥匙重新登。
