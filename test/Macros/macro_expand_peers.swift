// REQUIRES: swift_swift_parser, executable_test

// RUN: %empty-directory(%t)
// RUN: %host-build-swift -swift-version 5 -emit-library -o %t/%target-library-name(MacroDefinition) -parse-as-library -module-name=MacroDefinition %S/Inputs/syntax_macro_definitions.swift -g -no-toolchain-stdlib-rpath
// RUN: %target-typecheck-verify-swift -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -parse-as-library -disable-availability-checking

// Check with the imported macro library vs. the local declaration of the macro.
// RUN: %target-swift-frontend -swift-version 5 -emit-module -o %t/macro_library.swiftmodule %S/Inputs/macro_library.swift -module-name macro_library -load-plugin-library %t/%target-library-name(MacroDefinition)

// RUN: %target-typecheck-verify-swift -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -parse-as-library -disable-availability-checking -DIMPORT_MACRO_LIBRARY -I %t


// RUN: %target-swift-frontend -swift-version 5 -typecheck -load-plugin-library %t/%target-library-name(MacroDefinition) -parse-as-library %s -disable-availability-checking -dump-macro-expansions > %t/expansions-dump.txt 2>&1
// RUN: %FileCheck -check-prefix=CHECK-DUMP %s < %t/expansions-dump.txt

// RUN: %target-build-swift -swift-version 5 -Xfrontend -disable-availability-checking -load-plugin-library %t/%target-library-name(MacroDefinition) -parse-as-library %s -o %t/main -module-name MacroUser
// RUN: %target-run %t/main | %FileCheck %s -check-prefix=CHECK-EXEC

// Emit module while skipping function bodies
// RUN: %target-swift-frontend -swift-version 5 -emit-module -load-plugin-library %t/%target-library-name(MacroDefinition) -parse-as-library %s -disable-availability-checking -o %t/macro_expand_peers.swiftmodule -experimental-skip-non-inlinable-function-bodies-without-types

#if IMPORT_MACRO_LIBRARY
import macro_library
#else
@attached(peer, names: overloaded)
macro addCompletionHandler() = #externalMacro(module: "MacroDefinition", type: "AddCompletionHandler")
@attached(peer, names: suffixed(Builder))
macro AddClassReferencingSelf() = #externalMacro(module: "MacroDefinition", type: "AddClassReferencingSelfMacro")
#endif

struct S {
  @addCompletionHandler
  func f(a: Int, for b: String, _ value: Double) async -> String {
    return b
  }

  // CHECK-DUMP: @__swiftmacro_18macro_expand_peers1SV1f1a3for_SSSi_SSSdtYaF20addCompletionHandlerfMp_.swift
  // CHECK-DUMP: func f(a: Int, for b: String, _ value: Double, completionHandler: @escaping (String) -> Void) {
  // CHECK-DUMP:   Task {
  // CHECK-DUMP:     completionHandler(await f(a: a, for: b, value))
  // CHECK-DUMP:   }
  // CHECK-DUMP: }

  func useOverload(_ body: @escaping (String) -> Void) {
    self.f(a: 1, for: "hahaha local", 2.0) {
      body($0)
    }
  }
}

extension S {
  @addCompletionHandler
  func g(a: Int, for b: String, _ value: Double) async -> String {
    return b
  }

  // CHECK-DUMP: @__swiftmacro_18macro_expand_peers1SV1g1a3for_SSSi_SSSdtYaF20addCompletionHandlerfMp_.swift
  // CHECK-DUMP: func f(a: Int, for b: String, _ value: Double, completionHandler: @escaping (String) -> Void) {
  // CHECK-DUMP:   Task {
  // CHECK-DUMP:     completionHandler(await f(a: a, for: b, value))
  // CHECK-DUMP:   }
  // CHECK-DUMP: }

}

func useCompletionHandlerG(s: S, _ body: @escaping (String) -> Void) {
  s.g(a: 1, for: "hahaha local", 2.0) {
    body($0)
  }
}

@addCompletionHandler
func f(a: Int, for b: String, _ value: Double) async -> String {
  return b
}

func useOverload(_ body: @escaping (String) -> Void) {
  f(a: 1, for: "hahaha global", 2.0) {
    body($0)
  }
}

@attached(peer)
macro wrapInType() = #externalMacro(module: "MacroDefinition", type: "WrapInType")

@wrapInType
func global(a: Int, b: String) {
  print(a, b)
}

// CHECK-DUMP: @__swiftmacro_18macro_expand_peers6global1a1bySi_SStF10wrapInTypefMp_.swift
// CHECK-DUMP: struct $s18macro_expand_peers6global1a1bySi_SStF10wrapInTypefMp_6globalfMu0_ {
// CHECK-DUMP:   func $s18macro_expand_peers6global1a1bySi_SStF10wrapInTypefMp_6globalfMu_(a: Int, b: String)  {
// CHECK-DUMP:     global(a: a, b: b)
// CHECK-DUMP:   }
// CHECK-DUMP: }

@main
struct Main {
  static func main() async {
    let result1 = await withCheckedContinuation { cont in
      S().useOverload {
        cont.resume(returning: $0)
      }
    }
    print(result1)
    // CHECK-EXEC: hahaha local
    let result2 = await withCheckedContinuation { cont in
      useOverload {
        cont.resume(returning: $0)
      }
    }
    print(result2)
    // CHECK-EXEC: hahaha global
  }
}

@AddClassReferencingSelf
protocol MyProto { }
