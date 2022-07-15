// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend %s -typecheck -module-name Functions -clang-header-expose-public-decls -emit-clang-header-path %t/functions.h
// RUN: %FileCheck %s < %t/functions.h

// RUN: %check-interop-cxx-header-in-clang(%t/functions.h)

// CHECK-LABEL: namespace Functions {

// CHECK-LABEL: namespace _impl {

// CHECK: SWIFT_EXTERN void $s9Functions18emptyThrowFunctionyyKF(SWIFT_CONTEXT void * _Nonnull _self, SWIFT_ERROR_RESULT void ** _error) SWIFT_CALL; // emptyThrowFunction()
// CHECK: SWIFT_EXTERN void $s9Functions13throwFunctionyyKF(SWIFT_CONTEXT void * _Nonnull _self, SWIFT_ERROR_RESULT void ** _error) SWIFT_CALL; // throwFunction()

// CHECK: }

enum NaiveErrors : Error {
    case returnError
    case throwError
}

public func emptyThrowFunction() throws { print("passEmptyThrowFunction") }

// CHECK: inline void emptyThrowFunction() {
// CHECK: void* opaqueError = nullptr;
// CHECK: void* self = nullptr;
// CHECK: return _impl::$s9Functions18emptyThrowFunctionyyKF(self, &opaqueError);
// CHECK: }

public func throwFunction() throws {
    print("passThrowFunction")
    throw NaiveErrors.throwError
}

// CHECK: inline void throwFunction() {
// CHECK: void* opaqueError = nullptr;
// CHECK: void* self = nullptr;
// CHECK: return _impl::$s9Functions13throwFunctionyyKF(self, &opaqueError);
// CHECK: }
