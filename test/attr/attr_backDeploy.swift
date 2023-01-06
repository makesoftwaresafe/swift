// RUN: %target-typecheck-verify-swift -parse-as-library \
// RUN:   -define-availability "_myProject 2.0:macOS 12.0"

// MARK: - Valid declarations

// Ok, top level functions
@_backDeploy(before: macOS 12.0)
public func backDeployedTopLevelFunc() {}

// Ok, internal decls may be back deployed when @usableFromInline
@_backDeploy(before: macOS 12.0)
@usableFromInline
internal func backDeployedUsableFromInlineTopLevelFunc() {}

// Ok, function/property/subscript decls in a struct
public struct TopLevelStruct {
  @_backDeploy(before: macOS 12.0)
  public func backDeployedMethod() {}

  @_backDeploy(before: macOS 12.0)
  public var backDeployedComputedProperty: Int { 98 }

  @_backDeploy(before: macOS 12.0)
  public subscript(_ index: Int) -> Int { index }

  @_backDeploy(before: macOS 12.0)
  public var readWriteProperty: Int {
    get { 42 }
    set(newValue) {}
  }

  @_backDeploy(before: macOS 12.0)
  public subscript(at index: Int) -> Int {
    get { 42 }
    set(newValue) {}
  }

  public var explicitReadAndModify: Int {
    @_backDeploy(before: macOS 12.0)
    _read { yield 42 }

    @_backDeploy(before: macOS 12.0)
    _modify {}
  }
}

// Ok, final function decls in a non-final class
public class TopLevelClass {
  @_backDeploy(before: macOS 12.0)
  final public func backDeployedFinalMethod() {}

  @_backDeploy(before: macOS 12.0)
  final public var backDeployedFinalComputedProperty: Int { 98 }

  @_backDeploy(before: macOS 12.0)
  public static func backDeployedStaticMethod() {}

  @_backDeploy(before: macOS 12.0)
  public final class func backDeployedClassMethod() {}
}

// Ok, function decls in a final class
final public class FinalTopLevelClass {
  @_backDeploy(before: macOS 12.0)
  public func backDeployedMethod() {}

  @_backDeploy(before: macOS 12.0)
  public var backDeployedComputedProperty: Int { 98 }
}

// Ok, final function decls on an actor
@available(SwiftStdlib 5.1, *)
public actor TopLevelActor {
  @_backDeploy(before: macOS 12.0)
  final public func finalActorMethod() {}

  // Ok, actor methods are effectively final
  @_backDeploy(before: macOS 12.0)
  public func actorMethod() {}
}

// Ok, function decls in extension on public types
extension TopLevelStruct {
  @_backDeploy(before: macOS 12.0)
  public func backDeployedExtensionMethod() {}
}

extension TopLevelClass {
  @_backDeploy(before: macOS 12.0)
  final public func backDeployedExtensionMethod() {}
}

extension FinalTopLevelClass {
  @_backDeploy(before: macOS 12.0)
  public func backDeployedExtensionMethod() {}
}

public protocol TopLevelProtocol {}

extension TopLevelProtocol {
  @_backDeploy(before: macOS 12.0)
  public func backDeployedExtensionMethod() {}
}


// MARK: - Unsupported declaration kinds

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
public class CannotBackDeployClass {}

public final class CannotBackDeployClassInitDeinit {
  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to initializer declarations}}
  public init() {}

  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to deinitializer declarations}}
  deinit {}
}

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
public struct CannotBackDeployStruct {
  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' must not be used on stored properties}}
  public var cannotBackDeployStoredProperty: Int = 83

  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' must not be used on stored properties}}
  public lazy var cannotBackDeployLazyStoredProperty: Int = 15
}

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
public enum CannotBackDeployEnum {
  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
  case cannotBackDeployEnumCase
}

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' must not be used on stored properties}}
public var cannotBackDeployTopLevelVar = 79

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
extension TopLevelStruct {}

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
protocol CannotBackDeployProtocol {}

@available(SwiftStdlib 5.1, *)
@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' attribute cannot be applied to this declaration}}
public actor CannotBackDeployActor {}


// MARK: - Function body diagnostics

public struct FunctionBodyDiagnostics {
  public func publicFunc() {}
  @usableFromInline func usableFromInlineFunc() {}
  func internalFunc() {} // expected-note {{instance method 'internalFunc()' is not '@usableFromInline' or public}}
  fileprivate func fileprivateFunc() {} // expected-note {{instance method 'fileprivateFunc()' is not '@usableFromInline' or public}}
  private func privateFunc() {} // expected-note {{instance method 'privateFunc()' is not '@usableFromInline' or public}}

  @_backDeploy(before: macOS 12.0)
  public func backDeployedMethod() {
    struct Nested {} // expected-error {{type 'Nested' cannot be nested inside a '@_backDeploy' function}}

    publicFunc()
    usableFromInlineFunc()
    internalFunc() // expected-error {{instance method 'internalFunc()' is internal and cannot be referenced from a '@_backDeploy' function}}
    fileprivateFunc() // expected-error {{instance method 'fileprivateFunc()' is fileprivate and cannot be referenced from a '@_backDeploy' function}}
    privateFunc() // expected-error {{instance method 'privateFunc()' is private and cannot be referenced from a '@_backDeploy' function}}
  }
}


// MARK: - Incompatible declarations

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' may not be used on fileprivate declarations}}
fileprivate func filePrivateFunc() {}

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' may not be used on private declarations}}
private func privateFunc() {}

@_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' may not be used on internal declarations}}
internal func internalFunc() {}

private struct PrivateTopLevelStruct {
  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' may not be used on private declarations}}
  public func effectivelyPrivateFunc() {}
}

public class TopLevelClass2 {
  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' cannot be applied to a non-final instance method}}
  public func nonFinalMethod() {}

  @_backDeploy(before: macOS 12.0) // expected-error {{'@_backDeploy' cannot be applied to a non-final class method}}
  public class func nonFinalClassMethod() {}
}

@_backDeploy(before: macOS 12.0, macOS 13.0) // expected-error {{'@_backDeploy' contains multiple versions for macOS}}
public func duplicatePlatformsFunc1() {}

@_backDeploy(before: macOS 12.0)
@_backDeploy(before: macOS 13.0) // expected-error {{'@_backDeploy' contains multiple versions for macOS}}
public func duplicatePlatformsFunc2() {}

@_backDeploy(before: macOS 12.0)
@_alwaysEmitIntoClient // expected-error {{'@_alwaysEmitIntoClient' cannot be applied to a back deployed global function}}
public func alwaysEmitIntoClientFunc() {}

@_backDeploy(before: macOS 12.0)
@inlinable // Ok
public func inlinableFunc() {}

@_backDeploy(before: macOS 12.0)
@_transparent // expected-error {{'@_transparent' cannot be applied to a back deployed global function}}
public func transparentFunc() {}


// MARK: - Attribute parsing

@_backDeploy(before: macos 12.0, iOS 15.0) // expected-warning {{unknown platform 'macos' for attribute '@_backDeploy'; did you mean 'macOS'?}} {{22-27=macOS}}
public func incorrectPlatformCaseFunc() {}

@_backDeploy(before: mscos 12.0, iOS 15.0) // expected-warning {{unknown platform 'mscos' for attribute '@_backDeploy'; did you mean 'macOS'?}} {{22-27=macOS}}
public func incorrectPlatformSimilarFunc() {}

@_backDeploy(before: macOS 12.0, unknownOS 1.0) // expected-warning {{unknown platform 'unknownOS' for attribute '@_backDeploy'}}
public func unknownOSFunc() {}

@_backDeploy(before: @) // expected-error {{expected platform in '@_backDeploy' attribute}}
public func badPlatformFunc1() {}

@_backDeploy(before: @ 12.0) // expected-error {{expected platform in '@_backDeploy' attribute}}
public func badPlatformFunc2() {}

@_backDeploy(before: macOS) // expected-error {{expected version number in '@_backDeploy' attribute}}
public func missingVersionFunc1() {}

@_backDeploy(before: macOS 12.0, iOS) // expected-error {{expected version number in '@_backDeploy' attribute}}
public func missingVersionFunc2() {}

@_backDeploy(before: macOS, iOS) // expected-error 2{{expected version number in '@_backDeploy' attribute}}
public func missingVersionFunc3() {}

@_backDeploy(before: macOS 12.0, iOS 15.0,) // expected-error {{unexpected ',' separator}}
public func unexpectedSeparatorFunc() {}

@_backDeploy(before: macOS 12.0.1) // expected-warning {{'@_backDeploy' only uses major and minor version number}}
public func patchVersionFunc() {}

@_backDeploy(before: macOS 12.0, * 9.0) // expected-warning {{* as platform name has no effect in '@_backDeploy' attribute}}
public func wildcardWithVersionFunc() {}

@_backDeploy(before: macOS 12.0, *) // expected-warning {{* as platform name has no effect in '@_backDeploy' attribute}}
public func trailingWildcardFunc() {}

@_backDeploy(before: macOS 12.0, *, iOS 15.0) // expected-warning {{* as platform name has no effect in '@_backDeploy' attribute}}
public func embeddedWildcardFunc() {}

@_backDeploy(before: _myProject 3.0) // expected-error {{reference to undefined version '3.0' for availability macro '_myProject'}}
public func macroVersioned() {}

@_backDeploy(before: _myProject) // expected-error {{reference to undefined version '0' for availability macro '_myProject'}}
public func missingMacroVersion() {}

// Fall back to the default diagnostic when the macro is unknown.
@_backDeploy(before: _unknownMacro) // expected-warning {{unknown platform '_unknownMacro' for attribute '@_backDeploy'}}
// expected-error@-1 {{expected version number in '@_backDeploy' attribute}}
public func unknownMacroMissingVersion() {}

@_backDeploy(before: _unknownMacro 1.0) // expected-warning {{unknown platform '_unknownMacro' for attribute '@_backDeploy'}}
// expected-error@-1 {{expected at least one platform version in '@_backDeploy' attribute}}
public func unknownMacroVersioned() {}

@_backDeploy(before: _unknownMacro 1.0, _myProject 2.0) // expected-warning {{unknown platform '_unknownMacro' for attribute '@_backDeploy'}}
public func knownAndUnknownMacroVersioned() {}

@_backDeploy() // expected-error {{expected 'before:' in '@_backDeploy' attribute}}
// expected-error@-1 {{expected at least one platform version in '@_backDeploy' attribute}}
public func emptyAttributeFunc() {}

@_backDeploy(macOS 12.0) // expected-error {{expected 'before:' in '@_backDeploy' attribute}} {{14-14=before:}}
public func missingBeforeFunc() {}

@_backDeploy(before) // expected-error {{expected ':' after 'before' in '@_backDeploy' attribute}} {{20-20=:}}
// expected-error@-1 {{expected at least one platform version in '@_backDeploy' attribute}}
public func missingColonAfterBeforeFunc() {}

@_backDeploy(before macOS 12.0) // expected-error {{expected ':' after 'before' in '@_backDeploy' attribute}} {{20-20=:}}
public func missingColonBetweenBeforeAndPlatformFunc() {}

@_backDeploy(before: macOS 12.0,) // expected-error {{unexpected ',' separator}} {{32-33=}}
public func unexpectedTrailingCommaFunc() {}

@_backDeploy(before: macOS 12.0,, iOS 15.0) // expected-error {{unexpected ',' separator}} {{33-34=}}
public func extraCommaFunc() {}

@_backDeploy(before:) // expected-error {{expected at least one platform version in '@_backDeploy' attribute}}
public func emptyPlatformVersionsFunc() {}

@_backDeploy // expected-error {{expected '(' in '@_backDeploy' attribute}}
public func expectedLeftParenFunc() {}

@_backDeploy(before: macOS 12.0 // expected-note {{to match this opening '('}}
public func expectedRightParenFunc() {} // expected-error {{expected ')' in '@_backDeploy' argument list}}
