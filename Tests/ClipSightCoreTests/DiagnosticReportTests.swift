import XCTest
@testable import ClipSightCore

@MainActor
final class DiagnosticReportTests: XCTestCase {
    func testDiagnosticReportOmitsPotentialOCRTextAndLocalPaths() {
        let appState = AppState()
        appState.lastMessage = "secret recognized text from /Users/example/Desktop/capture.png"

        let report = DiagnosticReportBuilder.makeReport(
            appState: appState,
            appVersion: "1.2.3",
            buildNumber: "45",
            bundleIdentifier: "com.example.ClipSight"
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
            bundleIdentifier: "com.example.ClipSight"
        )

        XCTAssertTrue(report.contains("Bundle ID: com.example.ClipSight"))
        XCTAssertTrue(report.contains("Version: 1.2.3 (45)"))
        XCTAssertTrue(report.contains("Screen Recording: granted"))
        XCTAssertTrue(report.contains("Accessibility: missing optional"))
        XCTAssertTrue(report.contains("Launch At Login: enabled"))
        XCTAssertTrue(report.contains("Capture Running: true"))
        XCTAssertTrue(report.contains("HUD Placement: x=0.250 y=0.750"))
    }
}
