import Basic
@testable import TezosGenCore
@testable import TezosGenGenerator

final class MockContractCodeGenerator: ContractCodeGenerating {
    var generateContractStub: ((AbsolutePath, Contract, String) throws -> ())?
    var generateSharedContractStub: ((AbsolutePath) throws -> ())?
    
    func generateContract(path: AbsolutePath, contract: Contract, contractName: String) throws {
        try generateContractStub?(path, contract, contractName)
    }
    
    func generateSharedContract(path: AbsolutePath) throws {
        try generateSharedContractStub?(path)
    }
}
