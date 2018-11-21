import Foundation
import SwiftCLI
import PathKit
import StencilSwiftKit
import Stencil

open class GenerateCommand: SwiftCLI.Command {

    public let name = "generate"
    public let shortDescription = "Generates Swift code for contract"

    let contractName = Parameter(completion: .none)
    let file = Parameter(completion: .filename)
    let output = Key<String>("-o", "--output", description: "Define output directory")
    let xcode = Key<String>("-x", "--xcode", description: "Define location of .xcodeproj")
    var executableLocation = Path.current

    public init() {

    }

    public func execute() throws {

        guard let executableLocationString = CommandLine.arguments.first else { return }
        let executableLocation = Path(executableLocationString) + Path("../")
        self.executableLocation = executableLocation

        let filePath = Path.current + Path(file.value)
        guard filePath.exists else {
            stdout <<< "File at given path does not exist."
            return
        }

        let contract: Contract

        do {
            let abiData: Data = try filePath.read()
            contract = try JSONDecoder().decode(Contract.self, from: abiData)
        } catch {
            stdout <<< "ABI JSON decode error! ⛔️"
            return
        }

        var projectPath: Path?
        if let projectPathValue = xcode.value {
            projectPath = Path(projectPathValue)
        }

        var generatedSwiftCodePath: Path?

        if let outputValue = output.value {
            if let xcodePath = xcode.value {
                var xcodeComponents = xcodePath.components(separatedBy: "/")
                xcodeComponents.remove(at: xcodeComponents.endIndex - 1)
                generatedSwiftCodePath = Path(xcodeComponents.joined(separator: "/")) + Path(outputValue)
            } else {
                generatedSwiftCodePath = Path(outputValue)
            }
        }

        writeGeneratedCode(to: generatedSwiftCodePath, contract: contract)

        // Do not bind files when project or swift code path is not given
        guard let xcodePath = projectPath, let swiftCodePath = generatedSwiftCodePath, let relativePathValue = output.value else { return }
        bindFilesWithProject(xcodePath: xcodePath, swiftCodePath: swiftCodePath, relativePathValue: relativePathValue)
    }

    /// Writes and renders code from .stencil files to a given directory
    private func writeGeneratedCode(to path: Path?, contract: Contract) {

        let swiftCodePath = path ?? (Path.current + Path("GeneratedContracts"))

        let stencilSwiftExtension = Extension()
        stencilSwiftExtension.registerStencilSwiftExtensions()
        let fsLoader: FileSystemLoader
        let relativeTemplatesPath = executableLocation + Path("../templates/")
        if relativeTemplatesPath.exists {
            fsLoader = FileSystemLoader(paths: [relativeTemplatesPath])
        } else {
            fsLoader = FileSystemLoader(paths: ["/usr/local/share/tezosgen/templates/"])
        }

        let isSimple = contract.storage.type != .pair
        let params = contract.renderToSwift().enumerated().map { "param\($0 + 1): \($1)" }.joined(separator: ", ")
        let args = contract.renderToSwift().enumerated().map { "let arg\($0 + 1): \($1)" }.joined(separator: "\n")
        let renderedInit: String
        if isSimple {
            renderedInit = "param1"
        } else {
            renderedInit = contract.renderInitToSwift()
        }
        let initArgs = contract.renderArgsToSwift().joined(separator: "\n")
        let environment = Environment(loader: fsLoader, extensions: [stencilSwiftExtension])
        var contractDict: [String: Any] = ["params": params, "args": args, "type": contract.storage.generatedTypeString, "init": renderedInit, "init_args": initArgs, "simple": "\(isSimple)"]
        if let key = contract.storage.key {
            contractDict["key"] = key
        }
        let context: [String: Any] = ["contractName": contractName.value, "contract": contractDict]

        do {
            if !swiftCodePath.exists {
                try FileManager.default.createDirectory(atPath: "\(swiftCodePath.absolute())", withIntermediateDirectories: true, attributes: nil)
            }

            let commonRendered = try environment.renderTemplate(name: "shared_contractgen.stencil")
            let sharedSwiftCodePath = swiftCodePath + Path("SharedContract.swift")
            if sharedSwiftCodePath.exists {
                try sharedSwiftCodePath.delete()
            }
            try sharedSwiftCodePath.write(commonRendered)
            let rendered = try environment.renderTemplate(name: "contractgen.stencil", context: context)
            let contractCodePath = swiftCodePath + Path(contractName.value + ".swift")
            try contractCodePath.write(rendered)
        } catch {
            stdout <<< "Write Error! 😱"
            return
        }
    }

    func findTargetIndex(rakeFilePath: Path, targetsString: String) -> Int {
        let targets = targetsString.components(separatedBy: "\n")
        // Prints targets as a list so user can choose with which one they want to bind their files
        for (index, target) in targets.enumerated() {
            print("\(index + 1). " + target)
        }

        let index = Input.readInt(
            prompt: "Choose target for the generated contract code:",
            validation: { $0 > 0 && $0 <= targets.count },
            errorResponse: { input in
                self.stderr <<< "'\(input)' is invalid; must be a number between 1 and \(targets.count)"
            }
        )

        return index
    }

    /// Binds file references with project, adds files to target
    private func bindFilesWithProject(xcodePath: Path, swiftCodePath: Path, relativePathValue: String) {
        let targetsString: String
        let rakeFilePath: Path
        do {
            let relativeRakefilePath = executableLocation + Path("../Rakefile")
            if relativeRakefilePath.exists {
                rakeFilePath = relativeRakefilePath
            } else {
                rakeFilePath = Path("/usr/local/share/tezosgen/Rakefile")
            }
            targetsString = try capture(bash: "rake -f \(rakeFilePath.absolute()) xcode:find_targets'[\(xcodePath.absolute())]'").stdout
        } catch {
            stdout <<< "Rakefile task find_targets failed 😥"
            return
        }

        let index = findTargetIndex(rakeFilePath: rakeFilePath, targetsString: targetsString)

        var relativePathComponents = relativePathValue.components(separatedBy: "/")
        let parentGroup = relativePathComponents.remove(at: relativePathComponents.startIndex)
        let relativePath = relativePathComponents.joined(separator: "/")
        do {
            try run(bash: "rake -f \(rakeFilePath.absolute()) xcode:add_files_to_group'[\(xcodePath.absolute()),\(swiftCodePath.absolute()),\(relativePath),\(parentGroup),\(index - 1)]'")
            stdout <<< "Code generation: ✅"
        } catch {
            stdout <<< "Rakefile task add_files_to_group failed 😥"
        }
    }
}
