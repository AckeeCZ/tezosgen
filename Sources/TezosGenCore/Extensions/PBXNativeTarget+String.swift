import class XcodeProj.PBXNativeTarget

extension PBXNativeTarget: CustomStringConvertible {
    public var description: String {
        name
    }
}
