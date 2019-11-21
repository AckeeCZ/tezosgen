import SPMUtility

/// Available extensions for generating like convenience Combine methods, etc.
public enum GeneratorExtension: String, ArgumentKind {
    case combine = "combine"
    
    public static var completion: ShellCompletion = .none
    
    public init(argument: String) throws {
        guard let generatorExtension = GeneratorExtension(rawValue: argument) else {
            throw ArgumentConversionError.typeMismatch(value: argument, expectedType: GeneratorExtension.self)
        }

        self = generatorExtension
    }
}
