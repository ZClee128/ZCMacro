// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
import Foundation

public protocol ZCCodable: Codable, CustomDecodable {
  static var defaultValue: Self { get }
}

public protocol ZCMirror {
    static var mirror: [String: Any.Type] { get }
}

@attached(extension, conformances: ZCCodable)
@attached(member, names: named(init), named(defaultValue), named(CodingKeys), named(encode(to:)), named(init(from:)))
public macro zcCodable() = #externalMacro(module: "ZCMacroMacros", type: "AutoCodableMacro")

@attached(peer)
public macro zcAnnotation<T: ZCCodable>(key: [String]? = nil, default: T) = #externalMacro(module: "ZCMacroMacros", type: "AutoCodableAnnotation")
@attached(peer)
public macro zcAnnotation(key: [String]) = #externalMacro(module: "ZCMacroMacros", type: "AutoCodableAnnotation")
@attached(peer)
public macro zcAnnotation<T: ZCCodable>(key: [String]? = nil, default: T, ignore: Bool = false) = #externalMacro(module: "ZCMacroMacros", type: "AutoCodableAnnotation")
@attached(peer)
public macro zcAnnotation(key: [String]? = nil, ignore: Bool = false) = #externalMacro(module: "ZCMacroMacros", type: "AutoCodableAnnotation")

@attached(extension, conformances: ZCMirror)
@attached(member, names: named(mirror))
public macro zcMirror() = #externalMacro(module: "ZCMacroMacros", type: "MirrorMacro")
