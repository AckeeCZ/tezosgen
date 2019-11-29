import Foundation

public struct ContractCall: Decodable {
    public let name: String?
    public let parameter: TezosElement
    
    init(name: String? = nil, parameter: TezosElement) {
        self.name = name
        self.parameter = parameter
    }
}

/// Type to decode `[ContractCall]` which is encapsulated in a nested `or` michelson types
private struct ContractCalls: Decodable {
    let calls: [ContractCall]
    
    private enum CodingKeys: String, CodingKey {
        case prim
        case args
        case annots
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type: TezosPrimaryType = try container.decode(TezosPrimaryType.self, forKey: .prim)
        switch type {
        case .or:
            var nestedContainer = try container.nestedUnkeyedContainer(forKey: .args)
            let first = try nestedContainer.decode(ContractCalls.self)
            let second = try nestedContainer.decode(ContractCalls.self)
            calls = first.calls + second.calls
        default:
            let annotations = try container.decodeIfPresent([String].self, forKey: .annots)
            let name = annotations?.first?.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "%", with: "")
            var parameter = try TezosElement(from: decoder)
            // Rewrite `.name` since it belongs to the contract
            parameter.name = nil
            calls = [ContractCall(name: name, parameter: parameter)]
        }
    }
}

public struct Contract: Decodable {
    public let calls: [ContractCall]
    public let storage: TezosElement

    enum CodingKeys: String, CodingKey {
        case storage
        case parameter
        case args
        case prim
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let values = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .parameter)
        let type: TezosPrimaryType = try values.decode(TezosPrimaryType.self, forKey: .prim)
        switch type {
        case .or:
            var args = try values.nestedUnkeyedContainer(forKey: .args)
            calls = try args.decode(ContractCalls.self).calls + (try args.decode(ContractCalls.self).calls)
        default:
            let parameter = try container.decode(TezosElement.self, forKey: .parameter)
            calls = [ContractCall(parameter: parameter)]
        }
        storage = try container.decode(TezosElement.self, forKey: .storage)
    }
}
