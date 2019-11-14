import Basic
import protocol TuistSupport.Command
import class TuistSupport.FileHandler
import class TuistSupport.Printer
import class TuistSupport.System
import Foundation
import SPMUtility
import TezosGenCore
import XcodeProj
import PathKit


final class GenerateCommand: NSObject, Command {

    static var command: String = "generate"
    static var overview: String = "Generates Swift code for contract"

    let contractNameArgument: PositionalArgument<String>
    let fileArgument: PositionalArgument<String>
    let outputArgument: OptionArgument<String>
    let xcodeArgument: OptionArgument<String>
    var executableLocation = FileHandler.shared.currentPath

    required init(parser: ArgumentParser) {
        let subParser = parser.add(subparser: GenerateCommand.command, overview: GenerateCommand.overview)
        
        contractNameArgument = subParser.add(positional: "contract name", kind: String.self)
        fileArgument = subParser.add(positional: "file", kind: String.self)
        outputArgument = subParser.add(option: "--output",
                                       shortName: "-o",
                                       kind: String.self,
                                       usage: "Define output directory",
                                       completion: .filename)
        xcodeArgument = subParser.add(option: "--xcode",
                                      shortName: "-x",
                                      kind: String.self,
                                      usage: "Define location of .xcodeproj",
                                      completion: .filename)
    }

    func run(with arguments: ArgumentParser.Result) throws {
        guard let file = arguments.get(fileArgument) else { return }
        guard let contractName = arguments.get(contractNameArgument) else { fatalError() }
        // TODO: Fix for relative
        let filePath = AbsolutePath(file)
        guard FileHandler.shared.exists(filePath) else {
            Printer.shared.print(error: "File at given path does not exist.")
            return
        }

        let contract: Contract

        do {
            guard let abiData: Data = try FileHandler.shared.readTextFile(filePath).data(using: .utf8) else { return }
            contract = try JSONDecoder().decode(Contract.self, from: abiData)
        } catch {
            Printer.shared.print(error: "ABI JSON decode error! ⛔️")
            return
        }

        var projectPath: AbsolutePath?
        if let projectPathString = arguments.get(xcodeArgument) {
            projectPath = AbsolutePath(projectPathString)
        }

        var generatedSwiftCodePath: AbsolutePath?

        if let outputValue = arguments.get(outputArgument) {
            if let xcodePath = arguments.get(xcodeArgument) {
                var xcodeComponents = xcodePath.components(separatedBy: "/")
                xcodeComponents.remove(at: xcodeComponents.endIndex - 1)
                generatedSwiftCodePath = AbsolutePath(xcodeComponents.joined(separator: "/")).appending(RelativePath(outputValue))
            } else {
                generatedSwiftCodePath = AbsolutePath(outputValue)
            }
        }

        writeGeneratedCode(to: generatedSwiftCodePath, contract: contract, contractName: contractName)

        // Do not bind files when project or swift code path is not given
        guard
            let xcodePath = projectPath,
            let swiftCodePath = generatedSwiftCodePath,
            let relativePathValue = arguments.get(outputArgument)
        else { return }
        try bindFilesWithProject(xcodePath: xcodePath, swiftCodePath: swiftCodePath, relativePathValue: relativePathValue)
    }

    /// Writes and renders code from .stencil files to a given directory
    private func writeGeneratedCode(to path: AbsolutePath?, contract: Contract, contractName: String) {

        let swiftCodePath = path ?? (FileHandler.shared.currentPath.appending(component: "GeneratedConctracts"))

        let params = contract.parameter.renderToSwift().enumerated().map { ($1.1 ?? "param\($0 + 1)") + ": \($1.0)" }.joined(separator: ", ")
        let args = contract.storage.renderToSwift().enumerated().map { ($1.1 ?? "let arg\($0 + 1)") + ": \($1.0)"}.joined(separator: "\n\t")
        let renderedInit = contract.parameter.renderInitToSwift()
        let initArgs = contract.storage.renderArgsToSwift().joined(separator: "\n\t\t")
        
//        var contractDict: [String: Any] = ["params": params, "args": args, "storage_type": contract.storage.generatedSwiftTypeString, "storage_internal_type": contract.storage.generatedTypeString, "parameter_type": contract.parameter.generatedTypeString, "init": renderedInit.0, "init_args": initArgs, "simple": contract.storage.isSimple]
        let key: String?
        if let keyString = contract.storage.key {
            key = keyString
        } else {
            key = nil
        }

        let checks: String?
        if !renderedInit.1.isEmpty {
            checks = renderedInit.1.enumerated().map { "let tezosOr\($0 + 1) = \($1)" }.joined(separator: ", ")
        } else {
            checks = nil
        }

        do {
            if !FileHandler.shared.exists(swiftCodePath) {
                try FileManager.default.createDirectory(atPath: "\(swiftCodePath.pathString)", withIntermediateDirectories: true, attributes: nil)
            }

            try createSharedContract(path: swiftCodePath)
            
            try generateFile(path: swiftCodePath,
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
        } catch {
            Printer.shared.print(error: "Write Error! 😱")
            return
        }
    }
    
    private func chooseTargetIndex(from targets: [PBXNativeTarget]) throws -> PBXNativeTarget {
        // Prints targets as a list so user can choose with which one they want to bind their files
        for (index, target) in targets.enumerated() {
            print("\(index + 1). " + target.name)
        }
        
        Printer.shared.print("Choose target for the generated contract code:")
        guard
            let intString = readLine(),
            let index = Int(intString),
            index > 0 && index <= targets.count
        else {
            Printer.shared.print(error: "Input is invalid; must be a number between 1 and \(targets.count)")
            fatalError()
        }
        
        return targets[index - 1]
    }

    /// Binds file references with project, adds files to target
    private func bindFilesWithProject(xcodePath: AbsolutePath, swiftCodePath: AbsolutePath, relativePathValue: String) throws {
        let xcodeproj = try XcodeProj(pathString: xcodePath.pathString)
        let relativePathComponents = relativePathValue.components(separatedBy: "/")
        
        let outputGroup: PBXGroup? = try relativePathComponents.reduce(into: nil, { result, name in
            if let group = xcodeproj.pbxproj.groups.first(where: { $0.path == name }) {
                result = group
                return
            }

            result = try result?.addGroup(named: name).first
        })
        
        let rootPath = xcodePath.removingLastComponent()
        
        try outputGroup?.addFile(at: "HelloContract.swift", sourceRoot: xcodePath.removingLastComponent().path)
        try xcodeproj.write(path: Path(xcodePath.pathString))
    }
    
    private func createSharedContract(path: AbsolutePath) throws {
        let contents = """
        // Generated using TezosGen

        import TezosSwift

        struct ContractMethodInvocation {
            private let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Void

            init(send: @escaping (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Void) {
                self.send = send
            }

            func send(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil, completion: @escaping RPCCompletion<String>) {
                self.send(from, amount, operationFees, completion)
            }
        }
        """
        
        let sharedContractPath = path.appending(component: "SharedContract.swift")
        try FileHandler.shared.write(contents, path: sharedContractPath, atomically: true)
    }

    func generateFile(path: AbsolutePath,
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
                func call(\(contractParams) -> ContractMethodInvocation {
                    let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Void
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
                    let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Void = { from, amount, operationFees, completion in
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
                tezosClient.sendRPC(endpoint: endpoint, method: .get, completion: completion)
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
            func \(contractName.lowercased())(at: String) -> \(contractName)Box {
                return \(contractName)Box(tezosClient: self, at: at)
            }
        }
        """
        
        let contractPath = FileHandler.shared.currentPath.appending(component: contractName + ".swift")
        try FileHandler.shared.write(contents, path: contractPath, atomically: true)
    }
}

extension AbsolutePath {
    var path: Path {
        return Path(pathString)
    }
}
