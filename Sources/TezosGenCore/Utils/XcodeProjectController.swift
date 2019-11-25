import XcodeProj
import Basic

public protocol XcodeProjectControlling {
    func addFilesAndGroups(xcodePath: AbsolutePath, outputPath: RelativePath, files: [AbsolutePath], target: PBXNativeTarget) throws
    func targets(projectPath: AbsolutePath) throws -> [PBXNativeTarget]
}

public final class XcodeProjectController: XcodeProjectControlling {
    
    public init() { }
    
    /// Shared instance
    public static var shared: XcodeProjectControlling = XcodeProjectController()
    
    public func targets(projectPath: AbsolutePath) throws -> [PBXNativeTarget] {
        let xcodeproj = try XcodeProj(pathString: projectPath.pathString)
        return xcodeproj.pbxproj.nativeTargets
    }
    
    public func addFilesAndGroups(xcodePath: AbsolutePath, outputPath: RelativePath, files: [AbsolutePath], target: PBXNativeTarget) throws {
        let xcodeproj = try XcodeProj(pathString: xcodePath.pathString)
        
        let outputGroup: PBXGroup? = try outputPath.components.reduce(into: nil, { result, name in
            if let group = xcodeproj.pbxproj.groups.first(where: { $0.path == name }) {
                result = group
            } else {
                result = try result?.addGroup(named: name).first
            }
        })
        
        guard let currentTarget = xcodeproj.pbxproj.targets(named: target.name).first else { fatalError() }
        
        let pbxFiles = try files.compactMap {
            try outputGroup?.addFile(at: $0.path, sourceRoot: xcodePath.parentDirectory.path)
        }
        
        try pbxFiles.forEach {
            _ = try currentTarget.sourcesBuildPhase()?.add(file: $0)
        }

        try xcodeproj.write(path: xcodePath.path)
    }
}
