import Foundation

public enum StatusHUDPresentation: Equatable, Sendable {
    case success(String)
    case failure(String)

    public var message: String {
        switch self {
        case .success(let message), .failure(let message):
            message
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success:
            true
        case .failure:
            false
        }
    }
}
