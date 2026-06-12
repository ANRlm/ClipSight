import CoreGraphics
import Foundation

public enum DiagnosticReportBuilder {
    @MainActor
    public static func makeReport(appState: AppState, bundle: Bundle = .main) -> String {
        makeReport(
            appState: appState,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown"
        )
    }

    @MainActor
    public static func makeReport(
        appState: AppState,
        appVersion: String,
        buildNumber: String,
        bundleIdentifier: String
    ) -> String {
        let hudPlacement = appState.hudPlacement
        let hotKeyErrorState = appState.hotKeyRegistrationError == nil ? "none" : "present"

        return [
            "ClipSight Diagnostics",
            "Bundle ID: \(bundleIdentifier)",
            "Version: \(appVersion) (\(buildNumber))",
            "Screen Recording: \(permissionLabel(appState.screenRecordingPermission))",
            "Accessibility: \(permissionLabel(appState.accessibilityPermission))",
            "Launch At Login: \(appState.launchAtLoginEnabled ? "enabled" : "disabled")",
            "Capture Running: \(appState.isCapturing)",
            "Shortcut: \(appState.shortcutDisplay)",
            "Hot Key Error: \(hotKeyErrorState)",
            "HUD Placement: x=\(format(hudPlacement.x)) y=\(format(hudPlacement.y))",
            "OCR Text: omitted",
            "Screenshot Paths: omitted"
        ].joined(separator: "\n")
    }

    private static func permissionLabel(_ status: PermissionStatus) -> String {
        if status.isGranted {
            return "granted"
        }

        return status.isRequired ? "missing required" : "missing optional"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.3f", Double(value))
    }
}
