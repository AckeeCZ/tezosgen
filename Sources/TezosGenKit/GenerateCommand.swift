import Foundation
import Basic
import protocol TuistSupport.Command
import protocol TuistSupport.FatalError
import enum TuistSupport.ErrorType
import SPMUtility
import TezosGenCore
import TezosGenGenerator
import class XcodeProj.PBXNativeTarget

enum GenerateError: FatalError, Equatable {
    case fileNotFound(AbsolutePath)
    case argumentNotProvided(String)
    case contractDecodeFailed(AbsolutePath)
    case xcodeProjectNotFound(AbsolutePath)
    case invalidIndex(Int)
    case noTargetsFound(AbsolutePath)
    case targetNotFound(String)
    
    var description: String {
        switch self {
        case let .fileNotFound(path):
            return "Contract file not found at \(path.pathString)"
        case let .argumentNotProvided(argument):
            return "\(argument) argument not provided"
        case let .contractDecodeFailed(path):
            return "Failed to decode contract at \(path.pathString)"
        case let .xcodeProjectNotFound(path):
            return "Could not find Xcode project at \(path.pathString)"
        case let .invalidIndex(count):
            return "Input is invalid; must be a number between 1 and \(count)"
        case let .noTargetsFound(path):
            return "No targets found for project at \(path.pathString)"
        case let .targetNotFound(target):
            return "Could not find target with name \(target)"
        }
    }
    
    var type: ErrorType { .abort }
    
    static func == (lhs: GenerateError, rhs: GenerateError) -> Bool {
        switch (lhs, rhs) {
        case let (.fileNotFound(lhsPath), .fileNotFound(rhsPath)):
            return lhsPath == rhsPath
        case let (.argumentNotProvided(lhsArg), .argumentNotProvided(rhsArg)):
            return lhsArg == rhsArg
        case let (.contractDecodeFailed(lhsPath), .contractDecodeFailed(rhsPath)):
            return lhsPath == rhsPath
        case let (.xcodeProjectNotFound(lhsPath), .xcodeProjectNotFound(rhsPath)):
            return lhsPath == rhsPath
        case let (.invalidIndex(lhsCount), .invalidIndex(rhsCount)):
            return lhsCount == rhsCount
        case let (.noTargetsFound(lhsPath), .noTargetsFound(rhsPath)):
            return lhsPath == rhsPath
        default:
            return false
        }
    }
}

final class GenerateCommand: NSObject, Command {

    static var command: String = "generate"
    static var overview: String = "Generates Swift code for contract"

    private let contractNameArgument: PositionalArgument<String>
    private let fileArgument: PositionalArgument<String>
    private let outputArgument: OptionArgument<String>
    private let xcodeArgument: OptionArgument<String>
    private let extensionsArgument: OptionArgument<[GeneratorExtension]>
    private let targetArgument: OptionArgument<String>
    private let contractCodeGenerator: ContractCodeGenerating

    convenience init(parser: ArgumentParser) {
        self.init(parser: parser,
                  contractCodeGenerator: ContractCodeGenerator())
    }
    
    init(parser: ArgumentParser,
         contractCodeGenerator: ContractCodeGenerating) {
        let subParser = parser.add(subparser: GenerateCommand.command, overview: GenerateCommand.overview)
        
        contractNameArgument = subParser.add(positional: "contract name", kind: String.self)
        fileArgument = subParser.add(positional: "contract file",
                                     kind: String.self,
                                     completion: .filename)
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
        extensionsArgument = subParser.add(option: "--extensions",
                                            shortName: "-e",
                                            kind: [GeneratorExtension].self,
                                            strategy: .upToNextOption,
                                            usage: "Define extensions for the generated code")
        targetArgument = subParser.add(option: "--target",
                                       shortName: "-t",
                                       kind: String.self,
                                       usage: "Specify name of target to add generated code to")
        self.contractCodeGenerator = contractCodeGenerator
    }

    func run(with arguments: ArgumentParser.Result) throws {
        guard let file = arguments.get(fileArgument) else { throw GenerateError.argumentNotProvided("Contract file") }
        guard let contractName = arguments.get(contractNameArgument) else { throw GenerateError.argumentNotProvided("Contract name") }
        
        let filePath = AbsolutePath(file, relativeTo: FileHandler.shared.currentPath)
        guard FileHandler.shared.exists(filePath) else {
            throw GenerateError.fileNotFound(filePath)
        }

        guard
            let abiData: Data = try FileHandler.shared.readTextFile(filePath).data(using: .utf8)
        else { throw GenerateError.contractDecodeFailed(filePath) }
        let contract = try JSONDecoder().decode(Contract.self, from: abiData)

        let generatedSwiftCodePath: AbsolutePath = self.generatedSwiftCodePath(outputValue: arguments.get(outputArgument),
                                                                               xcodePath: arguments.get(xcodeArgument))

        try contractCodeGenerator.generateContract(path: generatedSwiftCodePath, contract: contract, contractName: contractName)
        try contractCodeGenerator.generateSharedContract(path: generatedSwiftCodePath, extensions: arguments.get(extensionsArgument) ?? [])
        
        // Do not bind files when project or swift code path is not given
        guard
            let xcodePathString = arguments.get(xcodeArgument),
            let outputPathString = arguments.get(outputArgument)
        else { return }
        let xcodePath = AbsolutePath(xcodePathString, relativeTo: FileHandler.shared.currentPath)
        guard FileHandler.shared.exists(xcodePath) else { throw GenerateError.xcodeProjectNotFound(xcodePath) }

        let outputPath = RelativePath(outputPathString)
        
        let targets = try XcodeProjectController.shared.targets(projectPath: xcodePath)
        guard !targets.isEmpty else { throw GenerateError.noTargetsFound(xcodePath) }
        let target: PBXNativeTarget
        if let predefinedTarget = arguments.get(targetArgument) {
            guard let foundTarget = targets.first(where: { $0.name == predefinedTarget }) else { throw GenerateError.targetNotFound(predefinedTarget) }
            target = foundTarget
        } else {
            target = try InputReader.shared.readInput(options: targets, question: "Choose target for the generated contract code:")
        }
        
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
                return AbsolutePath(xcodeComponents.joined(separator: "/"), relativeTo: FileHandler.shared.currentPath)
                    .appending(RelativePath(outputValue))
            } else {
                return AbsolutePath(outputValue, relativeTo: FileHandler.shared.currentPath)
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
            throw GenerateError.invalidIndex(targets.count)
        }
        
        return targets[index - 1]
    }
}
