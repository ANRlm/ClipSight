# ClipSight Release Checklist

本清单用于发布 local/ad-hoc 签名的 GitHub Release。

## Local Build

1. 运行测试：

   ```bash
   ./script/test.sh
   ```

2. 生成 local/ad-hoc zip 和 DMG：

   ```bash
   MARKETING_VERSION="0.5.0" BUILD_NUMBER="5" ./script/package_app.sh --distribution local
   ```

3. 验证本地 app 和 DMG：

   ```bash
   script/verify_release.sh --mode local
   ```

   `local` 模式要求 app bundle 结构、codesign、DMG 挂载和 Applications 快捷方式验证通过。系统拒绝 local/ad-hoc 构建是允许结果。

## Manual Smoke Test

1. 运行真实窗口 smoke test：

   ```bash
   script/smoke_app.sh --app dist/ClipSight.app
   ```

2. 打开设置页，确认可滚动、可调整窗口大小，并且主要控件可通过键盘访问。
3. 调整 HUD 位置，验证拖动、水平居中吸附、取消和完成。
4. 触发 OCR 成功、无文本和失败路径，确认只显示结果 HUD。
5. 复制诊断信息，确认报告不包含 OCR 原文或截图路径。
6. 运行性能检查：

   ```bash
   script/perf_check.sh --app dist/ClipSight.app
   ```

   检查输出中的 RSS/CPU 快照，确认没有明显异常增长或后台 CPU 占用。

## GitHub Release

1. 确认当前分支是 `main` 且工作区干净。
2. 使用受控脚本发布：

   ```bash
   script/release.sh --version 0.5.0 --build 5 --push
   ```

3. 确认 GitHub Release assets 包含 `ClipSight-0.5.0-local.dmg` 和 `ClipSight-0.5.0-local.zip`。
4. Release notes 必须说明这是 local/ad-hoc 签名构建，首次打开可能需要在 Finder 中 Control-click 或右键选择 `打开`。
