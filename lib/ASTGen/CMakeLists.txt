add_pure_swift_host_library(swiftLLVMJSON STATIC EMIT_MODULE
  Sources/LLVMJSON/LLVMJSON.swift

  DEPENDENCIES
    swiftBasic
)

add_pure_swift_host_library(swiftASTGen STATIC
  Sources/ASTGen/ASTGen.swift
  Sources/ASTGen/Decls.swift
  Sources/ASTGen/Diagnostics.swift
  Sources/ASTGen/Exprs.swift
  Sources/ASTGen/Generics.swift
  Sources/ASTGen/Literals.swift
  Sources/ASTGen/Macros.swift
  Sources/ASTGen/Misc.swift
  Sources/ASTGen/PluginHost.swift
  Sources/ASTGen/PluginMessages.swift
  Sources/ASTGen/SourceFile.swift
  Sources/ASTGen/SourceManager.swift
  Sources/ASTGen/SourceManager+MacroExpansionContext.swift
  Sources/ASTGen/Stmts.swift
  Sources/ASTGen/Types.swift

  DEPENDENCIES
    swiftAST
  SWIFT_DEPENDENCIES
    SwiftSyntax::SwiftDiagnostics
    SwiftSyntax::SwiftOperators
    SwiftSyntax::SwiftParser
    SwiftSyntax::SwiftParserDiagnostics
    SwiftSyntax::SwiftSyntax
    SwiftSyntax::SwiftSyntaxMacros
    swiftLLVMJSON
)
