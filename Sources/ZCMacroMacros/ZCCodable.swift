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
        var reqString = ""
        let typeName: String
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            reqString = "required "
            typeName = classDecl.name.text
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            typeName = structDecl.name.text
        } else {
            typeName = "Self" // 默认使用 Self
        }
        // MARK: - _init
        let _initDeclSyntax = try InitializerDeclSyntax(
            SyntaxNodeString(stringLiteral: "\(reqString)public init(\(arguments.map { "_\($0.name): \($0.type)" }.joined(separator: ", ")))"),
            bodyBuilder: {
                for argument in arguments {
                    ExprSyntax(stringLiteral: "self.\(argument.name) = _\(argument.name)")
                }
            }
        )

        let arr = arguments.map { tup in
            // 检查是否为数组类型
            if tup.type.isArrayOfAny() {
                return "_\(tup.name): \([])"
            }
            
            // 检查是否为字典类型
            if tup.type.isDictionaryWithKeyType("String", valueType: "Any") {
                return "_\(tup.name): \([:])"
            }
            
            // 返回默认值表达式
            return "_\(tup.name): \(tup.defaultValue ?? tup.type.defaultValueExpression)"
        }

        // MARK: - defaultValue
        let defaultBody: ExprSyntax = "\(raw: typeName)(\(raw: arr.joined(separator: ",")))"
        let defaultDeclSyntax: VariableDeclSyntax = try VariableDeclSyntax("public static var defaultValue: \(raw: typeName)") {
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
        print(defineCodingKeys.description)
        // MARK: - Decoder
        let decoder = try InitializerDeclSyntax(SyntaxNodeString(stringLiteral: "\(reqString)public init(from decoder: Decoder) throws"), bodyBuilder: {
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
                    ExprSyntax(stringLiteral: "\(argument.name) = (try \(decodingExpression))?.mapValues { $0.value } ?? nil")
                } else if argument.type.isArrayOfAny() {
                    ExprSyntax(stringLiteral: "\(argument.name) = (try \(decodingExpression))?.map { $0.value } ?? nil")
                } else {
                    ExprSyntax(stringLiteral: "\(argument.name) = try \(finalExpression)")
                }
            }
        })
        
        // MARK: - Encoder
        let encoder = try FunctionDeclSyntax(SyntaxNodeString(stringLiteral: "public func encode(to encoder: Encoder) throws"), bodyBuilder: {
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
            }
        })
        decls.append(contentsOf: [DeclSyntax(defineCodingKeys),
                                  DeclSyntax(decoder),
                                  DeclSyntax(encoder),
                                  DeclSyntax(_initDeclSyntax),
                                  DeclSyntax(defaultDeclSyntax)])
        return decls
    }
}

extension TypeSyntax {
    func isDictionaryWithKeyType(_ keyType: String, valueType: String) -> Bool {
        // 首先检查当前类型是否为可选类型
        if let optionalType = self.as(OptionalTypeSyntax.self) {
            // 获取可选类型的包装类型
            return optionalType.wrappedType.isDictionaryWithKeyType(keyType, valueType: valueType)
        }
        
        // 检查当前类型是否为字典类型
        guard let dictionaryType = self.as(DictionaryTypeSyntax.self) else {
            return false
        }
        let key = dictionaryType.key.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = dictionaryType.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return key == keyType && value == valueType
    }

    func isArrayOfAny() -> Bool {
        // 首先检查当前类型是否为可选类型
        if let optionalType = self.as(OptionalTypeSyntax.self) {
            // 获取可选类型的包装类型
            return optionalType.wrappedType.isArrayOfAny()
        }
        guard let arrayType = self.as(ArrayTypeSyntax.self) else {
            return false
        }
        let elementType = arrayType.element.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return elementType == "Any"
    }
    
    func isClassType() -> Bool {
        if self.as(ClassDeclSyntax.self) != nil {
            return true
        }
        return false
    }
    
    func isOptional() -> Bool {
        // 检查当前类型是否为可选类型
        if let _ = self.as(OptionalTypeSyntax.self) {
            return true
        }
        return false
    }
    
    var defaultValueExpression: String {
        return "\(self).defaultValue"
    }
}
