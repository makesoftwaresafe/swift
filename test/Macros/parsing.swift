// RUN: %target-typecheck-verify-swift -enable-experimental-feature Macros
protocol P { }
protocol Q { associatedtype Assoc }

@expression macro m1: Int = #externalMacro(module: "A", type: "M1")
// expected-warning@-1{{external macro implementation type 'A.M1' could not be found for macro 'm1'; the type must be public and provided via '-load-plugin-library'}}
@expression macro m2(_: Int) = #externalMacro(module: "A", type: "M2")
// expected-warning@-1{{external macro implementation type 'A.M2' could not be found for macro 'm2'; the type must be public and provided via '-load-plugin-library'}}
@expression macro m3(a b: Int) -> Int = #externalMacro(module: "A", type: "M3")
// expected-warning@-1{{external macro implementation type 'A.M3' could not be found for macro 'm3(a:)'; the type must be public and provided via '-load-plugin-library'}}
@expression macro m4<T: Q>: T = #externalMacro(module: "A", type: "M4") where T.Assoc: P
// expected-warning@-1{{external macro implementation type 'A.M4' could not be found for macro 'm4'; the type must be public and provided via '-load-plugin-library'}}
@expression macro m5<T: P>(_: T) = #externalMacro(module: "A", type: "M4")
// expected-warning@-1{{external macro implementation type 'A.M4' could not be found for macro 'm5'; the type must be public and provided via '-load-plugin-library'}}

@expression macro m6 = A // expected-error{{expected '(' for macro parameters or ':' for a value-like macro}}
// expected-error@-1{{macro must itself be defined by a macro expansion such as '#externalMacro(...)'}}
