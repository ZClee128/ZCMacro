//
//  File.swift
//  
//
//  Created by lzc on 2024/10/28.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension VariableDeclSyntax {
  /// variable name
  var name: String? {
    self.bindings.first?.as(PatternBindingSyntax.self)?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
  }
  
  /// variable type name
  var typeName: String? {
    guard let type = self.bindings.first?.as(PatternBindingSyntax.self)?.typeAnnotation?.as(TypeAnnotationSyntax.self) else {
      return nil
    }
    return "\(type.type)"
  }
  
  var type: TypeSyntax? {
    self.bindings.first?.as(PatternBindingSyntax.self)?.typeAnnotation?.as(TypeAnnotationSyntax.self)?.type
  }
}

extension VariableDeclSyntax {
  /// Check if this variable has the syntax of a stored property.
  var isStoredProperty: Bool {
    guard let binding = bindings.first,
          bindings.count == 1,
          !isLazyProperty,
          !isConstant else {
      return false
    }
    
    switch binding.accessorBlock?.accessors {
    case .none:
      return true
    case .accessors(let node):
      // traverse accessors
      for accessor in node {
        switch accessor.accessorSpecifier.tokenKind {
        case .keyword(.willSet), .keyword(.didSet):
          // stored properties can have observers
          break
        default:
          // everything else makes it a computed property
          return false
        }
      }
      return true
    case .getter:
      return false
    }
  }
  
  var isLazyProperty: Bool {
    modifiers.contains { $0.name.tokenKind == .keyword(Keyword.lazy) }
  }
  
  var isConstant: Bool {
    bindingSpecifier.tokenKind == .keyword(Keyword.let) && bindings.first?.initializer != nil
  }
  
  var isStatic: Bool {
    bindingSpecifier.tokenKind == .keyword(Keyword.static)
  }
  
  var isPrivate: Bool {
    bindingSpecifier.tokenKind == .keyword(Keyword.private)
  }
}

extension DeclGroupSyntax {
  /// Get the stored properties from the declaration based on syntax.
  func storedProperties() -> [VariableDeclSyntax] {
    return memberBlock.members.compactMap { member in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
            variable.isStoredProperty else { return nil }
      return variable
    }
  }
  
  func constantProperties() -> [VariableDeclSyntax] {
    return memberBlock.members.compactMap { member in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
            variable.isConstant else { return nil }
      return variable
    }
  }
  
  func privateStaticConstantProperties() -> [VariableDeclSyntax] {
    return memberBlock.members.compactMap { member in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
            variable.isStatic,
            variable.isPrivate,
            variable.isConstant
      else { return nil }
      return variable
    }
  }
}
