import XCTest
@testable import ClipSightCore

@MainActor
final class DiagnosticReportTests: XCTestCase {
    func testLoggingSubsystemUsesOfficialBundleIdentifierAndCategories() {
        XCTAssertEqual(ClipSightLogging.subsystem, "com.anrlm.ClipSight")
        XCTAssertEqual(ClipSightLogging.Category.captureOCR, "CaptureOCR")
        XCTAssertEqual(ClipSightLogging.Category.permissions, "Permissions")
        XCTAssertEqual(ClipSightLogging.Category.clipboard, "Clipboard")
        XCTAssertEqual(ClipSightLogging.Category.hud, "HUD")
    }

    func testDiagnosticReportOmitsPotentialOCRTextAndLocalPaths() {
        let appState = AppState()
        appState.lastMessage = "secret recognized text from /Users/example/Desktop/capture.png"

        let report = DiagnosticReportBuilder.makeReport(
            appState: appState,
            appVersion: "1.2.3",
            buildNumber: "45",
            bundleIdentifier: "com.example.ClipSight",
            operatingSystemVersion: "macOS Test"
        )

        XCTAssertFalse(report.contains("secret recognized text"))
        XCTAssertFalse(report.contains("/Users/example"))
        XCTAssertTrue(report.contains("OCR Text: omitted"))
        XCTAssertTrue(report.contains("Screenshot Paths: omitted"))
    }

    func testDiagnosticReportIncludesOperationalState() {
        let appState = AppState()
        appState.launchAtLoginEnabled = true
        appState.isCapturing = true
        appState.setHUDPlacement(HUDPlacement(x: 0.25, y: 0.75))
        appState.lastCaptureSummary = LastCaptureSummary(
            result: .success,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            durationMilliseconds: 842,
            recognizedLineCount: 3
        )
        appState.applyPermissionSnapshot(
            PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: false,
                    isRequired: false
                )
            )
        )

        let report = DiagnosticReportBuilder.makeReport(
            appState: appState,
            appVersion: "1.2.3",
            buildNumber: "45",
            bundleIdentifier: "com.example.ClipSight",
            operatingSystemVersion: "macOS Test"
        )

        XCTAssertTrue(report.contains("Bundle ID: com.example.ClipSight"))
        XCTAssertTrue(report.contains("Version: 1.2.3 (45)"))
        XCTAssertTrue(report.contains("macOS: macOS Test"))
        XCTAssertTrue(report.contains("Screen Recording: granted"))
        XCTAssertTrue(report.contains("Accessibility: missing optional"))
        XCTAssertTrue(report.contains("Launch At Login: enabled"))
        XCTAssertTrue(report.contains("Capture Running: true"))
        XCTAssertTrue(report.contains("HUD Placement: x=0.250 y=0.750"))
        XCTAssertTrue(report.contains("Last Capture: result=success duration_ms=842 lines=3"))
    }
}
