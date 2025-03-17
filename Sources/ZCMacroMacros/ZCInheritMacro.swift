//
//  File.swift
//  ZCMacro
//
//  Created by lzc on 2025/3/13.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum MacroExpansionError: Error {
    case message(String)
}

/// 负责继承 `Codable` 并自动生成 `CodingKeys`、`init(from:)` 和 `encode(to:)`
public struct ZCInheritMacro: MemberMacro, ExtensionMacro {

    /// **扩展 Codable**
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        return [
            try ExtensionDeclSyntax("extension \(type.trimmed) {}")
        ]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var decls: [DeclSyntax] = []
        // get stored properties
        let storedProperties: [VariableDeclSyntax] = try {
            if let classDeclaration = declaration.as(ClassDeclSyntax.self) {
                return classDeclaration.storedProperties()
            } else if let structDeclaration = declaration.as(StructDeclSyntax.self) {
                return structDeclaration.storedProperties()
            } else {
                throw CodableError.invalidInputType
            }
        }()
        // unpacking the property name and type of a stored property
        let arguments = storedProperties.compactMap { property -> (name: String, type: TypeSyntax, keys: [String], defaultValue: String?, ignore: Bool)? in
            guard let name = property.name, let type = property.type
            else { return nil }
            var keys: [String] = [name], defaultValue: String?, ignore = false
            // find the icarusAnnotation annotation tag
            guard let attribute = property.attributes.first(where: { $0.as(AttributeSyntax.self)!.attributeName.description == "zcAnnotation" })?.as(AttributeSyntax.self),
                  let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
            else { return (name: name, type: type, keys: keys, defaultValue: defaultValue, ignore: ignore)
            }
            // extracting the key and default values from the annotation and parsing them according to the syntax tree structure.
            arguments.forEach {
                let argument = $0.as(LabeledExprSyntax.self)
                let expression = argument?.expression.as(StringLiteralExprSyntax.self)
                let segments = expression?.segments.first?.as(StringSegmentSyntax.self)
                let content = segments?.content
                let argumentValue = argument?.expression
                switch argument?.label?.text {
                case "key":
                    if let arrayExpr = argumentValue?.as(ArrayExprSyntax.self) {
                        keys = arrayExpr.elements.compactMap { $0.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text }
                    } else if let key = content?.text {
                        keys = [key]
                    }
                case "default": defaultValue = argumentValue?.description
                case "ignore":
                    let literal = argumentValue?.as(BooleanLiteralExprSyntax.self)?.literal.text
                    ignore = (literal == "true")
                default: break
                }
            }
            if type.isDictionaryWithKeyType("String", valueType: "Any") {
                defaultValue = defaultValue ?? "[:]"
            } else if type.isArrayOfAny() {
                defaultValue = defaultValue ?? "[]"
            }
            // the property name is used as the default key
            return (name: name, type: type, keys: keys, defaultValue: defaultValue, ignore: ignore)
        }
        
        // MARK: - CodingKeys
        let defineCodingKeys = try EnumDeclSyntax(SyntaxNodeString(stringLiteral: "public enum CodingKeys: String, CodingKey"), membersBuilder: {
            for argument in arguments where !argument.ignore {
                for key in argument.keys {
                    DeclSyntax(stringLiteral: "case \(key)")
                }
            }
        })
        print(defineCodingKeys.description)
        // MARK: - Decoder
        let decoder = try InitializerDeclSyntax(SyntaxNodeString(stringLiteral: "required public init(from decoder: Decoder) throws"), bodyBuilder: {
            DeclSyntax(stringLiteral: "let standardContainer = try decoder.container(keyedBy: CustomDecodableKeys.self)\nlet container = CustomKeyedDecodingContainer(standardContainer)")
            for argument in arguments where !argument.ignore {
                // 对于每个 argument 的 key 生成一个解码表达式
                let decodingExpression = argument.keys.map { key in
                    if argument.type.isDictionaryWithKeyType("String", valueType: "Any") {
                        return "container.decodeIfPresent([String: AnyDecodable].self, forKey: CustomDecodableKeys(stringValue: \"\(key)\"))"
                    } else if argument.type.isArrayOfAny() {
                        return "container.decodeIfPresent([AnyDecodable].self, forKey: CustomDecodableKeys(stringValue: \"\(key)\"))"
                    } else {
                       return "container.decodeIfPresent(\(argument.type).self, forKey: CustomDecodableKeys(stringValue: \"\(key)\"))"
                    }
                }.joined(separator: " ?? ")
                
                // 使用最后的解码表达式，结合默认值
                let finalExpression = "\(decodingExpression) ?? \(argument.defaultValue ?? argument.type.defaultValueExpression)"
                
                // 根据类型构建相应的赋值表达式
                if argument.type.isDictionaryWithKeyType("String", valueType: "Any") {
                    if argument.type.isOptional() {
                        ExprSyntax(stringLiteral: "\(argument.name) = (try \(decodingExpression))?.mapValues { $0.value } ?? nil")
                    } else {
                        ExprSyntax(stringLiteral: "\(argument.name) = (try \(decodingExpression))?.mapValues { $0.value } ?? [:]")
                    }
                } else if argument.type.isArrayOfAny() {
                    if argument.type.isOptional() {
                        ExprSyntax(stringLiteral: "\(argument.name) = (try \(decodingExpression))?.map { $0.value } ?? nil")
                    } else {
                        ExprSyntax(stringLiteral: "\(argument.name) = (try \(decodingExpression))?.map { $0.value } ?? []")
                    }
                } else {
                    ExprSyntax(stringLiteral: "\(argument.name) = try \(finalExpression)")
                }
            }
            ExprSyntax(stringLiteral: "try super.init(from: decoder)")
        })
        
        // MARK: - Encoder
        let encoder = try FunctionDeclSyntax(SyntaxNodeString(stringLiteral: "override public func encode(to encoder: Encoder) throws"), bodyBuilder: {
            DeclSyntax(stringLiteral: "var container = encoder.container(keyedBy: CodingKeys.self)")
            for argument in arguments where !argument.ignore {
                // 创建一个编码表达式
                let encodingExpressions = argument.keys.map { key in
                    if argument.type.isDictionaryWithKeyType("String", valueType: "Any") {
                        if argument.type.isOptional() {
                            return "try container.encodeIfPresent(\(argument.name)?.mapValues { AnyEncodable($0) }, forKey: .\(key))"
                        } else {
                            return "try container.encodeIfPresent(\(argument.name).mapValues { AnyEncodable($0) }, forKey: .\(key))"
                        }
                    } else if argument.type.isArrayOfAny() {
                        if argument.type.isOptional() {
                            return "try container.encodeIfPresent(\(argument.name)?.map { AnyEncodable($0) }, forKey: .\(key))"
                        } else {
                            return "try container.encodeIfPresent(\(argument.name).map { AnyEncodable($0) }, forKey: .\(key))"
                        }
                    } else {
                        return "try container.encodeIfPresent(\(argument.name), forKey: .\(key))"
                    }
                }
                
                // 将所有编码表达式连接在一起
                for encodingExpression in encodingExpressions {
                    ExprSyntax(stringLiteral: encodingExpression)
                }
                ExprSyntax(stringLiteral: "try super.encode(to: encoder)")
            }
        })
        decls.append(contentsOf: [DeclSyntax(defineCodingKeys),
                                  DeclSyntax(decoder),
                                  DeclSyntax(encoder)
                                 ])
        return decls
    }
}
