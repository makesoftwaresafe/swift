// RUN: %empty-directory(%t)
// RUN: %target-build-swift -I %swift-host-lib-dir -L %swift-host-lib-dir -emit-library -o %t/%target-library-name(MacroDefinition) -module-name=MacroDefinition %S/Inputs/syntax_macro_definitions.swift -g -no-toolchain-stdlib-rpath
// RUNx: %target-swift-frontend -dump-ast -enable-experimental-feature Macros -enable-experimental-feature Macros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir %s -module-name MacroUser 2>&1 | %FileCheck --check-prefix CHECK-AST %s

// Diagnostics testing
// RUN: %target-typecheck-verify-swift -enable-experimental-feature Macros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -module-name MacroUser -DTEST_DIAGNOSTICS

// RUN: not %target-swift-frontend -typecheck -enable-experimental-feature Macros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -module-name MacroUser -DTEST_DIAGNOSTICS -serialize-diagnostics-path %t/macro_expand.dia %s
// RUN: c-index-test -read-diagnostics %t/macro_expand.dia 2>&1 | %FileCheck -check-prefix CHECK-DIAGS %s

// Execution testing
// RUN: %target-build-swift -enable-experimental-feature Macros -enable-experimental-feature Macros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -L %swift-host-lib-dir %s -o %t/main -module-name MacroUser
// RUN: %target-run %t/main | %FileCheck %s
// REQUIRES: executable_test

// FIXME: Swift parser is not enabled on Linux CI yet.
// REQUIRES: OS=macosx

@expression macro customFileID: String = #externalMacro(module: "MacroDefinition", type: "FileIDMacro")
@expression macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")
@expression macro fileID<T: ExpressibleByStringLiteral>: T = #externalMacro(module: "MacroDefinition", type: "FileIDMacro")
@expression macro recurse(_: Bool) = #externalMacro(module: "MacroDefinition", type: "RecursiveMacro")

func testFileID(a: Int, b: Int) {
  // CHECK: MacroUser/macro_expand.swift
  print("Result is \(#customFileID)")

  // CHECK: Builtin result is MacroUser/macro_expand.swift
  // CHECK-AST: macro_expansion_expr type='String'{{.*}}name=line
  print("Builtin result is \(#fileID)")
}

testFileID(a: 1, b: 2)

func testStringify(a: Int, b: Int) {
  let s = #stringify(a + b)
  print(s)

  // CHECK-AST: macro_expansion_expr type='(Int, String)'{{.*}}name=stringify
  // CHECK-AST-NEXT: argument_list
  // CHECK-AST: tuple_expr type='(Int, String)' location=Macro expansion of #stringify

  let (b, s2) = #stringify({ () -> Bool in return true })
  // CHECK-AST: macro_expansion_expr type='(() -> Bool, String)'{{.*}}name=stringify
  // CHECK-AST-NEXT: argument_list
  // CHECK-AST: tuple_expr type='(() -> Bool, String)' location=Macro expansion of #stringify

  let (b2, s3) = #stringify<Double>(1 + 2)
  // CHECK-AST: macro_expansion_expr type='(Double, String)'{{.*}}name=stringify
  // CHECK-AST-NEXT: argument_list
  // CHECK-AST: tuple_expr type='(Double, String)' location=Macro expansion of #stringify

  _ = (b, b2, s2, s3)
}

struct Outer {
  var value: Int = 0
  func test() {
    _ = #stringify(1 + value)

    _ = #stringify({ x in
      x + 1
    })
  }
}

// CHECK: (2, "a + b")
testStringify(a: 1, b: 1)

@expression macro addBlocker<T>(_ value: T) -> T = #externalMacro(module: "MacroDefinition", type: "AddBlocker")

struct OnlyAdds {
  static func +(lhs: OnlyAdds, rhs: OnlyAdds) -> OnlyAdds { lhs }
}

func testAddBlocker(a: Int, b: Int, c: Int, oa: OnlyAdds) {
  _ = #addBlocker(a * b * c)
#if TEST_DIAGNOSTICS
  _ = #addBlocker(a + b * c) // expected-error{{blocked an add; did you mean to subtract? (from macro 'addBlocker')}}
  // expected-note@-1{{use '-'}}{{21-22=-}}
  _ = #addBlocker(oa + oa) // expected-error{{blocked an add; did you mean to subtract? (from macro 'addBlocker')}}
  // expected-note@-1{{in expansion of macro 'addBlocker' here}}
  // expected-note@-2{{use '-'}}{{22-23=-}}

  // CHECK-DIAGS: macro_expand.swift:81:7-81:27:1:4: error: binary operator '-' cannot be applied to two 'OnlyAdds' operands [] []
  // CHECK-DIAGS: CONTENTS OF FILE{{.*}}addBlocker
  // CHECK-DIAGS-NEXT: Original source range: {{.*}}macro_expand.swift:81:7 - {{.*}}macro_expand.swift:81:27
  // CHECK-DIAGS-NEXT: oa - oa
  // CHECK-DIAGS-NEXT: END CONTENTS OF FILE
  // Check recursion.
  #recurse(false) // okay
  #recurse(true) // expected-note{{in expansion of macro 'recurse' here}}
#endif
}

// Make sure we don't crash with declarations produced by expansions.
@expression macro nestedDeclInExpr: () -> Void = #externalMacro(module: "MacroDefinition", type: "NestedDeclInExprMacro")

func testNestedDeclInExpr() {
  let _: () -> Void = #nestedDeclInExpr
}

@declaration(freestanding) macro bitwidthNumberedStructs(_ baseName: String) = #externalMacro(module: "MacroDefinition", type: "DefineBitwidthNumberedStructsMacro")
// Test overload
@declaration(freestanding) macro bitwidthNumberedStructs(_ baseName: String, blah: Bool) = #externalMacro(module: "MacroDefinition", type: "DefineBitwidthNumberedStructsMacro")

// FIXME: Declaration macro expansions in BraceStmt don't work yet.
//#bitwidthNumberedStructs("MyIntGlobal")

func testFreestandingMacroExpansion() {
  // Explicit structs to force macros to be parsed as decl.
  struct Foo {
    #bitwidthNumberedStructs("MyIntOne")
  }
  // CHECK: MyIntOne8
  print(Foo.MyIntOne8.self)
  // CHECK: MyIntOne16
  print(Foo.MyIntOne16.self)
  // CHECK: MyIntOne32
  print(Foo.MyIntOne32.self)
  // CHECK: MyIntOne64
  print(Foo.MyIntOne64.self)

  struct Foo2 {
    #bitwidthNumberedStructs("MyIntTwo", blah: false)
  }
  // CHECK: MyIntTwo8
  print(Foo2.MyIntTwo8.self)
  // CHECK: MyIntTwo16
  print(Foo2.MyIntTwo16.self)
  // CHECK: MyIntTwo32
  print(Foo2.MyIntTwo32.self)
  // CHECK: MyIntTwo64
  print(Foo2.MyIntTwo64.self)

  // FIXME: Declaration macro expansions in BraceStmt don't work yet.
//  HECK: MyIntGlobal8
//  print(MyIntGlobal8.self)
//  HECK: MyIntGlobal16
//  print(MyIntGlobal16.self)
//  HECK: MyIntGlobal32
//  print(MyIntGlobal32.self)
//  HECK: MyIntGlobal64
//  print(MyIntGlobal64.self)
}
testFreestandingMacroExpansion()
