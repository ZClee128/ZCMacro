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

enum MirrorError: Swift.Error, CustomStringConvertible {
  case invalidInputType
  
  var description: String {
    "@zcMirror macro is only applicable to structs or classes"
  }
}

public struct MirrorMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
      let sendableExtension: DeclSyntax =
            """
            extension \(type.trimmed): ZCMirror {}
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
        throw MirrorError.invalidInputType
      }
    }()
    
    // unpacking the property name and type of a stored property
    let arguments = storedProperties.compactMap { property -> (name: String, type: TypeSyntax)? in
      guard let name = property.name, let type = property.type
      else { return nil }
      return (name: name, type: type)
    }
    
    let mirrorSyntax = try VariableDeclSyntax("static var mirror: Dictionary<String, Any.Type>") {
      ExprSyntax(stringLiteral: "[\n")
      for argument in arguments {
        ExprSyntax(stringLiteral: "\"\(argument.name)\": \(argument.type).self,\n")
      }
      ExprSyntax(stringLiteral: "]")
    }
    
    return [DeclSyntax(mirrorSyntax)]
  }
}
