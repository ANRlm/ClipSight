# ClipSight Release Checklist

本清单用于发布前确认本地构建、Developer ID 签名和公证流程。不要把本地 ad-hoc 包当作正式分发包。

## Local Build

1. 运行测试：

   ```bash
   ./script/test.sh
   ```

2. 生成本地包：

   ```bash
   ./script/package_app.sh --distribution local
   ```

3. 验证本地包：

   ```bash
   script/verify_release.sh --mode local
   ```

   local 模式只要求 app bundle 结构和 codesign 验证通过。`spctl` / Gatekeeper 拒绝本地 ad-hoc 构建是允许结果。

## Developer ID Build

1. 设置正式 bundle id、版本号和 Developer ID 签名身份：

   ```bash
   CODESIGN_IDENTITY="Developer ID Application: Your Name" \
   CLIPSIGHT_BUNDLE_ID="com.example.ClipSight" \
   MARKETING_VERSION="0.3.0" \
   BUILD_NUMBER="1" \
   ./script/package_app.sh --distribution developer-id
   ```

2. 验证 Developer ID 包：

   ```bash
   script/verify_release.sh --mode developer-id
   ```

   developer-id 模式要求 Gatekeeper 接受该 app。

## Notarized Build

1. 使用已配置的 notarytool keychain profile 构建并提交公证：

   ```bash
   NOTARYTOOL_PROFILE="clipsight-notary" \
   CODESIGN_IDENTITY="Developer ID Application: Your Name" \
   CLIPSIGHT_BUNDLE_ID="com.example.ClipSight" \
   MARKETING_VERSION="0.3.0" \
   BUILD_NUMBER="1" \
   ./script/package_app.sh --distribution developer-id
   ```

2. 验证已 staple 的 app：

   ```bash
   script/verify_release.sh --mode notarized
   ```

   notarized 模式要求 Developer ID 校验、Gatekeeper 校验和 stapler 校验全部通过。

## Manual Smoke Test

1. 从 `dist/ClipSight.app` 启动应用。
2. 打开设置页，确认可滚动、可调整窗口大小。
3. 调整 HUD 位置，验证拖动、水平居中吸附、取消和完成。
4. 触发 OCR 成功、无文本和失败路径，确认只显示结果 HUD。
5. 复制诊断信息，确认报告不包含 OCR 原文或截图路径。
