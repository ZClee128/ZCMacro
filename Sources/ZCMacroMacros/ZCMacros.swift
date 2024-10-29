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

@main
struct ZCPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoCodableMacro.self,
        AutoCodableAnnotation.self,
        MirrorMacro.self
    ]
}
