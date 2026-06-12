import Foundation
import XCTest

final class ReleaseInfrastructureTests: XCTestCase {
    func testPackageScriptSupportsLocalDeveloperIDAndNotarizedDistributions() throws {
        let source = try String(contentsOfFile: "script/package_app.sh", encoding: .utf8)

        XCTAssertTrue(source.contains("--distribution local|developer-id|notarized"))
        XCTAssertTrue(source.contains("$APP_NAME-$MARKETING_VERSION-local.zip"))
        XCTAssertTrue(source.contains("$APP_NAME-$MARKETING_VERSION-developer-id.zip"))
        XCTAssertTrue(source.contains("$APP_NAME-$MARKETING_VERSION.zip"))
        XCTAssertTrue(source.contains("NOTARYTOOL_PROFILE is required for --distribution notarized"))
        XCTAssertTrue(source.contains("xcrun notarytool submit"))
        XCTAssertTrue(source.contains("xcrun stapler staple"))
    }

    func testCIWorkflowBuildsTestsPackagesAndVerifiesLocalBundle() throws {
        let source = try String(contentsOfFile: ".github/workflows/ci.yml", encoding: .utf8)

        XCTAssertTrue(source.contains("swift build"))
        XCTAssertTrue(source.contains("./script/test.sh"))
        XCTAssertTrue(source.contains("MARKETING_VERSION=0.0.0-ci"))
        XCTAssertTrue(source.contains("./script/package_app.sh --distribution local"))
        XCTAssertTrue(source.contains("script/verify_release.sh --mode local"))
        XCTAssertTrue(source.contains("git diff --check"))
    }

    func testReleaseWorkflowUsesManualNotarizedReleaseInputsAndSecrets() throws {
        let source = try String(contentsOfFile: ".github/workflows/release.yml", encoding: .utf8)

        XCTAssertTrue(source.contains("workflow_dispatch"))
        XCTAssertTrue(source.contains("CLIPSIGHT_BUNDLE_ID: com.anrlm.ClipSight"))
        XCTAssertTrue(source.contains("CLIPSIGHT_DEVELOPER_ID_CERT_BASE64"))
        XCTAssertTrue(source.contains("CLIPSIGHT_DEVELOPER_ID_CERT_PASSWORD"))
        XCTAssertTrue(source.contains("CLIPSIGHT_APPLE_ID"))
        XCTAssertTrue(source.contains("CLIPSIGHT_APPLE_TEAM_ID"))
        XCTAssertTrue(source.contains("CLIPSIGHT_APP_SPECIFIC_PASSWORD"))
        XCTAssertTrue(source.contains("CLIPSIGHT_CODESIGN_IDENTITY"))
        XCTAssertTrue(source.contains("./script/package_app.sh --distribution notarized"))
        XCTAssertTrue(source.contains("script/verify_release.sh --mode notarized"))
        XCTAssertTrue(source.contains("gh release create"))
    }

    func testLocalReleaseScriptAndSmokeScriptExposeExpectedInterfaces() throws {
        let buildRunScript = try String(contentsOfFile: "script/build_and_run.sh", encoding: .utf8)
        let releaseScript = try String(contentsOfFile: "script/release.sh", encoding: .utf8)
        let smokeScript = try String(contentsOfFile: "script/smoke_app.sh", encoding: .utf8)
        let verifyScript = try String(contentsOfFile: "script/verify_release.sh", encoding: .utf8)

        XCTAssertTrue(buildRunScript.contains("LOG_SUBSYSTEM=\"com.anrlm.ClipSight\""))
        XCTAssertTrue(releaseScript.contains("--version x.y.z"))
        XCTAssertTrue(releaseScript.contains("--distribution local|notarized"))
        XCTAssertTrue(releaseScript.contains("--push"))
        XCTAssertTrue(releaseScript.contains("release must be run from main"))
        XCTAssertTrue(releaseScript.contains("CLIPSIGHT_BUNDLE_ID"))
        XCTAssertTrue(smokeScript.contains("System Events automation is not available"))
        XCTAssertTrue(smokeScript.contains("settings window lost focus after status menu interaction"))
        XCTAssertTrue(smokeScript.contains("app did not return to background-only mode"))
        XCTAssertTrue(verifyScript.contains("CLIPSIGHT_EXPECTED_BUNDLE_ID:-com.anrlm.ClipSight"))
        XCTAssertTrue(verifyScript.contains("unexpected release bundle identifier"))
        XCTAssertTrue(verifyScript.contains("Skipped Gatekeeper acceptance for developer-id build"))
    }
}
