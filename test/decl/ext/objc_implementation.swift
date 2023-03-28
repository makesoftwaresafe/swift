// RUN: %target-typecheck-verify-swift -import-objc-header %S/Inputs/objc_implementation.h
// REQUIRES: objc_interop

@_objcImplementation extension ObjCClass {
  // expected-note@-1 {{previously implemented by extension here}}
  // expected-error@-2 {{extension for main class interface should provide implementation for instance method 'method(fromHeader4:)'}}
  // expected-error@-3 {{extension for main class interface should provide implementation for property 'propertyFromHeader9'}}
  // FIXME: give better diagnostic expected-error@-4 {{extension for main class interface should provide implementation for property 'propertyFromHeader8'}}
  // FIXME: give better diagnostic expected-error@-5 {{extension for main class interface should provide implementation for property 'propertyFromHeader7'}}
  // FIXME: give better diagnostic expected-error@-6 {{extension for main class interface should provide implementation for instance method 'method(fromHeader3:)'}}

  func method(fromHeader1: CInt) {
    // OK, provides an implementation for the header's method.
  }

  @objc func method(fromHeader2: CInt) {
    // OK, provides an implementation for the header's method.
  }

  func categoryMethod(fromHeader3: CInt) {
    // FIXME: should emit expected-DISABLED-error@-1 {{instance method 'categoryMethod(fromHeader3:)' should be implemented in extension for category 'PresentAdditions', not main class interface}}
    // FIXME: expected-error@-2 {{instance method 'categoryMethod(fromHeader3:)' does not match any instance method declared in the headers for 'ObjCClass'; did you use the instance method's Swift name?}}
    // FIXME: expected-note@-3 {{add 'private' or 'fileprivate' to define an Objective-C-compatible instance method not declared in the header}} {{3-3=private }}
    // FIXME: expected-note@-4 {{add 'final' to define a Swift instance method that cannot be overridden}} {{3-3=final }}
  }

  @objc fileprivate func methodNot(fromHeader1: CInt) {
    // OK, declares a new @objc dynamic method.
  }

  final func methodNot(fromHeader2: CInt) {
    // OK, declares a new Swift method.
  }

  func methodNot(fromHeader3: CInt) {
    // expected-error@-1 {{instance method 'methodNot(fromHeader3:)' does not match any instance method declared in the headers for 'ObjCClass'; did you use the instance method's Swift name?}}
    // expected-note@-2 {{add 'private' or 'fileprivate' to define an Objective-C-compatible instance method not declared in the header}} {{3-3=private }}
    // expected-note@-3 {{add 'final' to define a Swift instance method that cannot be overridden}} {{3-3=final }}
  }

  var propertyFromHeader1: CInt
  // OK, provides an implementation with a stored property

  @objc var propertyFromHeader2: CInt
  // OK, provides an implementation with a stored property

  var propertyFromHeader3: CInt {
    // OK, provides an implementation with a computed property
    get { return 1 }
    set {}
  }

  @objc var propertyFromHeader4: CInt {
    // OK, provides an implementation with a computed property
    get { return 1 }
    set {}
  }

  @objc let propertyFromHeader5: CInt
  // FIXME: bad, needs to be settable

  @objc var propertyFromHeader6: CInt {
    // FIXME: bad, needs a setter
    get { return 1 }
  }

  final var propertyFromHeader8: CInt
  // FIXME: Should complain about final not fulfilling the @objc requirement

  var readonlyPropertyFromHeader1: CInt
  // OK, provides an implementation with a stored property that's nonpublicly settable

  @objc var readonlyPropertyFromHeader2: CInt
  // OK, provides an implementation with a stored property that's nonpublicly settable

  var readonlyPropertyFromHeader3: CInt {
    // OK, provides an implementation with a computed property
    get { return 1 }
    set {}
  }

  @objc var readonlyPropertyFromHeader4: CInt {
    // OK, provides an implementation with a computed property
    get { return 1 }
    set {}
  }

  @objc let readonlyPropertyFromHeader5: CInt
  // OK, provides an implementation with a stored read-only property

  @objc var readonlyPropertyFromHeader6: CInt {
    // OK, provides an implementation with a computed read-only property
    get { return 1 }
  }

  internal var propertyNotFromHeader1: CInt
  // expected-error@-1 {{property 'propertyNotFromHeader1' does not match any property declared in the headers for 'ObjCClass'; did you use the property's Swift name?}}
  // expected-note@-2 {{add 'private' or 'fileprivate' to define an Objective-C-compatible property not declared in the header}} {{3-3=private }}
  // expected-note@-3 {{add 'final' to define a Swift property that cannot be overridden}} {{3-3=final }}

  @objc private var propertyNotFromHeader2: CInt
  // OK, provides a nonpublic but ObjC-compatible stored property

  @objc fileprivate var propertyNotFromHeader3: CInt {
    // OK, provides a nonpublic but ObjC-compatible computed property
    get { return 1 }
    set {}
  }

  final var propertyNotFromHeader4: CInt
  // OK, provides a Swift-only stored property

  @objc final var propertyNotFromHeader5: CInt
  // OK, @objc final is weird but supported, not a member impl

  override open func superclassMethod(_: CInt) {
    // OK
  }

  override open var superclassProperty: CInt {
    get {
      // OK
    }
    set {
      // OK
    }
  }

  override public init(fromSuperclass _: CInt) {
    // OK
  }

  class func classMethod1(_: CInt) {
    // OK
  }

  func classMethod2(_: CInt) {
    // expected-error@-1 {{instance method 'classMethod2' does not match class method declared in header}} {{3-3=class }}
  }

  func instanceMethod1(_: CInt) {
    // OK
  }

  class func instanceMethod2(_: CInt) {
    // expected-error@-1 {{class method 'instanceMethod2' does not match instance method declared in header}} {{3-9=}}
  }
}

@_objcImplementation(PresentAdditions) extension ObjCClass {
  // expected-note@-1 {{previously implemented by extension here}}
  // expected-error@-2 {{extension for category 'PresentAdditions' should provide implementation for instance method 'categoryMethod(fromHeader4:)'}}
  // FIXME: give better diagnostic expected-error@-3 {{extension for category 'PresentAdditions' should provide implementation for instance method 'categoryMethod(fromHeader3:)'}}

  func method(fromHeader3: CInt) {
    // FIXME: should emit expected-DISABLED-error@-1 {{instance method 'method(fromHeader3:)' should be implemented in extension for main class interface, not category 'PresentAdditions'}}
    // FIXME: expected-error@-2 {{instance method 'method(fromHeader3:)' does not match any instance method declared in the headers for 'ObjCClass'; did you use the instance method's Swift name?}}
    // FIXME: expected-note@-3 {{add 'private' or 'fileprivate' to define an Objective-C-compatible instance method not declared in the header}} {{3-3=private }}
    // FIXME: expected-note@-4 {{add 'final' to define a Swift instance method that cannot be overridden}} {{3-3=final }}
  }

  var propertyFromHeader7: CInt {
    // FIXME: should emit expected-DISABLED-error@-1 {{property 'propertyFromHeader7' should be implemented in extension for main class interface, not category 'PresentAdditions'}}
    // FIXME: expected-error@-2 {{property 'propertyFromHeader7' does not match any property declared in the headers for 'ObjCClass'; did you use the property's Swift name?}}
    // FIXME: expected-note@-3 {{add 'private' or 'fileprivate' to define an Objective-C-compatible property not declared in the header}} {{3-3=private }}
    // FIXME: expected-note@-4 {{add 'final' to define a Swift property that cannot be overridden}} {{3-3=final }}
    get { return 1 }
  }

  func categoryMethod(fromHeader1: CInt) {
    // OK, provides an implementation for the header's method.
  }

  @objc func categoryMethod(fromHeader2: CInt) {
    // OK, provides an implementation for the header's method.
  }

  @objc fileprivate func categoryMethodNot(fromHeader1: CInt) {
    // OK, declares a new @objc dynamic method.
  }

  final func categoryMethodNot(fromHeader2: CInt) {
    // OK, declares a new Swift method.
  }

  func categoryMethodNot(fromHeader3: CInt) {
    // expected-error@-1 {{instance method 'categoryMethodNot(fromHeader3:)' does not match any instance method declared in the headers for 'ObjCClass'; did you use the instance method's Swift name?}}
    // expected-note@-2 {{add 'private' or 'fileprivate' to define an Objective-C-compatible instance method not declared in the header}} {{3-3=private }}
    // expected-note@-3 {{add 'final' to define a Swift instance method that cannot be overridden}} {{3-3=final }}
  }

  var categoryPropertyFromHeader1: CInt
  // expected-error@-1 {{extensions must not contain stored properties}}

  @objc var categoryPropertyFromHeader2: CInt
  // expected-error@-1 {{extensions must not contain stored properties}}

  var categoryPropertyFromHeader3: CInt {
    // OK, provides an implementation with a computed property
    get { return 1 }
    set {}
  }

  @objc var categoryPropertyFromHeader4: CInt {
    // OK, provides an implementation with a computed property
    get { return 1 }
    set {}
  }
}

@_objcImplementation(SwiftNameTests) extension ObjCClass {
  // expected-error@-1 {{extension for category 'SwiftNameTests' should provide implementation for instance method 'methodSwiftName6B()'}}

  func methodSwiftName1() {
    // expected-error@-1 {{selector 'methodSwiftName1' for instance method 'methodSwiftName1()' not found in header; did you mean 'methodObjCName1'?}} {{3-3=@objc(methodObjCName1) }}
  }

  @objc(methodObjCName2) func methodSwiftName2() {
    // OK
  }

  func methodObjCName3() {
    // expected-error@-1 {{selector 'methodObjCName3' used in header by an instance method with a different name; did you mean 'methodSwiftName3()'?}} {{8-23=methodSwiftName3}} {{3-3=@objc(methodObjCName3) }}
    // FIXME: probably needs an @objc too, since the name is not explicit
  }

  @objc(methodWrongObjCName4) func methodSwiftName4() {
    // expected-error@-1 {{selector 'methodWrongObjCName4' for instance method 'methodSwiftName4()' not found in header; did you mean 'methodObjCName4'?}} {{9-29=methodObjCName4}}
  }

  @objc(methodObjCName5) func methodWrongSwiftName5() {
    // expected-error@-1 {{selector 'methodObjCName5' used in header by an instance method with a different name; did you mean 'methodSwiftName5()'?}} {{31-52=methodSwiftName5}}
  }

  @objc(methodObjCName6A) func methodSwiftName6B() {
    // expected-error@-1 {{selector 'methodObjCName6A' used in header by an instance method with a different name; did you mean 'methodSwiftName6A()'?}} {{32-49=methodSwiftName6A}}
  }
}

@_objcImplementation(AmbiguousMethods) extension ObjCClass {
  // expected-error@-1 {{found multiple implementations that could match instance method 'ambiguousMethod4(with:)' with selector 'ambiguousMethod4WithCInt:'}}

  @objc func ambiguousMethod1(with: CInt) {
    // expected-error@-1 {{instance method 'ambiguousMethod1(with:)' could match several different members declared in the header}}
    // expected-note@-2 {{instance method 'ambiguousMethod1(with:)' (with selector 'ambiguousMethod1WithCInt:') is a potential match; insert '@objc(ambiguousMethod1WithCInt:)' to use it}} {{8-8=(ambiguousMethod1WithCInt:)}}
    // expected-note@-3 {{instance method 'ambiguousMethod1(with:)' (with selector 'ambiguousMethod1WithCChar:') is a potential match; insert '@objc(ambiguousMethod1WithCChar:)' to use it}} {{8-8=(ambiguousMethod1WithCChar:)}}
  }

  func ambiguousMethod1(with: CChar) {
    // expected-error@-1 {{instance method 'ambiguousMethod1(with:)' could match several different members declared in the header}}
    // expected-note@-2 {{instance method 'ambiguousMethod1(with:)' (with selector 'ambiguousMethod1WithCInt:') is a potential match; insert '@objc(ambiguousMethod1WithCInt:)' to use it}} {{3-3=@objc(ambiguousMethod1WithCInt:) }}
    // expected-note@-3 {{instance method 'ambiguousMethod1(with:)' (with selector 'ambiguousMethod1WithCChar:') is a potential match; insert '@objc(ambiguousMethod1WithCChar:)' to use it}} {{3-3=@objc(ambiguousMethod1WithCChar:) }}
  }

  @objc(ambiguousMethod2WithCInt:) func ambiguousMethod2(with: CInt) {
    // OK, matches -ambiguousMethod2WithCInt: because of explicit @objc
  }

  func ambiguousMethod2(with: CChar) {
    // FIXME: OK, matches -ambiguousMethod2WithCChar: because the WithCInt: variant has been eliminated
    // FIXME: expected-error@-2 {{selector 'ambiguousMethod2With:' for instance method 'ambiguousMethod2(with:)' not found in header; did you mean 'ambiguousMethod2WithCChar:'?}}
  }

  func ambiguousMethod3(with: CInt) {
    // expected-error@-1 {{instance method 'ambiguousMethod3(with:)' could match several different members declared in the header}}
    // expected-note@-2 {{instance method 'ambiguousMethod3(with:)' (with selector 'ambiguousMethod3WithCInt:') is a potential match; insert '@objc(ambiguousMethod3WithCInt:)' to use it}} {{3-3=@objc(ambiguousMethod3WithCInt:) }}
    // expected-note@-3 {{instance method 'ambiguousMethod3(with:)' (with selector 'ambiguousMethod3WithCChar:') is a potential match; insert '@objc(ambiguousMethod3WithCChar:)' to use it}} {{3-3=@objc(ambiguousMethod3WithCChar:) }}
  }

  @objc func ambiguousMethod4(with: CInt) {
    // expected-note@-1 {{instance method 'ambiguousMethod4(with:)' is a potential match; insert '@objc(ambiguousMethod4WithCInt:)' to use it}} {{8-8=(ambiguousMethod4WithCInt:)}}
  }

  func ambiguousMethod4(with: CChar) {
    // expected-note@-1 {{instance method 'ambiguousMethod4(with:)' is a potential match; insert '@objc(ambiguousMethod4WithCInt:)' to use it}} {{3-3=@objc(ambiguousMethod4WithCInt:) }}
  }
}

@_objcImplementation extension ObjCClass {}
// expected-error@-1 {{duplicate implementation of Objective-C class 'ObjCClass'}}

@_objcImplementation(PresentAdditions) extension ObjCClass {}
// expected-error@-1 {{duplicate implementation of Objective-C category 'PresentAdditions' on class 'ObjCClass'}}

@_objcImplementation(MissingAdditions) extension ObjCClass {}
// expected-error@-1 {{could not find category 'MissingAdditions' on Objective-C class 'ObjCClass'; make sure your umbrella or bridging header imports the header that declares it}}
// expected-note@-2 {{remove arguments to implement the main '@interface' for this class}} {{21-39=}}

@_objcImplementation extension ObjCStruct {}
// expected-error@-1 {{cannot mark extension of struct 'ObjCStruct' with '@_objcImplementation'; it is not an imported Objective-C class}} {{1-22=}}

@_objcImplementation(CantWork) extension ObjCStruct {}
// expected-error@-1 {{cannot mark extension of struct 'ObjCStruct' with '@_objcImplementation'; it is not an imported Objective-C class}} {{1-32=}}

@objc class SwiftClass {}
// expected-note@-1 2 {{'SwiftClass' declared here}}

@_objcImplementation extension SwiftClass {}
// expected-error@-1 {{'@_objcImplementation' cannot be used to extend class 'SwiftClass' because it was defined by a Swift 'class' declaration, not an imported Objective-C '@interface' declaration}} {{1-22=}}

@_objcImplementation(WTF) extension SwiftClass {} // expected
// expected-error@-1 {{'@_objcImplementation' cannot be used to extend class 'SwiftClass' because it was defined by a Swift 'class' declaration, not an imported Objective-C '@interface' declaration}} {{1-27=}}

func usesAreNotAmbiguous(obj: ObjCClass) {
  obj.method(fromHeader1: 1)
  obj.method(fromHeader2: 2)
  obj.method(fromHeader3: 3)
  obj.method(fromHeader4: 4)

  obj.methodNot(fromHeader1: 1)
  obj.methodNot(fromHeader2: 2)

  obj.categoryMethod(fromHeader1: 1)
  obj.categoryMethod(fromHeader2: 2)
  obj.categoryMethod(fromHeader3: 3)
  obj.categoryMethod(fromHeader4: 4)

  obj.categoryMethodNot(fromHeader1: 1)
  obj.categoryMethodNot(fromHeader2: 2)
}
