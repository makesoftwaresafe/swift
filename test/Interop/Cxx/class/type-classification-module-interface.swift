// RUN: %target-swift-ide-test -print-module -module-to-print=TypeClassification -I %S/Inputs -source-filename=x -enable-experimental-cxx-interop | %FileCheck %s
// RUN: %target-swift-ide-test -print-module -skip-unsafe-cxx-methods -module-to-print=TypeClassification -I %S/Inputs -source-filename=x -enable-experimental-cxx-interop | %FileCheck %s -check-prefix=CHECK-SKIP-UNSAFE

// Make sure we don't import objects that we can't copy or destroy.
// CHECK-NOT: StructWithPrivateDefaultedCopyConstructor
// CHECK-NOT: StructWithInheritedPrivateDefaultedCopyConstructor
// CHECK-NOT: StructWithSubobjectPrivateDefaultedCopyConstructor
// CHECK-NOT: StructNonCopyableTriviallyMovable
// CHECK-NOT: StructNonCopyableNonMovable
// CHECK-NOT: StructWithMoveConstructor
// CHECK-NOT: StructWithInheritedMoveConstructor
// CHECK-NOT: StructWithSubobjectMoveConstructor
// CHECK-NOT: StructWithMoveAssignment
// CHECK-NOT: StructWithInheritedMoveAssignment
// CHECK-NOT: StructWithSubobjectMoveAssignment
// CHECK-NOT: StructWithPrivateDefaultedDestructor
// CHECK-NOT: StructWithInheritedPrivateDefaultedDestructor
// CHECK-NOT: StructWithSubobjectPrivateDefaultedDestructor
// CHECK-NOT: StructWithDeletedDestructor
// CHECK-NOT: StructWithInheritedDeletedDestructor
// CHECK-NOT: StructWithSubobjectDeletedDestructor

// CHECK: struct Iterator {
// CHECK: }

// CHECK: struct HasMethodThatReturnsIterator {
// CHECK:   func __getIteratorUnsafe() -> Iterator
// CHECK-SKIP-UNSAFE-NOT: func __getIteratorUnsafe() -> Iterator
// CHECK: }

// CHECK: struct IteratorBox {
// CHECK: }

// CHECK: struct HasMethodThatReturnsIteratorBox {
// CHECK:   func __getIteratorBoxUnsafe() -> IteratorBox
// CHECK-SKIP-UNSAFE-NOT: func __getIteratorBoxUnsafe() -> IteratorBox
// CHECK: }

// CHECK: struct HasMethodThatReturnsTemplatedPointerBox {
// CHECK:   func __getTemplatedPointerBoxUnsafe() -> TemplatedPointerBox<Int32>
// CHECK-SKIP-UNSAFE-NOT: func __getTemplatedPointerBoxUnsafe() -> TemplatedPointerBox<Int32>
// CHECK: }

// CHECK: struct HasMethodThatReturnsTemplatedBox {
// FIXME: This is unfortunate, we should be able to recognize that TemplatedBox<Int32> does not store any pointers as fields.
// CHECK:   func __getIntBoxUnsafe() -> TemplatedBox<Int32>
// CHECK:   func __getIntPtrBoxUnsafe()
// CHECK: }

// CHECK: struct HasMethodThatReturnsTemplatedIterator {
// CHECK:   func __getIteratorUnsafe()
// CHECK: }
