import Foundation

public struct Contract: Decodable {
    let parameter: TezosElement
    let storage: TezosElement

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
        let storage = try values.decode(TezosElement.self, forKey: .storage)
        let parameter = try values.decode(TezosElement.self, forKey: .parameter)
        self.init(storage: storage, parameter: parameter)
    }
}

extension Contract {
    public func renderToSwift() -> [String] {
        let params = parameter.renderToSwift()
        return params
    }

    public func renderInitToSwift() -> String {
        return storage.renderInitToSwift()
    }

    public func renderArgsToSwift() -> [String] {
        return storage.renderArgsToSwift()
    }
}

public enum TezosPrimaryType: String, Codable {
    case string
    case int
    case nat
    case bool
    case bytes
    case set
    case list
    case pair
    case option
    case or
    case timestamp
    case tez
    case signature
    case key
    case contract
    case keyHash = "key_hash"
    case mutez
    case map
    case bigMap = "big_map"
}

public class TezosElement: Decodable {
    public let name: String = ""
    public let type: TezosPrimaryType
    public let args: [TezosElement]

    enum CodingKeys: String, CodingKey {
        case prim
        case args
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TezosPrimaryType.self, forKey: .prim)
        switch type {
        case .pair:
            var nestedContainer = try container.nestedUnkeyedContainer(forKey: .args)
            let first = try nestedContainer.decode(TezosElement.self)
            let second = try nestedContainer.decode(TezosElement.self)
            args = [first, second]
        case .list, .set, .option:
            var nestedContainer = try container.nestedUnkeyedContainer(forKey: .args)
            let element = try nestedContainer.decode(TezosElement.self)
            args = [element]
        default:
            args = []
        }
    }
}

extension TezosElement {
    public var generatedTypeString: String {
        switch type {
        case .string:
            return "String"
        case .int:
            return "Int"
        case .nat:
            return "UInt"
        case .bytes:
            return "Data"
        case .bool:
            return "Bool"
        case .timestamp:
            return "Date"
        case .tez:
            return "Tez"
        case .signature:
            // TODO: Signature type
            return "String"
        case .key:
            // TODO: Key type
            return "String"
        case .contract:
            // TODO: Contract with storace type
            return "String"
        case .keyHash:
            // TODO: Key hash type
            return "String"
        case .mutez:
            // TODO: Mutez!
            return "Tez"
        case .pair:
            guard let first = args.first, let second = args.last else { return "" }
            return "TezosPair<\(first.generatedTypeString), \(second.generatedTypeString)>"
        case .or:
            guard let first = args.first, let second = args.last else { return "" }
            return "(\(first.generatedTypeString)?, \(second.generatedTypeString)?)"
        case .map:
            // TODO
            guard let first = args.first, let second = args.last else { return "" }
            return "(\(first.generatedTypeString)?, \(second.generatedTypeString)?)"
        case .bigMap:
            // TODO
            guard let first = args.first, let second = args.last else { return "" }
            return "(\(first.generatedTypeString)?, \(second.generatedTypeString)?)"
        case .option:
            guard let element = args.first else { return "" }
            return "\(element.generatedTypeString)?"
        case .list:
            guard let element = args.first else { return "" }
            return "Array<\(element.generatedTypeString)>"
        case .set:
            guard let element = args.first else { return "" }
            return "Set<\(element.generatedTypeString)>"
        }
    }

    public var key: String? {
        switch type {
        case .option:
            return nil
        default:
            return type.rawValue
        }
    }

    private func renderSimpleToSwift(index: Int) -> String {
        return generatedTypeString
    }

    private func renderPairElementToSwift(index: inout Int, renderedElements: inout [String]) {
        switch type {
        case .pair: renderElementToSwift(index: &index, renderedElements: &renderedElements)
        default:
            index += 1
            renderedElements.append(renderSimpleToSwift(index: index))
        }
    }

    private func renderElementToSwift(index: inout Int, renderedElements: inout [String]) {
        switch type {
        case .pair:
            args.first?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements)
            args.last?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements)
        default:
            index += 1
            renderedElements.append(renderSimpleToSwift(index: index))
        }
    }

    public func renderToSwift() -> [String] {
        var index = 0
        var renderedElements: [String] = []
        renderElementToSwift(index: &index, renderedElements: &renderedElements)
        return renderedElements
    }

    private func renderSimpleInitToSwift(index: Int, suffix: String) -> String {
        return "param\(index)" + suffix
    }

    private func renderInitPairElementToSwift(index: inout Int, renderedInit: inout String, suffix: String) {
        switch type {
        case .pair: renderInitElementToSwift(index: &index, renderedInit: &renderedInit)
        default:
            index += 1
            renderedInit += renderSimpleInitToSwift(index: index, suffix: suffix)
        }
    }

    private func renderInitElementToSwift(index: inout Int, renderedInit: inout String) {
        switch type {
        case .pair:
            renderedInit += "TezosPair(first: "
            args.first?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, suffix: "")
            renderedInit += ", second: "
            args.last?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, suffix: ")")
        default:
            index += 1
            renderedInit += renderSimpleInitToSwift(index: index, suffix: "")
        }
    }

    public func renderInitToSwift() -> String {
        var index = 0
        var renderedInit: String = ""
        renderInitElementToSwift(index: &index, renderedInit: &renderedInit)
        return renderedInit
    }

    private func renderArgInitElementToSwift(index: inout Int, currentlyRendered: String, args: inout [String]) {
        switch type {
        case .pair:
            self.args.first?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".first", args: &args)
            self.args.last?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".second", args: &args)
        default:
            index += 1
            args.append("self.arg\(index) = \(currentlyRendered)")
        }
    }

    public func renderArgsToSwift() -> [String] {
        var index = 0
        var args: [String] = []
        renderArgInitElementToSwift(index: &index, currentlyRendered: "tezosPair", args: &args)
        return args
    }
}
