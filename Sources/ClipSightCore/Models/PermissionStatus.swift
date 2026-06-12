import Foundation

public struct PermissionStatus: Equatable {
    public let title: String
    public let grantedLabel: String
    public let missingLabel: String
    public let detail: String
    public let isGranted: Bool
    public let isRequired: Bool

    public init(
        title: String,
        grantedLabel: String = "已授权",
        missingLabel: String = "需要授权",
        detail: String,
        isGranted: Bool,
        isRequired: Bool = true
    ) {
        self.title = title
        self.grantedLabel = grantedLabel
        self.missingLabel = missingLabel
        self.detail = detail
        self.isGranted = isGranted
        self.isRequired = isRequired
    }

    public var statusLabel: String {
        isGranted ? grantedLabel : missingLabel
    }

    public var requiresAction: Bool {
        isRequired && !isGranted
    }
}

public struct PermissionSnapshot: Equatable {
    public let screenRecording: PermissionStatus
    public let accessibility: PermissionStatus

    public init(screenRecording: PermissionStatus, accessibility: PermissionStatus) {
        self.screenRecording = screenRecording
        self.accessibility = accessibility
    }
}
