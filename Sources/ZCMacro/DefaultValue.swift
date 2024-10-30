//
//  File.swift
//  
//
//  Created by lzc on 2024/10/30.
//

import Foundation

extension Int: ZCCodable {
  public static var defaultValue: Int { 0 }
}

extension Int8: ZCCodable {
    public static var defaultValue: Int8 { 0 }
}

extension Int16: ZCCodable {
    public static var defaultValue: Int16 { 0 }
}

extension Int32: ZCCodable {
    public static var defaultValue: Int32 { 0 }
}

extension Int64: ZCCodable {
    public static var defaultValue: Int64 { 0 }
}

extension UInt: ZCCodable {
    public static var defaultValue: UInt { 0 }
}

extension UInt8: ZCCodable {
    public static var defaultValue: UInt8 { 0 }
}

extension UInt16: ZCCodable {
    public static var defaultValue: UInt16 { 0 }
}

extension UInt32: ZCCodable {
    public static var defaultValue: UInt32 { 0 }
}

extension UInt64: ZCCodable {
    public static var defaultValue: UInt64 { 0 }
}

extension Date: ZCCodable {
    public static var defaultValue: Date { Date(timeIntervalSince1970: 0) }
}

extension Data: ZCCodable {
    public static var defaultValue: Data { Data() }
}

extension UUID: ZCCodable {
    public static var defaultValue: UUID { UUID() }
}

extension URL: ZCCodable {
    public static var defaultValue: URL { URL(string: "")! }
}

// 范围类型
extension ClosedRange: ZCCodable where Bound: ZCCodable {
    public static var defaultValue: ClosedRange<Bound> { Bound.defaultValue...Bound.defaultValue }
}

extension Range: ZCCodable where Bound: ZCCodable {
    public static var defaultValue: Range<Bound> { Bound.defaultValue..<Bound.defaultValue }
}

extension String: ZCCodable {
  public static var defaultValue: String { "" }
}

extension Double: ZCCodable {
  public static var defaultValue: Double { 0.0 }
}

extension CGFloat: ZCCodable {
  public static var defaultValue: CGFloat { 0 }
}

extension Float: ZCCodable {
  public static var defaultValue: Float { 0 }
}

extension Decimal: ZCCodable {
    public static var defaultValue: Decimal { Decimal(0) }
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

public struct ZCArchiverBox<T: NSObject & NSCoding>: ZCCodable {
    public static var defaultValue: ZCArchiverBox<T> {
        // Check if T is NSAttributedString
        if T.self == NSAttributedString.self {
            return ZCArchiverBox(NSAttributedString(string: "") as! T)
        }
        // Check if T is NSMutableAttributedString
        else if T.self == NSMutableAttributedString.self {
            return ZCArchiverBox(NSMutableAttributedString(string: "") as! T)
        }
        // Check if T is NSArray
        else if T.self == NSArray.self {
            return ZCArchiverBox([] as! T)
        }
        // Check if T is NSDictionary
        else if T.self == NSDictionary.self {
            return ZCArchiverBox([:] as! T)
        }
        // Check if T is NSString
        else if T.self == NSString.self {
            return ZCArchiverBox("" as! T)
        }
        // Check if T is NSNumber
        else if T.self == NSNumber.self {
            return ZCArchiverBox(0 as! T) // Default number
        }
        return ZCArchiverBox("" as! T)
    }
    
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        
        guard let objectValue = try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Couldn't unarchive object")
        }
        self.value = objectValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
        try container.encode(data)
    }
}

