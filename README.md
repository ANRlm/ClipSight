# ClipSight

ClipSight 是一个轻量 macOS 菜单栏 OCR 工具。用户从菜单栏或自定义全局快捷键触发后，应用调用 macOS 系统截图框选界面，使用 Apple Vision 在本机识别中文和英文文本，并自动复制到剪贴板。

ClipSight 不提供预览窗口、历史记录、自定义截图界面或网络 OCR。识别完全在本机完成，不调用任何网络服务。

## 要求

- macOS 13 Ventura 或更高版本
- Swift Package Manager
- Xcode 或 Command Line Tools

## 构建

```bash
swift build
```

如果本机 Command Line Tools 与 Xcode/SDK 版本不匹配，可以直接使用项目脚本；脚本会优先选择 `/Applications/Xcode.app` 内的 Swift 工具链和 macOS SDK：

```bash
./script/package_app.sh --configuration debug
```

## 测试

运行常规 Swift Testing 测试：

```bash
./script/test.sh
```

脚本会优先使用 `/Applications/Xcode.app` 内的 Swift 工具链，并补齐 Swift Testing 在部分 Command Line Tools 环境下需要的框架路径。

可选 OCR 集成验证默认不运行。它会生成一张临时高对比度中英文图片，调用 Apple Vision，并检查能识别英文和中文关键词：

```bash
CLIPSIGHT_RUN_OCR_INTEGRATION=1 ./script/test.sh --filter OCRServiceIntegrationTests
```

## 打包

生成 release app bundle：

```bash
./script/package_app.sh
```

产物位于：

```text
dist/ClipSight.app
```

本地运行：

```bash
/usr/bin/open -n dist/ClipSight.app
```

验证签名：

```bash
codesign --verify --deep --strict dist/ClipSight.app
```

开发运行：

```bash
./script/build_and_run.sh
```

默认打包会使用 ad-hoc 签名，并嵌入稳定的 bundle identifier requirement，避免每次重新构建后 macOS 权限记录只绑定到新的二进制哈希。如果你有自己的代码签名证书，可以传入：

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name" ./script/package_app.sh
```

## 使用

1. 启动 `ClipSight.app`。
2. 在菜单栏点击 ClipSight 图标。
3. 点击 `截图识别`，使用系统截图框选界面选择区域。
4. 识别完成后，文本会写入系统剪贴板，并在屏幕中上方显示简洁状态提示。

ClipSight 没有默认快捷键。请在 `设置...` 中点击 `录制快捷键` 自行配置，也可以随时清除。

## 权限

ClipSight 需要以下权限：

- 屏幕录制：允许系统截图结果被应用读取。

设置页会显示屏幕录制和辅助功能权限状态，并提供跳转系统设置入口。

如果从菜单栏或全局快捷键触发 OCR 时缺少屏幕录制权限，ClipSight 会提示原因，并自动打开对应的系统设置页面，方便添加授权。

辅助功能权限不是 OCR 的前置条件。当前全局快捷键使用 Carbon 注册，不依赖辅助功能权限；该状态在设置页中显示为可选，方便后续排查系统级快捷键问题。

如果你使用旧版本本地构建授予过屏幕录制权限，更新后可能需要在系统设置里关闭再重新打开一次 `ClipSight.app`。旧脚本使用每次变化的 ad-hoc cdhash 签名，macOS 可能把新构建识别为另一个授权对象。

## 开机启动

设置页中的开机启动开关使用 `SMAppService.mainApp`。建议从打包后的 `ClipSight.app` 运行应用，再启用开机启动。

## 本地 OCR

OCR 使用 Apple Vision `VNRecognizeTextRequest`，默认同时识别简体中文和英文：

- `zh-Hans`
- `en-US`

所有识别都在本机执行，不上传截图，不调用网络服务。
