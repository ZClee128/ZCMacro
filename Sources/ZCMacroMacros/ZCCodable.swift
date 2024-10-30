//
//  File.swift
//
//
//  Created by lzc on 2024/10/28.
//
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

enum CodableError: Swift.Error, CustomStringConvertible {
    case invalidInputType
    
    var description: String {
        "@zcCodable macro is only applicable to structs or classes"
    }
}

// Annotation macro, unexpanded
public struct AutoCodableAnnotation: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws -> [DeclSyntax] {
            return []
        }
}

public struct AutoCodableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
            let sendableExtension: DeclSyntax =
            """
            extension \(type.trimmed): ZCCodable {}
            """
            
            guard let extensionDecl = sendableExtension.as(ExtensionDeclSyntax.self) else {
                return []
            }
            
            return [extensionDecl]
        }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
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
        
        // MARK: - _init
        let _initDeclSyntax = try InitializerDeclSyntax(
            SyntaxNodeString(stringLiteral: "private init(\(arguments.map { "_\($0.name): \($0.type)" }.joined(separator: ", ")))"),
            bodyBuilder: {
                for argument in arguments {
                    ExprSyntax(stringLiteral: "self.\(argument.name) = _\(argument.name)")
                }
            }
        )
        
        let arr = arguments.map { tup in
            if tup.type.isArrayOfAny() {
                return "_\(tup.name): \([])"
            }
            if tup.type.isDictionaryWithKeyType("String", valueType: "Any") {
                return "_\(tup.name): \([:])"
            }
            return "_\(tup.name): \(tup.defaultValue ?? tup.type.defaultValueExpression)"
        }
        
        // MARK: - defaultValue
        let defaultBody: ExprSyntax = "Self(\(raw: arr.joined(separator: ",")))"
        let defaultDeclSyntax: VariableDeclSyntax = try VariableDeclSyntax("public static var defaultValue: Self") {
            defaultBody
        }
        
        // MARK: - CodingKeys
        let defineCodingKeys = try EnumDeclSyntax(SyntaxNodeString(stringLiteral: "public enum CodingKeys: String, CodingKey"), membersBuilder: {
            for argument in arguments where !argument.ignore {
                for key in argument.keys {
                    DeclSyntax(stringLiteral: "case \(key)")
                }
            }
        })
        
        // MARK: - Decoder
        let decoder = try InitializerDeclSyntax(SyntaxNodeString(stringLiteral: "public init(from decoder: Decoder) throws"), bodyBuilder: {
            DeclSyntax(stringLiteral: "let container = try decoder.container(keyedBy: CodingKeys.self)")
            for argument in arguments where !argument.ignore {
                for key in argument.keys {
                    if argument.type.isDictionaryWithKeyType("String", valueType: "Any") {
                        ExprSyntax(stringLiteral: "\(argument.name) = try container.decodeIfPresent([String: AnyDecodable].self, forKey: .\(key))?.mapValues { $0.value } ?? [:]")
                    } else if argument.type.isArrayOfAny() {
                        ExprSyntax(stringLiteral: "\(argument.name) = try container.decodeIfPresent([AnyDecodable].self, forKey: .\(key))?.map { $0.value } ?? []")
                    } else {
                        ExprSyntax(stringLiteral: "\(argument.name) = try container.decodeIfPresent(\(argument.type).self, forKey: .\(key)) ?? \(argument.defaultValue ?? argument.type.defaultValueExpression)")
                    }
                }
            }
        })
        
        // MARK: - Encoder
        let encoder = try FunctionDeclSyntax(SyntaxNodeString(stringLiteral: "public func encode(to encoder: Encoder) throws"), bodyBuilder: {
            DeclSyntax(stringLiteral: "var container = encoder.container(keyedBy: CodingKeys.self)")
            for argument in arguments where !argument.ignore {
                for key in argument.keys {
                    if argument.type.isDictionaryWithKeyType("String", valueType: "Any") {
                        ExprSyntax(stringLiteral: "try container.encode(\(argument.name).mapValues { AnyEncodable($0) }, forKey: .\(key))")
                    } else if argument.type.isArrayOfAny() {
                        ExprSyntax(stringLiteral: "try container.encode(\(argument.name).map { AnyEncodable($0) }, forKey: .\(key))")
                    } else {
                        ExprSyntax(stringLiteral: "try container.encodeIfPresent(\(argument.name), forKey: .\(key))")
                    }
                }
            }
        })
        
        return [
            DeclSyntax(defineCodingKeys),
            DeclSyntax(decoder),
            DeclSyntax(encoder),
            DeclSyntax(_initDeclSyntax),
            DeclSyntax(defaultDeclSyntax)
        ]
    }
}

extension TypeSyntax {
    func isDictionaryWithKeyType(_ keyType: String, valueType: String) -> Bool {
        guard let dictionaryType = self.as(DictionaryTypeSyntax.self) else {
            return false
        }
        let key = dictionaryType.key.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = dictionaryType.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return key == keyType && value == valueType
    }

    func isArrayOfAny() -> Bool {
        guard let arrayType = self.as(ArrayTypeSyntax.self) else {
            return false
        }
        let elementType = arrayType.element.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return elementType == "Any"
    }
    var defaultValueExpression: String {
        return "\(self).defaultValue"
    }
}
