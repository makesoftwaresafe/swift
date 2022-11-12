import SwiftParser
import SwiftSyntax
@_spi(Testing) import _SwiftSyntaxMacros

extension SyntaxProtocol {
  func token(at position: AbsolutePosition) -> TokenSyntax? {
    // If the position isn't within this node at all, return early.
    guard position >= self.position && position < self.endPosition else {
      return nil
    }

    // If we are a token syntax, that's it!
    if let token = Syntax(self).as(TokenSyntax.self) {
      return token
    }

    // Otherwise, it must be one of our children.
    return children(viewMode: .sourceAccurate).lazy.compactMap { child in
      child.token(at: position)
    }.first
  }
}

/// Describes a macro that has been "exported" to the C++ part of the
/// compiler, with enough information to interface with the C++ layer.
struct ExportedMacro {
  var macro: Macro.Type
}

/// Look up a macro with the given name.
///
/// Returns an unmanaged pointer to an ExportedMacro instance that describes
/// the specified macro. If there is no macro with the given name, produces
/// nil.
@_cdecl("swift_ASTGen_lookupMacro")
public func lookupMacro(
  macroNamePtr: UnsafePointer<UInt8>
) -> UnsafeRawPointer? {
  let macroSystem = MacroSystem.exampleSystem

  // Look for a macro with this name.
  let macroName = String(cString: macroNamePtr)
  guard let macro = macroSystem.lookup(macroName) else { return nil }

  // Allocate and initialize the exported macro.
  let exportedPtr = UnsafeMutablePointer<ExportedMacro>.allocate(capacity: 1)
  exportedPtr.initialize(to: .init(macro: macro))
  return UnsafeRawPointer(exportedPtr)
}

/// Destroys the given macro.
@_cdecl("swift_ASTGen_destroyMacro")
public func destroyMacro(
  macroPtr: UnsafeMutablePointer<UInt8>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    macro.deinitialize(count: 1)
    macro.deallocate()
  }
}

/// Allocate a copy of the given string as a UTF-8 string.
private func allocateUTF8String(
  _ string: String,
  nullTerminated: Bool = false
) -> (UnsafePointer<UInt8>, Int) {
  var string = string
  return string.withUTF8 { utf8 in
    let capacity = utf8.count + (nullTerminated ? 1 : 0)
    let ptr = UnsafeMutablePointer<UInt8>.allocate(
      capacity: capacity
    )
    if let baseAddress = utf8.baseAddress {
      ptr.initialize(from: baseAddress, count: utf8.count)
    }

    if nullTerminated {
      ptr[utf8.count] = 0
    }

    return (UnsafePointer<UInt8>(ptr), utf8.count)
  }
}

@_cdecl("swift_ASTGen_getMacroGenericSignature")
public func getMacroGenericSignature(
  macroPtr: UnsafeMutablePointer<UInt8>,
  genericSignaturePtr: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  genericSignatureLengthPtr: UnsafeMutablePointer<Int>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    guard let genericSig = macro.pointee.macro.genericSignature else {
      (genericSignaturePtr.pointee, genericSignatureLengthPtr.pointee) = (nil, 0)
      return
    }

    (genericSignaturePtr.pointee, genericSignatureLengthPtr.pointee) =
      allocateUTF8String(genericSig.description)
  }
}

/// Query the type signature of the given macro.
@_cdecl("swift_ASTGen_getMacroTypeSignature")
public func getMacroTypeSignature(
  macroPtr: UnsafeMutablePointer<UInt8>,
  signaturePtr: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  signatureLengthPtr: UnsafeMutablePointer<Int>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    (signaturePtr.pointee, signatureLengthPtr.pointee) =
        allocateUTF8String(macro.pointee.macro.signature.description)
  }
}

/// Query the documentation of the given macro.
@_cdecl("swift_ASTGen_getMacroDocumentation")
public func getMacroDocumentation(
  macroPtr: UnsafeMutablePointer<UInt8>,
  documentationPtr: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  documentationLengthPtr: UnsafeMutablePointer<Int>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    (documentationPtr.pointee, documentationLengthPtr.pointee) =
        allocateUTF8String(macro.pointee.macro.documentation)
  }
}

/// Query the owning module of the given macro.
@_cdecl("swift_ASTGen_getMacroOwningModule")
public func getMacroOwningModule(
  macroPtr: UnsafeMutablePointer<UInt8>,
  owningModulePtr: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  owningModuleLengthPtr: UnsafeMutablePointer<Int>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    (owningModulePtr.pointee, owningModuleLengthPtr.pointee) =
        allocateUTF8String(macro.pointee.macro.owningModule)
  }
}

/// Query the supplemental signature modules of the given macro,
/// as a semicolon-separated string
@_cdecl("swift_ASTGen_getMacroSupplementalSignatureModules")
public func getMacroSupplementableSignatureModules(
  macroPtr: UnsafeMutablePointer<UInt8>,
  modulesPtr: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  modulesLengthPtr: UnsafeMutablePointer<Int>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    let modules = macro.pointee.macro.supplementalSignatureModules
        .joined(separator: ";")
    (modulesPtr.pointee, modulesLengthPtr.pointee) =
        allocateUTF8String(modules)
  }
}

/// Query the macro evaluation context given the evaluation
/// context sources.
@_cdecl("swift_ASTGen_getMacroEvaluationContext")
public func getMacroEvaluationContext(
  sourceFilePtr: UnsafePointer<UInt8>,
  declContext: UnsafeMutableRawPointer,
  context: UnsafeMutableRawPointer,
  evaluatedSourceBuffer: UnsafePointer<UInt8>,
  evaluatedSourceBufferLength: Int
) -> UnsafeMutableRawPointer? {
  let evaluatedSource = UnsafeBufferPointer(
      start: evaluatedSourceBuffer,
      count: evaluatedSourceBufferLength
  )
  let sourceFile = Parser.parse(source: evaluatedSource)

  // Dig out the top-level typealias declaration. That's all we'll
  // parse.
  guard let typealiasDecl = sourceFile.statements.first(
    where: { item in item.item.is(TypealiasDeclSyntax.self)
    })?.item.as(TypealiasDeclSyntax.self) else {
    return nil
  }

  // Parse and ASTGen that top-level declaration.
  // FIXME: we need to emit diagnostics from this.
  return ASTGenVisitor(
    ctx: context, base: sourceFilePtr, declContext: declContext
  ).visit(typealiasDecl).rawValue
}

@_cdecl("swift_ASTGen_evaluateMacro")
@usableFromInline
func evaluateMacro(
  sourceFilePtr: UnsafePointer<UInt8>,
  sourceLocationPtr: UnsafePointer<UInt8>?,
  expandedSourcePointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  expandedSourceLength: UnsafeMutablePointer<Int>
) -> Int {
  // We didn't expand anything so far.
  expandedSourcePointer.pointee = nil
  expandedSourceLength.pointee = 0

  guard let sourceLocationPtr = sourceLocationPtr else {
    print("NULL source location")
    return -1
  }

  return sourceFilePtr.withMemoryRebound(
    to: ExportedSourceFile.self, capacity: 1
  ) { (sourceFile: UnsafePointer<ExportedSourceFile>) -> Int in
    // Find the offset.
    let buffer = sourceFile.pointee.buffer
    let offset = sourceLocationPtr - buffer.baseAddress!
    if offset < 0 || offset >= buffer.count {
      print("source location isn't inside this buffer")
      return -1
    }

    let sf = sourceFile.pointee.syntax
    guard let token = sf.token(at: AbsolutePosition(utf8Offset: offset)) else {
      print("couldn't find token at offset \(offset)")
      return -1
    }

    guard let parentSyntax = token.parent,
      parentSyntax.is(MacroExpansionExprSyntax.self)
    else {
      print("not on a macro expansion node: \(token.recursiveDescription)")
      return -1
    }

    let macroSystem = MacroSystem.exampleSystem
    let converter = SourceLocationConverter(
      file: sourceFile.pointee.fileName, tree: sf
    )
    let context = MacroEvaluationContext(
      moduleName: sourceFile.pointee.moduleName,
      sourceLocationConverter: converter
    )

    let evaluatedSyntax = parentSyntax.evaluateMacro(
      with: macroSystem, context: context
    ) { error in
      /* TODO: Report errors */
    }

    var evaluatedSyntaxStr = evaluatedSyntax.withoutTrivia().description
    evaluatedSyntaxStr.withUTF8 { utf8 in
      let evaluatedResultPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: utf8.count + 1)
      if let baseAddress = utf8.baseAddress {
        evaluatedResultPtr.initialize(from: baseAddress, count: utf8.count)
      }
      evaluatedResultPtr[utf8.count] = 0

      expandedSourcePointer.pointee = UnsafePointer(evaluatedResultPtr)
      expandedSourceLength.pointee = utf8.count
    }

    return 0
  }
}

/// Calls the given `allMacros: [Any.Type]` function pointer and produces a
/// newly allocated buffer containing metadata pointers.
@_cdecl("swift_ASTGen_getMacroTypes")
@usableFromInline
func getMacroTypes(
  getterAddress: UnsafeRawPointer,
  resultAddress: UnsafeMutablePointer<UnsafePointer<UnsafeRawPointer>?>,
  count: UnsafeMutablePointer<Int>
) {
  let getter = unsafeBitCast(
    getterAddress, to: (@convention(thin) () -> [Any.Type]).self)
  let metatypes = getter()
  let address = UnsafeMutableBufferPointer<Any.Type>.allocate(
    capacity: metatypes.count
  )
  _ = address.initialize(from: metatypes)
  address.withMemoryRebound(to: UnsafeRawPointer.self) {
    resultAddress.initialize(to: UnsafePointer($0.baseAddress))
  }
  count.initialize(to: address.count)
}
