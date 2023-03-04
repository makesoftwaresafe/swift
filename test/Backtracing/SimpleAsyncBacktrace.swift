// RUN: %empty-directory(%t)
// RUN: %target-build-swift %s -g -parse-as-library -Onone -o %t/SimpleAsyncBacktrace
// RUN: %target-codesign %t/SimpleAsyncBacktrace
// RUN: %target-run %t/SimpleAsyncBacktrace | %FileCheck %s

// REQUIRES: concurrency
// REQUIRES: executable_test
// REQUIRES: OS=macosx
// REQUIRES: concurrency_runtime
// UNSUPPORTED: back_deployment_runtime

import _Backtracing

@available(SwiftStdlib 5.1, *)
func level1() async {
  await level2()
}

@available(SwiftStdlib 5.1, *)
func level2() async {
  level3()
}

@available(SwiftStdlib 5.1, *)
func level3() {
  level4()
}

@available(SwiftStdlib 5.1, *)
func level4() {
  level5()
}

@available(SwiftStdlib 5.1, *)
func level5() {
  let backtrace = try! Backtrace.capture()

  // CHECK:      0{{[ \t]+}}0x{{[0-9a-f]+}} [ra]
  // CHECK-NEXT: 1{{[ \t]+}}0x{{[0-9a-f]+}} [ra]
  // CHECK-NEXT: 2{{[ \t]+}}0x{{[0-9a-f]+}} [ra]
  // CHECK-NEXT: 3{{[ \t]+}}0x{{[0-9a-f]+}} [ra]
  // CHECK-NEXT: 4{{[ \t]+}}0x{{[0-9a-f]+}} [async]
  // CHECK-NEXT: 5{{[ \t]+}}0x{{[0-9a-f]+}} [async]

  print(backtrace)
}

@available(SwiftStdlib 5.1, *)
@main
struct SimpleAsyncBacktrace {
  static func main() async {
    await level1()
  }
}
