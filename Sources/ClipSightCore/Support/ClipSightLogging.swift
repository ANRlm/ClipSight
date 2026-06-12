import Foundation

public enum ClipSightLogging {
    public static let subsystem = "com.anrlm.ClipSight"

    public enum Category {
        public static let appLifecycle = "AppLifecycle"
        public static let permissions = "Permissions"
        public static let hotKey = "HotKey"
        public static let captureOCR = "CaptureOCR"
        public static let ocr = "OCR"
        public static let clipboard = "Clipboard"
        public static let hud = "HUD"
    }
}
