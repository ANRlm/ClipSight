import Foundation

public enum AppLanguage: String, Codable, Equatable, Sendable {
    case chinese
    case english
}

public enum AppLanguageSelection: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case system
    case chinese
    case english

    public static let `default`: AppLanguageSelection = .system

    public var id: String {
        rawValue
    }

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        switch self {
        case .chinese:
            return .chinese
        case .english:
            return .english
        case .system:
            let preferredLanguage = preferredLanguages.first?.lowercased() ?? ""
            return preferredLanguage.hasPrefix("zh") ? .chinese : .english
        }
    }
}

public struct AppLanguageStore {
    public static let storageKey = "ClipSight.appLanguageSelection"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> AppLanguageSelection {
        guard let rawValue = userDefaults.string(forKey: Self.storageKey),
              let selection = AppLanguageSelection(rawValue: rawValue) else {
            return .default
        }

        return selection
    }

    public func save(_ selection: AppLanguageSelection) {
        userDefaults.set(selection.rawValue, forKey: Self.storageKey)
    }

    public func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }
}

public struct AppStrings: Equatable, Sendable {
    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    public var readyStatus: String { choose("就绪", "Ready") }
    public var shortcutNotSet: String { choose("未设置", "Not set") }
    public var captureActionTitle: String { choose("截图识别", "Capture OCR") }
    public var capturingActionTitle: String { choose("正在识别", "Recognizing") }
    public var shortcutMenuPrefix: String { choose("快捷键", "Shortcut") }
    public var settingsActionTitle: String { choose("设置...", "Settings...") }
    public var copyDiagnosticsActionTitle: String { choose("复制诊断信息", "Copy Diagnostics") }
    public var quitActionTitle: String { choose("退出", "Quit") }
    public var settingsWindowTitle: String { choose("ClipSight 设置", "ClipSight Settings") }
    public var copiedDiagnosticsMessage: String { choose("已复制诊断信息", "Copied diagnostics") }

    public var developmentValidationTitle: String { choose("开发验证", "Development QA") }
    public var showSuccessHUDTitle: String { choose("显示成功 HUD", "Show Success HUD") }
    public var showNoTextHUDTitle: String { choose("显示无文本 HUD", "Show No Text HUD") }
    public var showFailureHUDTitle: String { choose("显示失败 HUD", "Show Failure HUD") }
    public var adjustHUDPositionTitle: String { choose("调整 HUD 位置", "Adjust HUD Position") }

    public var settingsHeaderDetail: String {
        choose("框选截图，识别中英文文本，并复制到剪贴板", "Select a screen region, recognize Chinese and English text, and copy it to the clipboard")
    }

    public var localProcessingBadge: String { choose("本地处理", "Local") }
    public var shortcutSectionTitle: String { choose("快捷键", "Shortcut") }
    public var shortcutSectionSubtitle: String { choose("全局触发框选 OCR", "Global trigger for screen OCR") }
    public var permissionsSectionTitle: String { choose("权限", "Permissions") }
    public var permissionsSectionSubtitle: String {
        choose("屏幕录制为必需，辅助功能为可选", "Screen Recording is required. Accessibility is optional.")
    }

    public var requiredRoleLabel: String { choose("必需", "Required") }
    public var optionalRoleLabel: String { choose("可选", "Optional") }
    public var openButtonTitle: String { choose("打开", "Open") }
    public var refreshPermissionsNotice: String {
        choose("从系统设置返回后会自动刷新，也可手动刷新。", "Permissions refresh automatically after returning from System Settings. You can also refresh manually.")
    }
    public var refreshButtonTitle: String { choose("刷新", "Refresh") }

    public var systemSectionTitle: String { choose("系统", "System") }
    public var systemSectionSubtitle: String {
        choose("启动行为，语言和本地识别设置", "Launch behavior, language, and local recognition settings")
    }
    public var launchAtLoginTitle: String { choose("开机启动", "Launch at Login") }
    public var launchAtLoginDetail: String {
        choose("登录 macOS 后自动启动 ClipSight", "Start ClipSight automatically after logging in to macOS")
    }
    public var languageTitle: String { choose("语言", "Language") }
    public var languageDetail: String { choose("界面语言，默认同步系统", "Interface language. System is the default.") }
    public var hudPositionTitle: String { choose("提示框位置", "HUD Position") }
    public var hudPositionDetail: String {
        choose("拖动设置 OCR 结果提示的显示位置", "Drag to set where OCR result HUD appears")
    }
    public var adjustButtonTitle: String { choose("调整", "Adjust") }
    public var resetButtonTitle: String { choose("重置", "Reset") }

    public var shortcutRecordTitle: String { choose("录制", "Record") }
    public var shortcutRecordingTitle: String { choose("录制中", "Recording") }
    public var shortcutClearTitle: String { choose("清除", "Clear") }
    public var shortcutRecordingPrompt: String { choose("按下组合键，Esc 取消", "Press a shortcut. Esc cancels.") }
    public var currentShortcutTitle: String { choose("当前快捷键", "Current Shortcut") }
    public var shortcutKeyLabel: String { choose("按键", "Key") }

    public var hudSuccessMessage: String { choose("已复制", "Copied") }
    public var hudNoTextMessage: String { choose("未识别到文本", "No Text Found") }
    public var hudFailureMessage: String { choose("识别失败", "Recognition Failed") }
    public var placementCenteredLabel: String { choose("水平居中", "Centered") }
    public var placementCustomLabel: String { choose("自定义", "Custom") }
    public var placementCancelTitle: String { choose("取消", "Cancel") }
    public var placementDoneTitle: String { choose("完成", "Done") }

    public var ocrCapturingMessage: String { choose("正在截图识别", "Capturing for OCR") }
    public var permissionMissingOpenedSettingsMessage: String {
        choose("需要屏幕录制权限，已打开系统设置", "Screen Recording permission is required. System Settings has been opened.")
    }
    public var captureCancelledMessage: String { choose("已取消截图", "Capture cancelled") }
    public var noTextRecognizedMessage: String { hudNoTextMessage }

    public var permissionGrantedLabel: String { choose("已授权", "Granted") }
    public var permissionMissingLabel: String { choose("需要授权", "Needs Permission") }
    public var screenRecordingTitle: String { choose("屏幕录制", "Screen Recording") }
    public var screenRecordingDetail: String {
        choose("允许 ClipSight 读取框选截图内容", "Allow ClipSight to read selected screenshot content")
    }
    public var accessibilityTitle: String { choose("辅助功能", "Accessibility") }
    public var accessibilityDetail: String {
        choose("当前快捷键实现不依赖辅助功能权限", "The current shortcut implementation does not require Accessibility permission")
    }

    public var languageSystemOption: String { choose("同步系统", "System") }
    public var languageChineseOption: String { choose("中文", "Chinese") }
    public var languageEnglishOption: String { choose("English", "English") }

    public func copiedLinesMessage(_ lineCount: Int) -> String {
        switch language {
        case .chinese:
            return "已复制 \(lineCount) 行文本"
        case .english:
            return lineCount == 1 ? "Copied 1 line" : "Copied \(lineCount) lines"
        }
    }

    public func permissionSnapshot(
        screenRecordingGranted: Bool,
        accessibilityGranted: Bool
    ) -> PermissionSnapshot {
        PermissionSnapshot(
            screenRecording: screenRecordingPermissionStatus(isGranted: screenRecordingGranted),
            accessibility: accessibilityPermissionStatus(isGranted: accessibilityGranted)
        )
    }

    public func screenRecordingPermissionStatus(isGranted: Bool) -> PermissionStatus {
        PermissionStatus(
            title: screenRecordingTitle,
            grantedLabel: permissionGrantedLabel,
            missingLabel: permissionMissingLabel,
            detail: screenRecordingDetail,
            isGranted: isGranted
        )
    }

    public func accessibilityPermissionStatus(isGranted: Bool) -> PermissionStatus {
        PermissionStatus(
            title: accessibilityTitle,
            grantedLabel: permissionGrantedLabel,
            missingLabel: optionalRoleLabel,
            detail: accessibilityDetail,
            isGranted: isGranted,
            isRequired: false
        )
    }

    public func languageSelectionTitle(_ selection: AppLanguageSelection) -> String {
        switch selection {
        case .system:
            return languageSystemOption
        case .chinese:
            return languageChineseOption
        case .english:
            return languageEnglishOption
        }
    }

    public func errorMessage(for error: Error) -> String {
        if let error = error as? ScreenCaptureError {
            return screenCaptureErrorMessage(error)
        }

        if let error = error as? OCRServiceError {
            return ocrErrorMessage(error)
        }

        if let error = error as? ClipboardServiceError {
            return clipboardErrorMessage(error)
        }

        if let error = error as? HotKeyManagerError {
            return hotKeyErrorMessage(error)
        }

        return error.localizedDescription
    }

    public func screenCaptureErrorMessage(_ error: ScreenCaptureError) -> String {
        switch error {
        case .launchFailed(let message):
            return choose("无法启动系统截图工具：\(message)", "Could not start the system screenshot tool: \(message)")
        case .commandFailed(let status, let message):
            if message.isEmpty {
                return choose("系统截图失败，退出码 \(status)", "System screenshot failed with exit code \(status)")
            }

            return choose("系统截图失败：\(message)", "System screenshot failed: \(message)")
        case .outputUnreadable:
            return choose("截图文件无法读取", "Screenshot file could not be read")
        }
    }

    public func ocrErrorMessage(_ error: OCRServiceError) -> String {
        switch error {
        case .noTextRecognized:
            return noTextRecognizedMessage
        case .recognitionFailed(let message):
            return choose("OCR 识别失败：\(message)", "OCR recognition failed: \(message)")
        }
    }

    public func clipboardErrorMessage(_ error: ClipboardServiceError) -> String {
        switch error {
        case .emptyText:
            return choose("没有可复制的文本", "There is no text to copy")
        case .writeFailed:
            return choose("写入剪贴板失败", "Failed to write to the clipboard")
        }
    }

    public func hotKeyErrorMessage(_ error: HotKeyManagerError) -> String {
        switch error {
        case .eventHandlerInstallFailed(let status):
            return choose("快捷键监听初始化失败（\(status)）", "Shortcut listener setup failed (\(status))")
        case .registrationFailed(let status):
            return choose("快捷键注册失败（\(status)），可能已被其他应用占用", "Shortcut registration failed (\(status)). It may already be used by another app.")
        }
    }

    private func choose(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}
