import Basic
import XCTest
import TezosGenCore
@testable import TezosGenCoreTesting
@testable import TezosGenGenerator

final class ContractCodeGeneratorTests: TezosGenUnitTestCase {
    var subject: ContractCodeGenerator!
    
    override func setUp() {
        super.setUp()
        
        subject = ContractCodeGenerator()
    }
    
    func test_shared_contract_is_generated() throws {
        // When
        try subject.generateSharedContract(path: fileHandler.currentPath)
        
        // Then
        XCTAssertMultilineEqual(try fileHandler.readTextFile(fileHandler.currentPath.appending(component: "SharedContract.swift")), multiline: """
        // Generated using TezosGen

        import TezosSwift

        struct ContractMethodInvocation {
            private let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?

            init(send: @escaping (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?) {
                self.send = send
            }

            @discardableResult
            func send(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil, completion: @escaping RPCCompletion<String>) -> Cancelable? {
                self.send(from, amount, operationFees, completion)
            }
        }
        
        """)
    }
    
    func test_shared_contract_is_generated_with_combine() throws {
        // When
        try subject.generateSharedContract(path: fileHandler.currentPath, extensions: [.combine])
        
        // Then
        XCTAssertMultilineEqual(try fileHandler.readTextFile(fileHandler.currentPath.appending(component: "SharedContract.swift")), multiline: """
        // Generated using TezosGen

        import TezosSwift
        import Combine

        struct ContractMethodInvocation {
            private let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?

            init(send: @escaping (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?) {
                self.send = send
            }

            @discardableResult
            func send(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil, completion: @escaping RPCCompletion<String>) -> Cancelable? {
                self.send(from, amount, operationFees, completion)
            }
            
            func sendPublisher(from: Wallet, amount: TezToken, operationFees: OperationFees? = nil) -> ContractPublisher<String> {
                ContractPublisher(send: { self.send(from, amount, operationFees, $0) })
            }
        }
        
        """)
    }
    
    func test_contract_is_generated() throws {
        // Given
        let contract = Contract(calls: [ContractCall(parameter: TezosElement(type: .set, args: [TezosElement(type: .nat)]))], storage: TezosElement(type: .set, args: [TezosElement(type: .nat)]))
        let contractName = "HelloContract"
        let contractPath = fileHandler.currentPath.appending(component: contractName + ".swift")
        
        // When
        try subject.generateContract(path: fileHandler.currentPath, contract: contract, contractName: contractName)
        
        // Then
        XCTAssertMultilineEqual(try fileHandler.readTextFile(contractPath), multiline: """
        // Generated using TezosGen
        // swiftlint:disable file_length

        import Foundation
        import TezosSwift

        /// Struct for function currying
        struct HelloContractBox {
            fileprivate let tezosClient: TezosClient
            fileprivate let at: String

            fileprivate init(tezosClient: TezosClient, at: String) {
               self.tezosClient = tezosClient
               self.at = at
            }
            /**
             Call HelloContract with specified params.
             **Important:**
             Params are in the order of how they are specified in the Tezos structure tree
            */
            func call(_ param1: [UInt]) -> ContractMethodInvocation {
                let send: (_ from: Wallet, _ amount: TezToken, _ operationFees: OperationFees?, _ completion: @escaping RPCCompletion<String>) -> Cancelable?
                let input: [UInt] = param1.sorted()
                send = { from, amount, operationFees, completion in
                    self.tezosClient.send(amount: amount, to: self.at, from: from, input: input, operationFees: operationFees, completion: completion)
                }

                return ContractMethodInvocation(send: send)
            }

            /// Call this method to obtain contract status data
            @discardableResult
            func status(completion: @escaping RPCCompletion<HelloContractStatus>) -> Cancelable? {
                let endpoint = "/chains/main/blocks/head/context/contracts/" + at
                return tezosClient.sendRPC(endpoint: endpoint, method: .get, completion: completion)
            }
        }

        /// Status data of HelloContract
        struct HelloContractStatus: Decodable {
            /// HelloContract's storage
            let storage: [UInt]

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: ContractStatusKeys.self)
                let scriptContainer = try container.nestedContainer(keyedBy: ContractStatusKeys.self, forKey: .script)
                self.storage = try scriptContainer.decodeRPC([UInt].self, forKey: .storage)
            }
        }

        extension TezosClient {
            /**
             This function returns type that you can then use to call HelloContract specified by address.

             - Parameter at: String description of desired address.

             - Returns: Callable type to send Tezos with.
            */
            func helloContract(at: String) -> HelloContractBox {
                return HelloContractBox(tezosClient: self, at: at)
            }
        }
        """)
    }
}
