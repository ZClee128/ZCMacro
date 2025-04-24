//
//  File.swift
//  
//
//  Created by lzc on 2024/11/1.
//

import Foundation

public struct CustomDecodableKeys: CodingKey {
    public var stringValue: String
    public var intValue: Int?
    
    public init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    public init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// 定义 CustomDecodable 协议
public protocol CustomDecodable {
    static func customDecode(from container: KeyedDecodingContainer<CustomDecodableKeys>, forKey key: KeyedDecodingContainer<CustomDecodableKeys>.Key) throws -> Self?
}

// 提供 CustomDecodable 的默认实现
extension CustomDecodable {
    public static func customDecode(from container: KeyedDecodingContainer<KeyedDecodingContainer<CustomDecodableKeys>.Key>, forKey key: KeyedDecodingContainer<CustomDecodableKeys>.Key) throws -> Self? {
        // 如果 Self 是基础类型，尝试直接解码
        if Self.self == Int.self || Self.self == Optional<Int>.self {
            if let int = try? container.decodeIfPresent(Int.self, forKey: key) {
                return int as? Self
            } else if let string = try? container.decodeIfPresent(String.self, forKey: key), let int = Int(string) {
                return int as? Self
            } else {
                return nil
            }
        } else if Self.self == Double.self || Self.self == Optional<Double>.self {
            if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
                return double as? Self
            } else if let string = try? container.decodeIfPresent(String.self, forKey: key), let double = Double(string) {
                return double as? Self
            } else {
                return nil
            }
        } else if Self.self == Float.self || Self.self == CGFloat.self || Self.self == Optional<Float>.self || Self.self == Optional<CGFloat>.self {
            if let float = try? container.decodeIfPresent(Float.self, forKey: key) {
                return (Self.self == CGFloat.self || Self.self == Optional<CGFloat>.self)
                ? CGFloat(float) as? Self
                : float as? Self
            } else if let string = try? container.decodeIfPresent(String.self, forKey: key),
                      let double = Double(string) {
                if Self.self == CGFloat.self || Self.self == Optional<CGFloat>.self {
                    return CGFloat(double) as? Self
                } else {
                    return Float(double) as? Self
                }
            } else {
                return nil
            }
        } else if Self.self == String.self || Self.self == Optional<String>.self {
            return (try? container.decodeIfPresent(String.self, forKey: key)) as? Self
        } else if Self.self == Bool.self || Self.self == Optional<Bool>.self {
            return (try? container.decodeIfPresent(Bool.self, forKey: key)) as? Self
        } else if Self.self == URL.self || Self.self == Optional<URL>.self {
            if let string = try? container.decodeIfPresent(String.self, forKey: key),
               let url = URL(string: string) {
                return url as? Self
            }
        } else if Self.self == UUID.self || Self.self == Optional<UUID>.self {
            if let string = try? container.decodeIfPresent(String.self, forKey: key), let uuid = UUID(uuidString: string) {
                return uuid as? Self
            }
        } else if Self.self == Date.self || Self.self == Optional<Date>.self {
            if let timestamp = try? container.decodeIfPresent(TimeInterval.self, forKey: key) {
                return Date(timeIntervalSince1970: timestamp) as? Self
            }
        } else if Self.self == Data.self || Self.self == Optional<Data>.self {
            if let base64String = try? container.decodeIfPresent(String.self, forKey: key), let data = Data(base64Encoded: base64String) {
                return data as? Self
            }
        }
        if let decodableType = Self.self as? Decodable.Type {
            return try? container.decodeIfPresent(decodableType, forKey: key) as? Self
        }
        // 如果没有匹配类型，则返回 nil，避免递归
        return nil
    }
}

// 扩展 KeyedDecodingContainer
extension KeyedDecodingContainer where K == CustomDecodableKeys {
    public func decodeIfPresent<T>(_ type: T.Type, forKey key: Self.Key) throws -> T? where T: CustomDecodable {
        // 防止无限递归：在调用 customDecode 之前，确保类型安全
        return try T.customDecode(from: self, forKey: key)
    }
}

extension Double: CustomDecodable {}
extension String: CustomDecodable {}
extension Bool: CustomDecodable {}
extension CGFloat: CustomDecodable {}
extension Int: CustomDecodable {}
extension URL: CustomDecodable {}
extension UUID: CustomDecodable {}
extension Date: CustomDecodable {}
extension Data: CustomDecodable {}

public struct CustomKeyedDecodingContainer {
    private let container: KeyedDecodingContainer<CustomDecodableKeys>
    
    public init(_ container: KeyedDecodingContainer<CustomDecodableKeys>) {
        self.container = container
    }
    
    public func decodeIfPresent<T: CustomDecodable>(_ type: T.Type, forKey key: CustomDecodableKeys) throws -> T? {
        return try T.customDecode(from: container, forKey: key)
    }
}
