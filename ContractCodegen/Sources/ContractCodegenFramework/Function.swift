public struct Function: Decodable {

    let parameter: TezosElement
    let storage: TezosElement

    public struct TezosElement {
        public let name: String = ""
        public let type: TezosType
        // TODO: Support optionals
        // public let optional: Bool
    }

    public enum TezosType {
        case int
        case nat
        case pair(first: ParameterType, second: ParameterType)
    }

    enum CodingKeys: String, CodingKey {
        case storage
        case parameter
    }

    public init(storage: TezosElement, parameter: TezosElement) {
        self.storage = storage
        self.parameter = parameter
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let storage = try values.decode(TezosType.self, forKey: .storage)
        let parameter = try values.decode(TezosType.self, forKey: .parameter)
        self.init(storage: storage, parameter: parameter)
    }
}

extension TezosElement: Decodable {
    enum CodingKeys: String, CodingKey {
        case prim
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //var name = try values.decode(String.self, forKey: .name)
        let type = try container.decode(TezosType.self, forKey: .prim)
        let typeString = try values.decode(String.self, forKey: .type)
        self.init(type: type)
    }
}

// MARK: Render to swift
extension Function.TezosElement {
    public var generatedTypeString: String {
        switch type {
        case .int:
            return "Int"
        case .nat:
            return "UInt"
        case .pair(let first, let second):
            return "TezosPair<\(first.generatedTypeString), \(second.generatedTypeString)>"
        }
    }
}

extension Function.ParameterType.DynamicType {
    var generatedTypeString: String {
        let nonPrefixedTypeString: String
        switch self {
        case .bytes:
            nonPrefixedTypeString = "Data"
        case .string:
            nonPrefixedTypeString = "String"
        case .array(let type):
            let innerType = type.generatedTypeString
            nonPrefixedTypeString = "Array<\(innerType)>"
        }
        return nonPrefixedTypeString
    }
}

extension Function.ParameterType.DynamicType {
    func abiTypeString(value: String) -> String {
        let abiString: String
        switch self {
        case .bytes:
            abiString = ".bytes(count: .unlimited, value: \(value))"
        case .string:
            abiString = ".string(value: \(value))"
        case .array(let type):
            abiString = ".array(count: .unlimited, type: \(type.abiTypeString), value: \(value))"
        }
        return abiString
    }
}

extension Function.Output {
    public func renderToSwift() -> String {
        return name + ": " + type.generatedTypeString
    }
}

extension Function.Input {
    public func renderToSwift(index: Int) -> String {
        return "param\(index)" + ": " + type.generatedTypeString
//        return name + ": " + type.generatedTypeString
    }
}

extension Function {
    public func renderToSwift() -> String {
        let params = inputs.enumerated().map { $1.renderToSwift(index: $0) }.joined(separator: ",")
        let returnType = outputs.map { $0.renderToSwift() }.joined(separator: ",")

        return """
        func \(name)(\(params)) -> (\(returnType))
        """
    }
}
