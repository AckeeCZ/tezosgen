import Basic
import TezosGenCore
import class TuistSupport.FileHandler

public protocol ContractCodeGenerating {
    func generateContract(path: AbsolutePath, contract: Contract, contractName: String) throws
    func generateSharedContract(path: AbsolutePath) throws
}

public final class ContractCodeGenerator: ContractCodeGenerating {
    public init() { }
    
    public func generateContract(path: AbsolutePath, contract: Contract, contractName: String) throws {
        let params = contract.parameter.renderToSwift().enumerated().map { ($1.1 ?? "param\($0 + 1)") + ": \($1.0)" }.joined(separator: ", ")
        let args = contract.storage.renderToSwift().enumerated().map { ($1.1 ?? "let arg\($0 + 1)") + ": \($1.0)"}.joined(separator: "\n\t")
        let renderedInit = contract.parameter.renderInitToSwift()
        let initArgs = contract.storage.renderArgsToSwift().joined(separator: "\n\t\t")
        
        let key: String? = contract.storage.key

        let checks: String?
        if !renderedInit.1.isEmpty {
            checks = renderedInit.1.enumerated().map { "let tezosOr\($0 + 1) = \($1)" }.joined(separator: ", ")
        } else {
            checks = nil
        }
        
        if !FileHandler.shared.exists(path) {
            try FileHandler.shared.createFolder(path)
        }
        
        try generateContract(path: path,
                             contractName: contractName,
                             arguments: args,
                             storageType: contract.storage.generatedSwiftTypeString,
                             storageInternalType: contract.storage.generatedTypeString,
                             paramaterType: contract.parameter.generatedTypeString,
                             contractParams: params,
                             checks: checks,
                             contractInit: renderedInit.0,
                             contractInitArguments: initArgs,
                             isSimple: contract.storage.isSimple,
                             key: key)
    }
    
    public func generateSharedContract(path: AbsolutePath) throws {
        let contents = """
        // Generated using TezosGen

        import TezosSwift

        struct ContractMethodInvocation {
            private let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?

            init(send: @escaping (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?) {
                self.send = send
            }

            func send(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil, completion: @escaping RPCCompletion<String>) -> Cancelable? {
                self.send(from, amount, operationFees, completion)
            }
        }
        """
        
        let sharedContractPath = path.appending(component: "SharedContract.swift")
        try FileHandler.shared.write(contents, path: sharedContractPath, atomically: true)
    }
    
    private func generateContract(path: AbsolutePath,
                      contractName: String,
                      arguments: String,
                      storageType: String,
                      storageInternalType: String,
                      paramaterType: String?,
                      contractParams: String,
                      checks: String?,
                      contractInit: String,
                      contractInitArguments: String,
                      isSimple: Bool,
                      key: String?) throws {
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
        if let paramaterType = paramaterType {
            contents +=
            """
            
                
                /**
                 Call \(contractName) with specified params.
                 **Important:**
                 Params are in the order of how they are specified in the Tezos structure tree
                */
                func call(\(contractParams)) -> ContractMethodInvocation {
                    let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?
            """
            if let checks = checks {
                contents +=
                """
                    guard \(checks) else {
                        send = { from, amount, operationFees, completion in
                            completion(.failure(.parameterError(reason: .orError)))
                        }
                        return ContractMethodInvocation(send: send)
                    }
                """
            }
            contents +=
            """
                
                    let input: \(paramaterType) = \(contractInit)
                    send = { from, amount, operationFees, completion in
                        self.tezosClient.send(amount: amount, to: self.at, from: from, input: input, operationFees: operationFees, completion: completion)
                    }

                    return ContractMethodInvocation(send: send)
                }
            """
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
            func status(completion: @escaping RPCCompletion<
        """
        
        
        if storageType != "Void" {
            contents += """
            \(contractName)Status
            """
        } else {
            contents += """
            ContractStatus
            """
        }
        
        contents += """
        >) {
                let endpoint = "/chains/main/blocks/head/context/contracts/" + at
                return tezosClient.sendRPC(endpoint: endpoint, method: .get, completion: completion)
            }
        }
        """
        
        if storageType != "Void" {
            contents += """
            
            
            /// Status data of \(contractName)
            struct \(contractName)Status: Decodable {
                /// Balance of \(contractName) in Tezos
                let balance: Tez
                /// Is contract spendable
                let spendable: Bool
                /// \(contractName)'s manager address
                let manager: String
                /// \(contractName)'s delegate
                let delegate: StatusDelegate
                /// \(contractName)'s current operation counter
                let counter: Int
                /// \(contractName)'s storage
                let storage:
            """
            if isSimple {
                contents += """
                \(storageType)
                """
            } else {
                contents += """
                \(contractName)StatusStorage
                """
            }
            contents += """
            
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: ContractStatusKeys.self)
                    self.balance = try container.decode(Tez.self, forKey: .balance)
                    self.spendable = try container.decode(Bool.self, forKey: .spendable)
                    self.manager = try container.decode(String.self, forKey: .manager)
                    self.delegate = try container.decode(StatusDelegate.self, forKey: .delegate)
                    self.counter = try container.decodeRPC(Int.self, forKey: .counter)

                    let scriptContainer = try container.nestedContainer(keyedBy: ContractStatusKeys.self, forKey: .script)
            """
            if isSimple {
                if key == "set" || key == "list" {
                    contents += """
                    
                            self.storage = try scriptContainer.decodeRPC(\(storageType).self, forKey: .storage)
                    """
                } else if key == "map" || key == "big_map" {
                    contents += """
                    
                            self.storage = try scriptContainer.decode(\(storageInternalType).self, forKey: .storage).pairs.map { ($0.first, $0.second) }
                    """
                } else {
                    contents += """
                    
                            self.storage = try scriptContainer.nestedContainer(keyedBy: StorageKeys.self, forKey: .storage).decodeRPC(\(storageType)).self)
                    """
                }
            } else if key == nil {
                contents += """
                
                        self.storage = try scriptContainer.nestedContainer(keyedBy: StorageKeys.self, forKey: .storage).decodeRPC(\(storageType).self)
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
            
            if !isSimple {
                contents += """
                
                /**
                 \(contractName)'s storage with specified args.
                 **Important:**
                 Args are in the order of how they are specified in the Tezos structure tree
                */
                struct \(contractName)StatusStorage: Decodable {
                    \(arguments)

                    public init(from decoder: Decoder) throws {
                        let tezosElement = try decoder.singleValueContainer().decode(\(storageType).self)

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
