
public enum TezosPrimaryType: String, Codable {
    case string
    case int
    case nat
    case bool
    case bytes
    case set
    case list
    case pair
    case option
    case or
    case timestamp
    case tez
    case signature
    case key
    case contract
    case keyHash = "key_hash"
    case mutez
    case map
    case bigMap = "big_map"
    case unit
    case address
}
