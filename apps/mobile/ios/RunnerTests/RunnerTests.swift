import Flutter
@testable import Runner
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testDeviceCalendarRegistrationSkipsAnUnavailableRegistrar() {
    var didRegister = false

    VinscentDeviceCalendarBridgeRegistration.register(
      with: nil,
      registerBridge: { _ in didRegister = true }
    )

    XCTAssertFalse(didRegister)
  }

}
