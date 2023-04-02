// RUN: %target-run-simple-swift(-Xfrontend -sil-verify-all)

// REQUIRES: executable_test

import StdlibUnittest

defer { runAllTests() }

var Tests = TestSuite("MoveOnlyTests")

@_moveOnly
struct FD {
  var a = LifetimeTracked(0)

  deinit {
  }
}

Tests.test("simple deinit called once") {
  do {
    let s = FD()
  }
  expectEqual(0, LifetimeTracked.instances)
}

Tests.test("ref element addr destroyed once") {
  class CopyableKlass {
    var fd = FD()
  }

  func assignCopyableKlass(_ x: CopyableKlass) {
    x.fd = FD()
  }

  do {
    let x = CopyableKlass()
    assignCopyableKlass(x)
  }
  expectEqual(0, LifetimeTracked.instances)
}

var global = FD()

Tests.test("global destroyed once") {
  do {
    global = FD()
  }
  expectEqual(0, LifetimeTracked.instances)    
}

// TODO (rdar://107494072): Move-only types with deinits declared inside
// functions sometimes lose their deinit function.
// When that's fixed, FD2 can be moved back inside the test closure below.
@_moveOnly
struct FD2 {
  var field = 5
  static var count = 0
  init() { FD2.count += 1 }
  deinit {
    FD2.count -= 1
    print("In deinit!")
  }
  func use() {}
}

Tests.test("deinit not called in init when assigned") {
  class FDHaver {
    var fd: FD2

    init() {
      self.fd = FD2()
    }
  }

  class FDHaver2 {
    var fd: FD2

    init() {
      self.fd = FD2()
      self.fd = FD2()
      self.fd = FD2()
      self.fd.use()
    }
  }

  do {
    let haver = FDHaver2()
    let _ = haver
  }
  expectEqual(0, FD2.count)
}
