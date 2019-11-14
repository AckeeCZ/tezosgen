import Basic
import protocol TuistSupport.Command
import class TuistSupport.FileHandler
import class TuistSupport.Printer
import class TuistSupport.System
import Foundation
import SPMUtility
import TezosGenCore
import TezosGenGenerator
import TezosGenUtils
import XcodeProj
import PathKit


final class GenerateCommand: NSObject, Command {

    static var command: String = "generate"
    static var overview: String = "Generates Swift code for contract"

    private let contractNameArgument: PositionalArgument<String>
    private let fileArgument: PositionalArgument<String>
    private let outputArgument: OptionArgument<String>
    private let xcodeArgument: OptionArgument<String>
    private let contractCodeGenerator: ContractCodeGenerating

    convenience init(parser: ArgumentParser) {
        self.init(parser: parser,
                  contractCodeGenerator: ContractCodeGenerator())
    }
    
    init(parser: ArgumentParser,
         contractCodeGenerator: ContractCodeGenerating) {
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
        self.contractCodeGenerator = contractCodeGenerator
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

        let generatedSwiftCodePath: AbsolutePath = self.generatedSwiftCodePath(outputValue: arguments.get(outputArgument),
                                                                               xcodePath: arguments.get(xcodeArgument))

        try contractCodeGenerator.generateContract(path: generatedSwiftCodePath, contract: contract, contractName: contractName)
        try contractCodeGenerator.generateSharedContract(path: generatedSwiftCodePath)

        // Do not bind files when project or swift code path is not given
        guard
            let xcodePath = projectPath,
            let outputPathString = arguments.get(outputArgument)
        else { fatalError() }
        let outputPath = RelativePath(outputPathString)
        
        let targets = try XcodeProjectController.shared.targets(projectPath: xcodePath)
        let target = try chooseTargetIndex(from: targets)
        
        let contractPath = generatedSwiftCodePath.appending(component: contractName + ".swift")
        let sharedContractPath = generatedSwiftCodePath.appending(component: "SharedContract.swift")
        
        try XcodeProjectController.shared.addFilesAndGroups(xcodePath: xcodePath,
                                                            outputPath: outputPath,
                                                            files: [contractPath, sharedContractPath],
                                                            target: target)
    }
    
    private func generatedSwiftCodePath(outputValue: String?, xcodePath: String?) -> AbsolutePath {
        if let outputValue = outputValue {
            if let xcodePath = xcodePath {
                var xcodeComponents = xcodePath.components(separatedBy: "/")
                xcodeComponents.remove(at: xcodeComponents.endIndex - 1)
                return AbsolutePath(xcodeComponents.joined(separator: "/")).appending(RelativePath(outputValue))
            } else {
                return AbsolutePath(outputValue)
            }
        } else {
            return FileHandler.shared.currentPath.appending(component: "GeneratedContracts")
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
}

extension AbsolutePath {
    var path: Path {
        return Path(pathString)
    }
}
