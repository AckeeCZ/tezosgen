import Foundation
import XCTest
import SPMUtility
@testable import TezosGenCoreTesting
@testable import TezosGenKit

class GenerateCommandTests: TezosGenUnitTestCase {
    private var subject: GenerateCommand!
    private var parser: ArgumentParser!
    
    override func setUp() {
        super.setUp()
        parser = ArgumentParser.test()
        subject = GenerateCommand(parser: parser)
    }
    
    func test_fails_when_contractFile_does_not_exist() throws {
        // Given
        let path = fileHandler.currentPath.appending(component: "file")
        let result = try parser.parse(["generate", "contract", path.pathString])
        
        // Then
        XCTAssertThrowsSpecific(try subject.run(with: result), GenerateError.fileNotFound(path))
    }
}

