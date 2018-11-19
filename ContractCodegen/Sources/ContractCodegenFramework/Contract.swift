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
    case int
    case nat
    case pair
}

public class TezosElement: Decodable {
    public let name: String = ""
    public let type: TezosPrimaryType
    // TODO: Support optionals
    // public let optional: Bool
    public let first: TezosElement?
    public let second: TezosElement?

    enum CodingKeys: String, CodingKey {
        case prim
        case first
        case second
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TezosPrimaryType.self, forKey: .prim)
        self.first = try container.decodeIfPresent(TezosElement.self, forKey: .first)
        self.second = try container.decodeIfPresent(TezosElement.self, forKey: .second)
    }
}

extension TezosElement {
    public var generatedTypeString: String {
        switch type {
        case .int:
            return "Int"
        case .nat:
            return "UInt"
        case .pair:
            guard let first = first, let second = second else { return "" }
            return "TezosPair<\(first.generatedTypeString), \(second.generatedTypeString)>"
        }
    }

    private func renderPairElementToSwift(index: inout Int, renderedElements: inout [String]) {
        switch type {
        case .pair: renderElementToSwift(index: &index, renderedElements: &renderedElements)
        default:
            index += 1
            renderedElements.append(generatedTypeString)
        }
    }

    private func renderElementToSwift(index: inout Int, renderedElements: inout [String]) {
        switch type {
        case .pair:
            first?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements)
            second?.renderPairElementToSwift(index: &index, renderedElements: &renderedElements)
        default:
            index += 1
            renderedElements.append(generatedTypeString)
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
            first?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, suffix: "")
            renderedInit += ", second: "
            second?.renderInitPairElementToSwift(index: &index, renderedInit: &renderedInit, suffix: ")")
        default:
            index += 1
            renderedInit += renderSimpleInitToSwift(index: index, suffix: ")")
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
            first?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".first", args: &args)
            second?.renderArgInitElementToSwift(index: &index, currentlyRendered: currentlyRendered + ".second", args: &args)
        default:
            index += 1
            args.append("self.arg\(index) = \(currentlyRendered)")
        }
    }

    public func renderArgsToSwift() -> [String] {
        var index = 0
        var args: [String] = []
        renderArgInitElementToSwift(index: &index, currentlyRendered: "tezosElement", args: &args)
        return args
    }
}
