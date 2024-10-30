//
//  File.swift
//  
//
//  Created by lzc on 2024/10/30.
//

import Foundation

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
