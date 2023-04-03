// REQUIRES: swift_swift_parser, executable_test

// RUN: %empty-directory(%t)
// RUN: %host-build-swift -swift-version 5 -emit-library -o %t/%target-library-name(MacroDefinition) -module-name=MacroDefinition %S/Inputs/variadic_macros.swift -g -no-toolchain-stdlib-rpath
// RUN: %target-typecheck-verify-swift -swift-version 5 -enable-experimental-feature VariadicGenerics -load-plugin-library %t/%target-library-name(MacroDefinition) -module-name MacroUser -DTEST_DIAGNOSTICS -swift-version 5
// RUN: %target-build-swift -swift-version 5 -enable-experimental-feature VariadicGenerics -load-plugin-library %t/%target-library-name(MacroDefinition) %s -o %t/main -module-name MacroUser -swift-version 5
// RUN: %target-run %t/main | %FileCheck %s

@freestanding(expression) macro print<each Value>(_ value: repeat each Value) = #externalMacro(module: "MacroDefinition", type: "PrintMacro")

func testIt() {
  // CHECK: hello
  // CHECK: [1, 2, 3, 4, 5]
  #print("hello", [1, 2, 3, 4, 5])

  // CHECK: world
  #print("world")
}

testIt()
