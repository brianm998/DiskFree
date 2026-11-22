import Foundation

/// Detects whether the app process is hosting an XCTest bundle.
enum TestHost {
    static let environmentKeys = ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"]

    static func isTestHost(environment: [String: String]) -> Bool {
        environmentKeys.contains { environment[$0] != nil }
    }

    static var isActive: Bool {
        isTestHost(environment: ProcessInfo.processInfo.environment)
    }
}
