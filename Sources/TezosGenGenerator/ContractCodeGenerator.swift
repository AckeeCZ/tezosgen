import Basic
import TezosGenCore
import class TuistSupport.FileHandler

public protocol ContractCodeGenerating {
    func generateContract(path: AbsolutePath, contract: Contract, contractName: String, extensions: [GeneratorExtension]) throws
    func generateContract(path: AbsolutePath, contract: Contract, contractName: String) throws
    func generateSharedContract(path: AbsolutePath, extensions: [GeneratorExtension]) throws
    func generateSharedContract(path: AbsolutePath) throws
}

// swiftlint:disable line_length
// swiftlint:disable:next type_body_length
public final class ContractCodeGenerator: ContractCodeGenerating {
    public init() { }
    
    public func generateContract(path: AbsolutePath, contract: Contract, contractName: String) throws {
        try generateContract(path: path, contract: contract, contractName: contractName, extensions: [])
    }
    
    public func generateContract(path: AbsolutePath, contract: Contract, contractName: String, extensions: [GeneratorExtension]) throws {
        if !FileHandler.shared.exists(path) {
            try FileHandler.shared.createFolder(path)
        }
        
        try generateContractCode(path: path,
                                 contractName: contractName,
                                 contract: contract,
                                 extensions: extensions)
    }
    
    public func generateSharedContract(path: AbsolutePath) throws {
        try generateSharedContract(path: path, extensions: [])
    }
    
    public func generateSharedContract(path: AbsolutePath, extensions: [GeneratorExtension]) throws {
        let importExtensionContents = extensions.reduce("") { content, currentExtension in
            switch currentExtension {
            case .combine:
                return content + "\nimport Combine"
            }
        }
        
        let additionalFunctionContents = extensions.reduce("") { content, currentExtension in
            switch currentExtension {
            case .combine:
                return content + """
                
                    
                    func sendPublisher(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil) -> ContractPublisher<String> {
                        ContractPublisher(send: { self.send(from, amount, operationFees, $0) })
                    }
                """
            }
        }
        let contents = """
        // Generated using TezosGen

        import TezosSwift\(importExtensionContents)

        struct ContractMethodInvocation {
            private let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?

            init(send: @escaping (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?) {
                self.send = send
            }

            @discardableResult
            func send(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil, completion: @escaping RPCCompletion<String>) -> Cancelable? {
                self.send(from, amount, operationFees, completion)
            }\(additionalFunctionContents)
        }
        
        """
        
        let sharedContractPath = path.appending(component: "SharedContract.swift")
        try FileHandler.shared.write(contents, path: sharedContractPath, atomically: true)
    }
    
    // MARK: - Helpers
    
    private func generateContractCall(contractName: String,
                                      contractCall: ContractCall) -> String {
        
        let contractParams = contractCall.parameter.renderToSwift()
            .filter { $0.0 != "Never?" }
            .enumerated()
            .map {
                ($1.1 ?? "param\($0 + 1)") + ": \($1.0)"
            }
        let contractParamsString: String
        if contractParams.count == 1 {
            contractParamsString = "_ " + contractParams.joined(separator: ", ")
        } else {
            contractParamsString = contractParams.joined(separator: ", ")
        }
        let contractInit = contractCall.parameter.renderInitToSwift()
        let parameterType = contractCall.parameter.generatedTypeString

        let checks: String?
        if !contractInit.1.isEmpty {
            checks = contractInit.1.enumerated().map { "let tezosOr\($0 + 1) = \($1)" }.joined(separator: ", ")
        } else {
            checks = nil
        }
        
        var contents =
        """
        
            /**
             Call \(contractName) with specified params.
             **Important:**
             Params are in the order of how they are specified in the Tezos structure tree
            */
            func \(contractCall.name ?? "call")(\(contractParamsString)) -> ContractMethodInvocation {
                let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?
        """
        if let checks = checks {
            contents +=
            """
                
                    guard \(checks) else {
                        send = { from, amount, operationFees, completion in
                            completion(.failure(.parameterError(reason: .orError)))
                            return AnyCancelable { }
                        }
                        return ContractMethodInvocation(send: send)
                    }
            """
        }
        if contractParams.isEmpty {
            contents +=
            """
            
                    send = { from, amount, operationFees, completion in
                        self.tezosClient.send(amount: amount, to: self.at, from: from, operationFees: operationFees, completion: completion)
                    }

                    return ContractMethodInvocation(send: send)
                }
            """
        } else {
            contents +=
            """
            
                    let input: \(parameterType) = \(contractInit.0)
                    send = { from, amount, operationFees, completion in
                        self.tezosClient.send(amount: amount, to: self.at, from: from, input: input, operationFees: operationFees, completion: completion)
                    }

                    return ContractMethodInvocation(send: send)
                }
            """
        }
        
        return contents
    }
    
    // swiftlint:disable:next function_body_length
    private func generateContractCode(path: AbsolutePath,
                                  contractName: String,
                                  contract: Contract,
                                  extensions: [GeneratorExtension]) throws {
        var contents = """
        // Generated using TezosGen
        // swiftlint:disable file_length

        import Foundation
        import TezosSwift

        /// Struct for function currying
        struct \(contractName)Box {
            fileprivate let tezosClient: TezosClient
            fileprivate let at: String

            fileprivate init(tezosClient: TezosClient, at: String) {
               self.tezosClient = tezosClient
               self.at = at
            }
        """
        if !contract.calls.isEmpty {
            contents += contract.calls
                .map {
                    generateContractCall(contractName: contractName,
                                        contractCall: $0)
                }.joined(separator: "\n")
        } else {
            contents +=
            """
                func call() -> ContractMethodInvocation {
                    let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable? = { from, amount, operationFees, completion in
                        self.tezosClient.send(amount: amount, to: self.at, from: from, operationFees: operationFees, completion: completion)
                    }
                }
            """
        }
        contents +=
        """
        
        
            /// Call this method to obtain contract status data
            @discardableResult
            func status(completion: @escaping RPCCompletion<
        """
        
        let contractStatusType: String
        if contract.storage.type != .unit {
            contractStatusType = "\(contractName)Status"
        } else {
            contractStatusType = "ContractStatus"
        }
        
        contents += contractStatusType
        
        contents += """
        >) -> Cancelable? {
                let endpoint = "/chains/main/blocks/head/context/contracts/" + at
                return tezosClient.sendRPC(endpoint: endpoint, method: .get, completion: completion)
            }
        """
        
        extensions.forEach {
            switch $0 {
            case .combine:
                contents += """
                
                
                    /// Call this method to obtain contract status data
                    func statusPublisher() -> ContractPublisher<\(contractStatusType)> {
                        ContractPublisher(send: { self.status(completion: $0) })
                    }
                """
            }
        }
        
        contents += """
        
        }
        """
        
        if contract.storage.type != .unit {
            contents += """
            
            
            /// Status data of \(contractName)
            struct \(contractName)Status: Decodable {
                /// \(contractName)'s storage
                let storage: 
            """
            if contract.storage.isSimple {
                contents += """
                \(contract.storage.generatedSwiftTypeString)
                """
            } else {
                contents += """
                \(contractName)StatusStorage
                """
            }
            contents += """
            
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: ContractStatusKeys.self)
                    let scriptContainer = try container.nestedContainer(keyedBy: ContractStatusKeys.self, forKey: .script)
            """
            if contract.storage.isSimple {
                switch contract.storage.type {
                case .set, .list:
                    contents += """
                    
                            self.storage = try scriptContainer.decodeRPC(\(contract.storage.generatedSwiftTypeString).self, forKey: .storage)
                    """
                case .map, .bigMap:
                    contents += """
                    
                            self.storage = try scriptContainer.decode(\(contract.storage.generatedTypeString).self, forKey: .storage).pairs.reduce([:], { var mutable = $0; mutable[$1.first] = $1.second; return mutable })
                    """
                default:
                    contents += """
                    
                            self.storage = try scriptContainer.nestedContainer(keyedBy: StorageKeys.self, forKey: .storage).decodeRPC(\(contract.storage.generatedSwiftTypeString).self)
                    """
                }
            } else if contract.storage.key == nil {
                contents += """
                
                        self.storage = try scriptContainer.nestedContainer(keyedBy: StorageKeys.self, forKey: .storage).decodeRPC(\(contract.storage.generatedSwiftTypeString).self)
                """
            } else {
                contents += """
                
                        self.storage = try scriptContainer.decode(\(contractName)StatusStorage.self, forKey: .storage)
                """
            }
            contents += """
            
                }
            }
            """
            
            let arguments = contract.storage.renderToSwift().enumerated().map { "let " + ($1.1 ?? "arg\($0 + 1)") + ": \($1.0)"}.joined(separator: "\n\t")
            let contractInitArguments = contract.storage.renderArgsToSwift().joined(separator: "\n\t\t")
            
            if !contract.storage.isSimple {
                contents += """
                
                /**
                 \(contractName)'s storage with specified args.
                 **Important:**
                 Args are in the order of how they are specified in the Tezos structure tree
                */
                struct \(contractName)StatusStorage: Decodable {
                    \(arguments)

                    public init(from decoder: Decoder) throws {
                """
                
                switch contract.storage.type {
                case .option:
                    contents += """
                            
                            let container = try decoder.container(keyedBy: StorageKeys.self)
                            var nestedContainer = try? container.nestedUnkeyedContainer(forKey: .args)
                            let tezosElement = try nestedContainer?.decode(\(contract.storage.generatedSwiftTypeString).self)
                    """
                default:
                    contents += """
                    
                            let tezosElement = try decoder.singleValueContainer().decode(\(contract.storage.generatedSwiftTypeString).self)
                    """
                }
                contents += """
                
                        \(contractInitArguments)
                    }
                }
                """
            }
        }
        
        contents += """
        
        
        extension TezosClient {
            /**
             This function returns type that you can then use to call \(contractName) specified by address.

             - Parameter at: String description of desired address.

             - Returns: Callable type to send Tezos with.
            */
            func \(contractName.prefix(1).lowercased() + contractName.dropFirst())(at: String) -> \(contractName)Box {
                return \(contractName)Box(tezosClient: self, at: at)
            }
        }
        """
        
        let contractPath = path.appending(component: contractName + ".swift")
        try FileHandler.shared.write(contents, path: contractPath, atomically: true)
    }
}
