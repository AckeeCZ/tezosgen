import Basic
import TezosGenCore
import class XcodeProj.PBXNativeTarget

public final class MockXcodeProjectController: XcodeProjectControlling {
    public var addFilesAndGroupsStub: ((AbsolutePath, RelativePath, [AbsolutePath], PBXNativeTarget) throws -> ())?
    public var targetsStub: ((AbsolutePath) throws -> [PBXNativeTarget])?
    
    public func addFilesAndGroups(xcodePath: AbsolutePath, outputPath: RelativePath, files: [AbsolutePath], target: PBXNativeTarget) throws {
        try addFilesAndGroupsStub?(xcodePath, outputPath, files, target)
    }
    
    public func targets(projectPath: AbsolutePath) throws -> [PBXNativeTarget] {
        try targetsStub?(projectPath) ?? []
    }
}
