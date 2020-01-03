import Basic
import TezosGenCore
@testable import TezosGenGenerator

final class MockContractCodeGenerator: ContractCodeGenerating {
    var generateContractStub: ((AbsolutePath, Contract, String, [GeneratorExtension]) throws -> ())?
    var generateSharedContractStub: ((AbsolutePath, [GeneratorExtension]) throws -> ())?
    
    func generateContract(path: AbsolutePath, contract: Contract, contractName: String) throws {
        try generateContractStub?(path, contract, contractName, [])
    }
    
    func generateContract(path: AbsolutePath, contract: Contract, contractName: String, extensions: [GeneratorExtension]) throws {
        try generateContractStub?(path, contract, contractName, extensions)
    }
    
    func generateSharedContract(path: AbsolutePath) throws {
        try generateSharedContractStub?(path, [])
    }
    
    func generateSharedContract(path: AbsolutePath, extensions: [GeneratorExtension]) throws {
        try generateSharedContractStub?(path, extensions)
    }
}
