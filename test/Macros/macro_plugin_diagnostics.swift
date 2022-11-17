// RUN: %empty-directory(%t)
// RUN: %target-build-swift -Xfrontend -disable-availability-checking -I %swift-lib-dir -L %swift-lib-dir -emit-library -emit-library-path=%t/%target-library-name(MacroDefinitionMissingAllMacros) -working-directory=%t -module-name=MacroDefinitionMissingAllMacros %S/Inputs/macro_definition_missing_allmacros.swift
// RUN: %target-build-swift -Xfrontend -disable-availability-checking -I %swift-lib-dir -L %swift-lib-dir -emit-library -emit-library-path=%t/%target-library-name(MacroDefinition) -working-directory=%t -module-name=MacroDefinition %S/Inputs/macro_definition.swift
// RUN: %target-swift-frontend -I %swift-lib-dir -L %swift-lib-dir -enable-experimental-feature Macros -load-plugin-library %t/%target-library-name(MacroDefinition) -load-plugin-library %t/%target-library-name(MacroDefinitionMissingAllMacros) -disable-availability-checking -typecheck -verify -primary-file %s 2>&1 | %FileCheck %s

// FIXME: Swift parser is not enabled on Linux CI yet.
// REQUIRES: OS=macosx

// rdar://102160067
// UNSUPPORTED: CPU=arm64e

// CHECK: <unknown>:{{.*}}: warning: compiler plugin module 'MacroDefinitionMissingAllMacros' (in {{.*}}/libMacroDefinitionMissingAllMacros.dylib) is missing a top-level computed property 'public var allMacros: [Any.Type]' to declare all macros; undeclared macros will be ignored

// expected-note @+2 {{test note}}
// expected-warning @+1 {{test warning}}
let _ = #customStringify(1.byteSwapped + 2.advanced(by: 10))

// expected-note @+2 {{test note}}
// expected-warning @+1 {{test warning}}
let _ = #customStringify(1.0.truncatingRemainder(dividingBy: 1.0) + 3.0)

// expected-note @+1 {{test note}}
let _ = #customStringify(
  ["a", "b", "c"] +
// expected-warning @+1 {{test warning}}
  ["d", "e", "f"])

// expected-error @+1 {{macro 'notDefined' is undefined; use `-load-plugin-library` to specify dynamic libraries that contain this macro}}
let _ = #notDefined

// expected-error @+1 {{macro 'dummy' is undefined; use `-load-plugin-library` to specify dynamic libraries that contain this macro}}
let _ = #dummy
