import Foundation
import XCTest
import SPMUtility
import class XcodeProj.PBXNativeTarget
@testable import TezosGenCoreTesting
@testable import TezosGenGenerator
import TezosGenCore
@testable import TezosGenKit

class GenerateCommandTests: TezosGenUnitTestCase {
    private var subject: GenerateCommand!
    private var parser: ArgumentParser!
    private var contractCodeGenerator: MockContractCodeGenerator!
    
    override func setUp() {
        super.setUp()
        parser = ArgumentParser.test()
        contractCodeGenerator = MockContractCodeGenerator()
        subject = GenerateCommand(parser: parser,
                                  contractCodeGenerator: contractCodeGenerator)
    }
    
    func test_fails_when_contractFile_does_not_exist() throws {
        // Given
        let path = fileHandler.currentPath.appending(component: "file")
        let result = try parser.parse(["generate", "contract", path.pathString])
        
        // Then
        XCTAssertThrowsSpecific(try subject.run(with: result), GenerateError.fileNotFound(path))
    }
    
    func test_sharedContract_is_generatedWithCombine() throws {
        // Given
        let path = fileHandler.currentPath.appending(component: "file")
        let contractContent = """
        {"parameter":  {"prim":"set","args":[{"prim":"nat"}]}, "storage": {"prim":"set","args":[{"prim":"nat"}]}}
        """
        try fileHandler.write(contractContent, path: path, atomically: true)
        let xcodeprojPath = fileHandler.currentPath.appending(component: "test.xcodeproj")
        try fileHandler.createFolder(xcodeprojPath)
        let outputFile = "output_file"
        let result = try parser.parse(["generate", "contract", path.pathString, "-x", xcodeprojPath.pathString, "-o", outputFile,  "--extensions", "combine"])
        
        var receivedExtensions: [GeneratorExtension] = []
        contractCodeGenerator.generateSharedContractStub = { _, extensions in
            receivedExtensions = extensions
        }
        
        xcodeProjectController.targetsStub = { _ in
            [PBXNativeTarget(name: "")]
        }
        
        // When
        try subject.run(with: result)
        
        // Then
        XCTAssertEqual(receivedExtensions, [.combine])
    }
}

