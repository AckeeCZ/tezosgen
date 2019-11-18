public class TezosElement: Decodable {
    public let name: String?
    public let type: TezosPrimaryType
    public let args: [TezosElement]

    enum CodingKeys: String, CodingKey {
        case prim
        case args
        case annots
    }
    
    public init(name: String? = nil,
                type: TezosPrimaryType,
                args: [TezosElement] = []) {
        self.name = name
        self.type = type
        self.args = args
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(TezosPrimaryType.self, forKey: .prim)
        switch type {
        case .pair, .or, .map:
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

        let annotations = try container.decodeIfPresent([String].self, forKey: .annots)
        name = annotations?.first?.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "%", with: "")
    }
}

extension TezosElement {
    public var generatedTypeString: String {
        switch type {
        case .unit:
            return "Void"
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
            // TODO: Contract with storage type
            return "String"
        case .keyHash:
            // TODO: Key hash type
            return "String"
        case .address:
            // TODO: Address type
            return "String"
        case .mutez:
            return "Mutez"
        case .pair:
            guard let first = args.first, let second = args.last else { return "" }
            return "TezosPair<\(first.generatedTypeString), \(second.generatedTypeString)>"
        case .or:
            guard let first = args.first, let second = args.last else { return "" }
            return "TezosOr<\(first.generatedTypeString), \(second.generatedTypeString)>"
        case .map:
            guard let first = args.first, let second = args.last else { return "" }
            return "TezosMap<\(first.generatedTypeString), \(second.generatedTypeString)>"
        case .bigMap:
            guard let first = args.first, let second = args.last else { return "" }
            return "TezosMap<\(first.generatedTypeString), \(second.generatedTypeString)>"
        case .option:
            guard let element = args.first else { return "" }
            return "\(element.generatedTypeString)?"
        case .list, .set:
            guard let element = args.first else { return "" }
            return "[\(element.generatedTypeString)]"
        }
    }

    public var generatedSwiftTypeString: String {
        switch type {
        case .map, .bigMap:
            guard let first = args.first, let second = args.last else { return "" }
            return "[(\(first.generatedTypeString), \(second.generatedTypeString))]"
        default:
            return generatedTypeString
        }

    }

    public var isSimple: Bool {
        switch type {
        case .option:
            return args.first?.type != .pair
        case .pair, .or:
            return false
        default:
            return true
        }
    }

    public var key: String? {
        switch type {
        case .keyHash, .contract:
            return TezosPrimaryType.string.rawValue
        case .option:
            return args.first?.type.rawValue
        default:
            return type.rawValue
        }
    }

    private func renderSimpleToSwift(index: Int, optional: Bool = false) -> (String, String?) {
        switch type {
        case .option:
            return (generatedTypeString, name)
        default:
            let suffix = optional ? "?" : ""
            return (generatedSwiftTypeString + suffix, name)
        }
    }

    private func renderPairElementToSwift(index: inout Int, renderedElements: inout [(String, String?)], optional: Bool) {
        switch type {
        case .pair: renderElementToSwift(index: &index, renderedElements: &renderedElements, optional: optional)
        case .option: args.first?.renderElementToSwift(index: &index, renderedElements: &renderedElements, optional: true)
        default:
            index += 1
            renderedElements.append(renderSimpleToSwift(index: index, optional: optional))
        }
    }

    private func renderElementToSwift(index: inout Int, renderedElements: inout [(String, String?)], optional: Bool = false) {
        switch type {
        case .pair:
            args.first?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements, optional: optional)
            args.last?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements, optional: optional)
        case .or:
            args.first?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements, optional: true)
            args.last?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements, optional: true)
        case .option:
            if args.first?.type == .pair || args.first?.type == .or {
                args.first?.args.first?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements, optional: true)
                args.first?.args.last?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements, optional: true)
            } else {
                index += 1
                renderedElements.append(renderSimpleToSwift(index: index))
            }
        default:
            index += 1
            renderedElements.append(renderSimpleToSwift(index: index, optional: optional))
        }
    }

    public func renderToSwift() -> [(String, String?)] {
        var index = 0
        var renderedElements: [(String, String?)] = []
        renderElementToSwift(index: &index, renderedElements: &renderedElements)
        return renderedElements
    }

    private func renderSimpleInitToSwift(index: Int, suffix: String) -> String {
        var paramName: String = name ?? "param\(index)"
        if type == .set {
            paramName += ".sorted()"
        }
        return paramName + suffix
    }

    private func renderInitPairElementToSwift(index: inout Int, renderedInit: inout String, orChecks: inout [String], suffix: String) {
        switch type {
        case .pair, .or: renderInitElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks)
        default:
            index += 1
            renderedInit += renderSimpleInitToSwift(index: index, suffix: suffix)
        }
    }

    private func renderInitElementToSwift(index: inout Int, renderedInit: inout String, orChecks: inout [String]) {
        switch type {
        case .pair:
            renderedInit += "TezosPair(first: "
            args.first?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks, suffix: "")
            renderedInit += ", second: "
            args.last?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks, suffix: ")")
        case .map:
            index += 1
            renderedInit += "TezosMap(pairs: param\(index).map { TezosPair(first: $0.0, second: $0.1) })"
        case .or:
            var orCheck = ""
            orCheck += "TezosOr(left: "
            args.first?.renderInitPairElementToSwift(index: &index, renderedInit: &orCheck, orChecks: &orChecks, suffix: "")
            orCheck += ", right: "
            args.last?.renderInitPairElementToSwift(index: &index, renderedInit: &orCheck, orChecks: &orChecks, suffix: ")")
            orChecks.append(orCheck)
            renderedInit += "tezosOr\(orChecks.count)"
        case .option:
            if args.first?.type == .or {
                renderedInit += "TezosOr(left: "
                args.first?.args.first?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks, suffix: "")
                renderedInit += ", right: "
                args.first?.args.last?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks, suffix: ")")
            }
            args.first?.renderInitElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks)
        default:
            index += 1
            renderedInit += renderSimpleInitToSwift(index: index, suffix: "")
        }
    }

    public func renderInitToSwift() -> (String, [String]) {
        var index = 0
        var renderedInit: String = ""
        var orChecks: [String] = []
        renderInitElementToSwift(index: &index, renderedInit: &renderedInit, orChecks: &orChecks)
        return (renderedInit, orChecks)
    }

    private func renderArgInitElementToSwift(index: inout Int, currentlyRendered: String, args: inout [String]) {
        switch type {
        case .pair:
            self.args.first?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".first", args: &args)
            self.args.last?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".second", args: &args)
        case .or:
            self.args.first?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".left", args: &args)
            self.args.last?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".right", args: &args)
        case .option:
            let arg = self.args.first
            if arg?.type == .pair {
                arg?.args.first?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + "?" + ".first", args: &args)
                arg?.args.last?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + "?" + ".second", args: &args)
            } else if arg?.type == .or {
                arg?.args.first?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + "?" + ".left", args: &args)
                arg?.args.last?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + "?" + ".right", args: &args)
            } else {
                index += 1
                let argName = name ?? "arg\(index)"
                args.append("self.\(argName) = \(currentlyRendered)")
            }
        case .set:
            index += 1
            let argName = name ?? "arg\(index)"
            args.append("self.\(argName) = \(currentlyRendered).sorted()")
        default:
            index += 1
            let argName = name ?? "arg\(index)"
            args.append("self.\(argName) = \(currentlyRendered)")
        }
    }

    public func renderArgsToSwift() -> [String] {
        var index = 0
        var args: [String] = []
        renderArgInitElementToSwift(index: &index, currentlyRendered: "tezosElement", args: &args)
        return args
    }
}
