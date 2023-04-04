// RUN: %target-swift-emit-silgen -enable-experimental-feature VariadicGenerics %s | %FileCheck %s

// rdar://107459964
// rdar://107478603

// Because of -enable-experimental-feature VariadicGenerics
// REQUIRES: asserts

public struct G<Value> {
  public let id: Int
}

public struct Holder<each T> {
  public let values: (repeat G<each T>)
}

// CHECK-LABEL: sil {{.*}}@$s4main21testInstanceVarAccessyAA1GVyxGAA6HolderVyx_QPGlF :
// CHECK:       [[T0:%.*]] = struct_extract %0 : $Holder<X>, #Holder.values
// CHECK-NEXT:  return [[T0]] : $G<X>
public func testInstanceVarAccess<X>(_ holder: Holder<X>) -> G<X> {
  return holder.values
}

extension Holder {
  public static var allValues: (repeat G<each T>) {
    return (repeat G<each T>(id: 0))
  }
}

// CHECK-LABEL: sil {{.*}}@$s4main19testStaticVarAccessAA1GVyxGylF :
// CHECK:       [[METATYPE:%.*]] = metatype $@thin Holder<X>.Type
// CHECK-NEXT:  [[PACK:%.*]] = alloc_pack $Pack{G<X>}
// CHECK-NEXT:  [[TEMP:%.*]] = alloc_stack $G<X>
// CHECK-NEXT:  [[INDEX:%.*]] = scalar_pack_index 0 of $Pack{G<X>}
// CHECK-NEXT:  pack_element_set [[TEMP]] : $*G<X> into [[INDEX]] of [[PACK]] :
// CHECK-NEXT:  // function_ref
// CHECK-NEXT:  [[FN:%.*]] = function_ref @$s4main6HolderV9allValuesAA1GVyxGxQp_tvgZ : $@convention(method) <each τ_0_0> (@thin Holder<repeat each τ_0_0>.Type) -> @pack_out Pack{repeat G<each τ_0_0>}
// CHECK-NEXT:  apply [[FN]]<Pack{X}>([[PACK]], [[METATYPE]])
// CHECK-NEXT:  [[T0:%.*]] = load [trivial] [[TEMP]] : $*G<X>
// CHECK-NEXT:  dealloc_stack [[TEMP]]
// CHECK-NEXT:  dealloc_pack [[PACK]]
// CHECK-NEXT:  return [[T0]] : $G<X>
public func testStaticVarAccess<X>() -> G<X> {
  return Holder<X>.allValues
}

extension Holder {
  static func takeExpansion(arg: (repeat G<each T>)) {}
  static func takePartial(arg: (Int, repeat G<each T>)) {}
}

// CHECK-LABEL: sil {{.*}}@$s4main23testArgPassingExpansion3argyAA1GVyxG_tlF :
// CHECK:       [[METATYPE:%.*]] = metatype $@thin Holder<X>.Type
// CHECK-NEXT:  [[PACK:%.*]] = alloc_pack $Pack{G<X>}
// CHECK-NEXT:  [[TEMP:%.*]] = alloc_stack $G<X>
// CHECK-NEXT:  store %0 to [trivial] [[TEMP]] : $*G<X>
// CHECK-NEXT:  [[INDEX:%.*]] = scalar_pack_index 0 of $Pack{G<X>}
// CHECK-NEXT:  pack_element_set [[TEMP]] : $*G<X> into [[INDEX]] of [[PACK]] :
// CHECK-NEXT:  // function_ref
// CHECK-NEXT:  [[FN:%.*]] = function_ref @$s4main6HolderV13takeExpansion3argyAA1GVyxGxQp_t_tFZ : $@convention(method) <each τ_0_0> (@pack_guaranteed Pack{repeat G<each τ_0_0>}, @thin Holder<repeat each τ_0_0>.Type) -> ()
// CHECK-NEXT:  apply [[FN]]<Pack{X}>([[PACK]], [[METATYPE]])
// CHECK-NEXT:  dealloc_stack [[TEMP]]
// CHECK-NEXT:  dealloc_pack [[PACK]]
public func testArgPassingExpansion<X>(arg: G<X>) {
  Holder<X>.takeExpansion(arg: arg)
}

// CHECK-LABEL: sil {{.*}}@$s4main21testArgPassingPartialyyF :
// CHECK:       [[METATYPE:%.*]] = metatype $@thin Holder<>.Type
// CHECK:       [[PACK:%.*]] = alloc_pack $Pack{}
// CHECK-NEXT:  // function_ref
// CHECK-NEXT:  [[FN:%.*]] = function_ref @$s4main6HolderV11takePartial3argySi_AA1GVyxGxQpt_tFZ : $@convention(method) <each τ_0_0> (Int, @pack_guaranteed Pack{repeat G<each τ_0_0>}, @thin Holder<repeat each τ_0_0>.Type) -> ()
// CHECK-NEXT:  apply [[FN]]<Pack{}>({{.*}}, [[PACK]], [[METATYPE]])
// CHECK-NEXT:  dealloc_pack [[PACK]]
public func testArgPassingPartial() {
  Holder< >.takePartial(arg: 0)
}
