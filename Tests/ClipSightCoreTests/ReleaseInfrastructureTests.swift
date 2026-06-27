import Foundation
import XCTest

final class ReleaseInfrastructureTests: XCTestCase {
    func testPackageScriptSupportsOnlyLocalDistribution() throws {
        let source = try String(contentsOfFile: "script/package_app.sh", encoding: .utf8)

        XCTAssertTrue(source.contains("--distribution local"))
        XCTAssertTrue(source.contains("$APP_NAME-$MARKETING_VERSION-local.zip"))
        XCTAssertTrue(source.contains("$APP_NAME-$MARKETING_VERSION-local.dmg"))
        XCTAssertTrue(source.contains("MARKETING_VERSION=\"${MARKETING_VERSION:-0.5.0}\""))
        XCTAssertTrue(source.contains("defaults to 0.5.0"))
        XCTAssertTrue(source.contains("hdiutil create"))
        XCTAssertTrue(source.contains("ln -s /Applications"))
        XCTAssertTrue(source.contains("codesign"))
        XCTAssertTrue(source.contains("xcode-select -p"))
        XCTAssertTrue(source.contains("/Applications/Xcode-beta.app/Contents/Developer"))
        XCTAssertTrue(source.contains("export DEVELOPER_DIR=\"$XCODE_DEVELOPER_DIR\""))
        XCTAssertFalse(source.contains(["developer", "id"].joined(separator: "-")))
        XCTAssertFalse(source.contains(String(["n", "o", "t", "a", "r", "i", "z", "e", "d"])))
        XCTAssertFalse(source.contains(String(["n", "o", "t", "a", "r", "y", "t", "o", "o", "l"])))
        XCTAssertFalse(source.contains(["stap", "ler"].joined()))
    }

    func testCIWorkflowBuildsTestsPackagesAndVerifiesLocalBundle() throws {
        let source = try String(contentsOfFile: ".github/workflows/ci.yml", encoding: .utf8)

        XCTAssertTrue(source.contains("swift build"))
        XCTAssertTrue(source.contains("./script/test.sh"))
        XCTAssertTrue(source.contains("MARKETING_VERSION=0.0.0-ci"))
        XCTAssertTrue(source.contains("./script/package_app.sh --distribution local"))
        XCTAssertTrue(source.contains("script/verify_release.sh --mode local"))
        XCTAssertTrue(source.contains("git diff --check"))
        XCTAssertTrue(source.contains("actions/checkout@v5"))
    }

    func testPaidSigningReleaseWorkflowIsNotPresent() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: ".github/workflows/release.yml"))
    }

    func testLocalReleaseScriptAndSmokeScriptExposeExpectedInterfaces() throws {
        let buildRunScript = try String(contentsOfFile: "script/build_and_run.sh", encoding: .utf8)
        let releaseScript = try String(contentsOfFile: "script/release.sh", encoding: .utf8)
        let smokeScript = try String(contentsOfFile: "script/smoke_app.sh", encoding: .utf8)
        let verifyScript = try String(contentsOfFile: "script/verify_release.sh", encoding: .utf8)

        XCTAssertTrue(buildRunScript.contains("LOG_SUBSYSTEM=\"com.anrlm.ClipSight\""))
        XCTAssertTrue(releaseScript.contains("--version x.y.z"))
        XCTAssertTrue(releaseScript.contains("for example 0.5.0"))
        XCTAssertTrue(releaseScript.contains("./script/package_app.sh --distribution local"))
        XCTAssertFalse(releaseScript.contains("DISTRIBUTION="))
        XCTAssertTrue(releaseScript.contains("--push"))
        XCTAssertTrue(releaseScript.contains("release must be run from main"))
        XCTAssertTrue(releaseScript.contains("ClipSight-$VERSION-local.zip"))
        XCTAssertTrue(releaseScript.contains("ClipSight-$VERSION-local.dmg"))
        XCTAssertTrue(releaseScript.contains("gh release create \"$TAG\" \"$ASSET\" \"$DMG_ASSET\""))
        XCTAssertTrue(smokeScript.contains("System Events automation is not available"))
        XCTAssertTrue(smokeScript.contains("settings window lost focus after status menu interaction"))
        XCTAssertTrue(smokeScript.contains("app did not return to background-only mode"))
        XCTAssertTrue(verifyScript.contains("mode must be local"))
        XCTAssertTrue(verifyScript.contains("com.local.ClipSight"))
        XCTAssertTrue(verifyScript.contains("hdiutil attach"))
        XCTAssertTrue(verifyScript.contains("hdiutil detach"))
        XCTAssertTrue(verifyScript.contains("Applications"))
        XCTAssertFalse(verifyScript.contains(String(["n", "o", "t", "a", "r", "i", "z", "e", "d"])))
        XCTAssertFalse(verifyScript.contains(["developer", "id"].joined(separator: "-")))
    }

    func testPerformanceCheckScriptExposesExpectedLocalAuditFlow() throws {
        let source = try String(contentsOfFile: "script/perf_check.sh", encoding: .utf8)

        XCTAssertTrue(source.contains("usage: script/perf_check.sh [--app path/to/ClipSight.app]"))
        XCTAssertTrue(source.contains("CLIPSIGHT_ENABLE_QA_MENU=1"))
        XCTAssertTrue(source.contains("ps -o rss= -o %cpu="))
        XCTAssertTrue(source.contains("openSettingsIteration"))
        XCTAssertTrue(source.contains("showSuccessHUD"))
        XCTAssertTrue(source.contains("adjustHUDPosition"))
        XCTAssertTrue(source.contains("RSS delta"))
    }

    func testTestScriptFallsBackWhenSwiftPMDoesNotSupportXCTestFeatureFlags() throws {
        let source = try String(contentsOfFile: "script/test.sh", encoding: .utf8)

        XCTAssertTrue(source.contains("Unknown option '--enable-xctest'"))
        XCTAssertTrue(source.contains("Unknown option '--disable-swift-testing'"))
        XCTAssertTrue(source.contains("run_swift_test"))
        XCTAssertTrue(source.contains("command+=(\"${XCTest_FLAGS[@]}\")"))
        XCTAssertTrue(source.contains("command+=(\"${ARGS[@]}\")"))
        XCTAssertTrue(source.contains("xcode-select -p"))
        XCTAssertTrue(source.contains("/Applications/Xcode-beta.app/Contents/Developer"))
        XCTAssertTrue(source.contains("export DEVELOPER_DIR=\"$XCODE_DEVELOPER_DIR\""))
        XCTAssertTrue(source.contains("ClipSightCoreTests.xctest"))
        XCTAssertTrue(source.contains("$SCRATCH_PATH/out/Products/Debug/$TEST_BUNDLE_NAME"))
        XCTAssertTrue(source.contains("if [[ ${#XCTEST_ARGS[@]} -gt 0 ]]"))
        XCTAssertTrue(source.contains("exec \"$XCODE_XCTEST_AGENT\" \"$TEST_BUNDLE\""))
    }
}
