// RUN: %empty-directory(%t)

// RUN: %target-build-swift-dylib(%t/%target-library-name(variadic_generic_library)) -Xfrontend -disable-availability-checking -enable-experimental-feature VariadicGenerics -enable-library-evolution %S/Inputs/variadic_generic_library.swift -emit-module -emit-module-path %t/variadic_generic_library.swiftmodule -module-name variadic_generic_library
// RUN: %target-codesign %t/%target-library-name(variadic_generic_library)

// RUN: %target-build-swift %s -Xfrontend -disable-availability-checking -enable-experimental-feature VariadicGenerics -lvariadic_generic_library -I %t -L %t -o %t/main %target-rpath(%t)
// RUN: %target-codesign %t/main

// RUN: %target-run %t/main %t/%target-library-name(variadic_generic_library)

// REQUIRES: executable_test

// FIXME: Optimizations disabled for all parameter pack tests in test/Interpreter/
// REQUIRES: swift_test_mode_optimize_none

// Because of -enable-experimental-feature VariadicGenerics
// REQUIRES: asserts


import variadic_generic_library
import StdlibUnittest

var ImportParameterPackTests = TestSuite("ImportParameterPackTests")

ImportParameterPackTests.test("basic") {
  let closure: (Variable<Int>) -> _ = { a in
    True()
  }

  let predicate = Predicate.init(builder: closure)
  let result = try! predicate.evaluate(1)
  expectEqual(result, true)
}

ImportParameterPackTests.test("no inputs") {
  let closure: () -> _ = {
    True()
  }

  let predicate = Predicate.init(builder: closure)
  let result = try! predicate.evaluate()
  expectEqual(result, true)
}


ImportParameterPackTests.test("multi-input") {
  let closure: (Variable<Int>, Variable<String>, Variable<Bool>) -> _ = { a, b, c in
    True()
  }

  let predicate = Predicate<Int, String, Bool>(builder: closure)
  let result = try! predicate.evaluate(1, "hello", true)
  expectEqual(result, true)
}

runAllTests()
