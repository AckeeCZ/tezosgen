import Foundation
import XCTest
@testable import TezosGenCore

public class TezosGenUnitTestCase: TezosGenTestCase {
    public var system: MockSystem!
    public var fileHandler: MockFileHandler!
    public var xcodeProjectController: MockXcodeProjectController!

    public override func setUp() {
        super.setUp()
        // System
        system = MockSystem()
        System.shared = system

        // File handler
        // swiftlint:disable force_try
        fileHandler = try! MockFileHandler()
        FileHandler.shared = fileHandler
        
        // XcodeController
        xcodeProjectController = MockXcodeProjectController()
        XcodeProjectController.shared = xcodeProjectController
    }

    public override func tearDown() {
        // System
        system = nil
        System.shared = System()

        // File handler
        fileHandler = nil
        FileHandler.shared = FileHandler()
        
        // XcodeController
        xcodeProjectController = nil
        XcodeProjectController.shared = XcodeProjectController()

        super.tearDown()
    }
}
