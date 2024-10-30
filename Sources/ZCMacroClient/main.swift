import ZCMacro
import ZCMacroMacros
import Foundation

@zcCodable
struct Test{
  let name: String
  @zcAnnotation(key: "new_age", default: 99)
  let age: Int
    @zcAnnotation(key: "new_add", default: "aa")
  let address: String
  let optional: String?
  let array: [String]
  let dic: [String: Any]
  let people: People
}

@zcCodable
struct Generic<T: ZCCodable> {
  let value: T
  let a: Int
}

// key不存在 解析
let dic: [String: Any] = [:]

do {
  let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
  let value = try JSONDecoder().decode(Generic<Test>.self, from: jsonData)
  print(value)
} catch {
  print("Error: \(error)")
}

let a = 99

@zcCodable
struct People{
//  @icarusAnnotation(default: "aaaad")
  let name: String
//  @icarusAnnotation(key: "new_age", default: a + 1)
  let age: Int
//    @icarusAnnotation(default: Sex.female)
    let sex: Sex
}

let peopleDic: [String: Any] = ["name": "ldc", "age": false]
let testDic: [String: Any] = [:]

do {
  let value: People = try decode(peopleDic)
  print(value)
} catch {
  print("Error: \(error)")
}

extension Int: ZCCodable {
  public static var defaultValue: Int { 0 }
}

extension String: ZCCodable {
  public static var defaultValue: String { "" }
}

extension Double: ZCCodable {
  public static var defaultValue: Double { 0.0 }
}

extension Bool: ZCCodable {
  public static var defaultValue: Bool { false }
}

extension Optional: ZCCodable where Wrapped: ZCCodable {
  public static var defaultValue: Optional<Wrapped> { .none }
}

extension Dictionary: ZCCodable where Value: ZCCodable, Key: ZCCodable {
  public static var defaultValue: Dictionary<Key, Value> { [:] }
}

extension Array: ZCCodable where Element: ZCCodable {
  public static var defaultValue: Array<Element> { [] }
}

func decode<T: Codable>(_ dic: [String: Any]) throws -> T {
  let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
  return try JSONDecoder().decode(T.self, from: jsonData)
}

@zcMirror
struct MirrorTest {
    let name: String
    let age: Int
    let people: People
    let optional: Int?
}

print(MirrorTest.mirror)

@zcCodable
struct Address {
  let country: String
  let province: String
  let city: String
}

enum Sex: ZCCodable {
  case male
  case female
  
  static var defaultValue: Sex { .male }
}

@zcCodable
struct Student {
  @zcAnnotation(key: "new_name")
  let name: String
  @zcAnnotation(default: 100)
  let age: Int
  let address: Address
  @zcAnnotation(default: true)
  let isBoarder: Bool
  @zcAnnotation(key: "_sex", default: Sex.female)
  let sex: Sex
}

public struct AnyDecodable: Decodable, Encodable {
    public let value: Any
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dateValue = try? container.decode(Date.self) {
            value = dateValue
        } else if let dataValue = try? container.decode(Data.self) {
            value = dataValue
        } else if let intArrayValue = try? container.decode([Int].self) {
            value = intArrayValue
        } else if let doubleArrayValue = try? container.decode([Double].self) {
            value = doubleArrayValue
        } else if let stringArrayValue = try? container.decode([String].self) {
            value = stringArrayValue
        } else if let boolArrayValue = try? container.decode([Bool].self) {
            value = boolArrayValue
        } else if let nestedArrayValue = try? container.decode([AnyDecodable].self) {
            value = nestedArrayValue.map { $0.value }
        } else if let nestedDictionaryValue = try? container.decode([String: AnyDecodable].self) {
            value = nestedDictionaryValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Type not supported")
        }
    }
    
    // 编码器，用于支持编码
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let dateValue as Date:
            try container.encode(dateValue)
        case let dataValue as Data:
            try container.encode(dataValue)
        case let intArrayValue as [Int]:
            try container.encode(intArrayValue)
        case let doubleArrayValue as [Double]:
            try container.encode(doubleArrayValue)
        case let stringArrayValue as [String]:
            try container.encode(stringArrayValue)
        case let boolArrayValue as [Bool]:
            try container.encode(boolArrayValue)
        case let nestedArrayValue as [Any]:
            let anyEncodableArray = nestedArrayValue.map { AnyEncodable($0) }
            try container.encode(anyEncodableArray)
        case let nestedDictionaryValue as [String: Any]:
            let anyEncodableDictionary = nestedDictionaryValue.mapValues { AnyEncodable($0) }
            try container.encode(anyEncodableDictionary)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Type not supported"))
        }
    }
}

extension AnyDecodable: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}

public struct AnyEncodable: Encodable {
    public let value: Any
    
    public init<T>(_ value: T) {
        self.value = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let dateValue as Date:
            try container.encode(dateValue)
        case let dataValue as Data:
            try container.encode(dataValue)
        case let intArray as [Int]:
            try container.encode(intArray)
        case let doubleArray as [Double]:
            try container.encode(doubleArray)
        case let stringArray as [String]:
            try container.encode(stringArray)
        case let boolArray as [Bool]:
            try container.encode(boolArray)
        case let nestedArray as [AnyEncodable]:
            try container.encode(nestedArray.map { AnyEncodable($0) })
        case let nestedDictionary as [String: AnyEncodable]:
            try container.encode(nestedDictionary.mapValues { AnyEncodable($0) })
        case let dictionaryValue as [String: Any]:
            try container.encode(dictionaryValue.mapValues { AnyEncodable($0) })
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyEncodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Type not supported"))
        }
    }
}

extension AnyEncodable: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}
