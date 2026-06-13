import Foundation
import XCTest

final class ReleaseInfrastructureTests: XCTestCase {
    func testPackageScriptSupportsOnlyLocalDistribution() throws {
        let source = try String(contentsOfFile: "script/package_app.sh", encoding: .utf8)

        XCTAssertTrue(source.contains("--distribution local"))
        XCTAssertTrue(source.contains("$APP_NAME-$MARKETING_VERSION-local.zip"))
        XCTAssertTrue(source.contains("codesign"))
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
        XCTAssertTrue(releaseScript.contains("./script/package_app.sh --distribution local"))
        XCTAssertFalse(releaseScript.contains("DISTRIBUTION="))
        XCTAssertTrue(releaseScript.contains("--push"))
        XCTAssertTrue(releaseScript.contains("release must be run from main"))
        XCTAssertTrue(releaseScript.contains("ClipSight-$VERSION-local.zip"))
        XCTAssertTrue(smokeScript.contains("System Events automation is not available"))
        XCTAssertTrue(smokeScript.contains("settings window lost focus after status menu interaction"))
        XCTAssertTrue(smokeScript.contains("app did not return to background-only mode"))
        XCTAssertTrue(verifyScript.contains("mode must be local"))
        XCTAssertTrue(verifyScript.contains("com.local.ClipSight"))
        XCTAssertFalse(verifyScript.contains(String(["n", "o", "t", "a", "r", "i", "z", "e", "d"])))
        XCTAssertFalse(verifyScript.contains(["developer", "id"].joined(separator: "-")))
    }

    func testTestScriptFallsBackWhenSwiftPMDoesNotSupportXCTestFeatureFlags() throws {
        let source = try String(contentsOfFile: "script/test.sh", encoding: .utf8)

        XCTAssertTrue(source.contains("Unknown option '--enable-xctest'"))
        XCTAssertTrue(source.contains("Unknown option '--disable-swift-testing'"))
        XCTAssertTrue(source.contains(#""$SWIFT_BIN" test "${XCTest_FLAGS[@]}" "$@""#))
    }
}
