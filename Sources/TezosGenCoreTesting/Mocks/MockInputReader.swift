import TezosGenCore
import class XcodeProj.PBXNativeTarget

private enum InputReaderError: Error {
    case enumNotStubbed
}

public final class MockInputReader: InputReading {
    public var readInputStringStub: (([String], String) throws -> String)?
    public var readPBXNativeTargetStub: (([PBXNativeTarget], String) throws -> PBXNativeTarget)?
    public var readEnumInputStub: (() throws -> String?)?
    private var stubs: [String: String] = [:]
    
    public func promptCommand(_ text: String, output: String) {
        stubs[text] = output
    }
    
    public func readInput<Option>(options: [Option], question: String) throws -> Option where Option : CustomStringConvertible, Option : Hashable {
        switch Option.self {
        case is PBXNativeTarget.Type:
            return (try readPBXNativeTargetStub?(options as! [PBXNativeTarget], question) ?? PBXNativeTarget(name: "")) as! Option
        case is String.Type:
            return (try readInputStringStub?(options as! [String], question) ?? "") as! Option
        default:
            fatalError("\(Option.self) for `readInput` has not been stubbed")
        }
    }
    
    public func readInput(options: [String], question: String) throws -> String {
        try readInputStringStub?(options, question) ?? ""
    }
    
    public func readInput(options: [PBXNativeTarget], question: String) throws -> PBXNativeTarget {
        try readPBXNativeTargetStub?(options, question) ?? PBXNativeTarget(name: "")
    }
    
    public func readEnumInput<EnumType>(question: String) throws -> EnumType where EnumType : CaseIterable, EnumType : RawRepresentable, EnumType.RawValue == String {
        guard
            let readEnumInputStub = try readEnumInputStub?(),
            let enumValue = EnumType(rawValue: readEnumInputStub)
        else { return try defaultEnumValue() }
        return enumValue
    }
    
    public func prompt(_ text: String, defaultValue: String?) -> String {
        return stubs[text] ?? defaultValue ?? ""
    }
    
    // MARK: - Helpers
    
    private func defaultEnumValue<EnumType>() throws -> EnumType where EnumType : CaseIterable {
        guard let defaultEnumValue = EnumType.allCases.first else { throw InputReaderError.enumNotStubbed }
        return defaultEnumValue
    }
}
