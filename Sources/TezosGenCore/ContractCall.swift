public struct ContractCall: Decodable {
    public let name: String?
    public let parameter: TezosElement
    
    public init(name: String? = nil, parameter: TezosElement) {
        self.name = name
        self.parameter = parameter
    }
}
