import Foundation

public struct Contract: Decodable {
    public let parameter: TezosElement
    public let storage: TezosElement

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
