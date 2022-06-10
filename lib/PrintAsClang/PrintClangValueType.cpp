//===--- PrintClangValueType.cpp - Printer for C/C++ value types *- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "PrintClangValueType.h"
#include "ClangSyntaxPrinter.h"
#include "OutputLanguageMode.h"
#include "PrimitiveTypeMapping.h"
#include "SwiftToClangInteropContext.h"
#include "swift/AST/Decl.h"
#include "swift/AST/ParameterList.h"
#include "swift/AST/Type.h"
#include "swift/AST/TypeVisitor.h"
#include "swift/ClangImporter/ClangImporter.h"
#include "swift/IRGen/IRABIDetailsProvider.h"
#include "llvm/ADT/STLExtras.h"

using namespace swift;

/// Print out the C type name of a struct/enum declaration.
static void printCTypeName(raw_ostream &os, const NominalTypeDecl *type) {
  ClangSyntaxPrinter printer(os);
  printer.printModuleNameCPrefix(*type->getParentModule());
  // FIXME: add nested type qualifiers to fully disambiguate the name.
  printer.printBaseName(type);
}

/// Print out the C++ type name of a struct/enum declaration.
static void printCxxTypeName(raw_ostream &os, const NominalTypeDecl *type) {
  // FIXME: Print namespace qualifiers for references from other modules.
  // FIXME: Print class qualifiers for nested class references.
  ClangSyntaxPrinter(os).printBaseName(type);
}

/// Print out the C++ type name of the implementation class that provides hidden
/// access to the private class APIs.
static void printCxxImplClassName(raw_ostream &os,
                                  const NominalTypeDecl *type) {
  os << "_impl_";
  ClangSyntaxPrinter(os).printBaseName(type);
}

static void
printCValueTypeStorageStruct(raw_ostream &os, const NominalTypeDecl *typeDecl,
                             IRABIDetailsProvider::SizeAndAlignment layout) {
  os << "struct ";
  printCTypeName(os, typeDecl);
  os << " {\n";
  os << "  _Alignas(" << layout.alignment << ") ";
  os << "char _storage[" << layout.size << "];\n";
  os << "};\n\n";
}

void ClangValueTypePrinter::printStructDecl(const StructDecl *SD) {
  auto typeSizeAlign =
      interopContext.getIrABIDetails().getTypeSizeAlignment(SD);
  if (!typeSizeAlign) {
    // FIXME: handle non-fixed layout structs.
    return;
  }
  if (typeSizeAlign->size == 0) {
    // FIXME: How to represent 0 sized structs?
    return;
  }

  ClangSyntaxPrinter printer(os);

  // Print out a forward declaration of the "hidden" _impl class.
  printer.printNamespace(cxx_synthesis::getCxxImplNamespaceName(),
                         [&](raw_ostream &os) {
                           os << "class ";
                           printCxxImplClassName(os, SD);
                           os << ";\n";
                         });

  // Print out the C++ class itself.
  os << "class ";
  ClangSyntaxPrinter(os).printBaseName(SD);
  os << " final {\n";
  // FIXME: Print the other members of the struct.
  os << "private:\n";

  // Print out private default constructor.
  os << "  inline ";
  printer.printBaseName(SD);
  os << "() {}\n";
  // Print out '_make' function which returns an unitialized instance for
  // passing to Swift.
  os << "  static inline ";
  printer.printBaseName(SD);
  os << " _make() { return ";
  printer.printBaseName(SD);
  os << "(); }\n";
  // Print out the private accessors to the underlying Swift value storage.
  os << "  inline const char * _Nonnull _getOpaquePointer() const { return "
        "_storage; }\n";
  os << "  inline char * _Nonnull _getOpaquePointer() { return _storage; }\n";
  os << "\n";

  // Print out the storage for the value type.
  os << "  alignas(" << typeSizeAlign->alignment << ") ";
  os << "char _storage[" << typeSizeAlign->size << "];\n";
  // Wrap up the value type.
  os << "  friend class " << cxx_synthesis::getCxxImplNamespaceName() << "::";
  printCxxImplClassName(os, SD);
  os << ";\n";
  os << "};\n\n";

  // Print out the "hidden" _impl class.
  printer.printNamespace(
      cxx_synthesis::getCxxImplNamespaceName(), [&](raw_ostream &os) {
        os << "class ";
        printCxxImplClassName(os, SD);
        os << " {\n";
        os << "public:\n";

        os << "  static inline char * _Nonnull getOpaquePointer(";
        printCxxTypeName(os, SD);
        os << " &object) { return object._getOpaquePointer(); }\n";

        os << "  static inline const char * _Nonnull getOpaquePointer(const ";
        printCxxTypeName(os, SD);
        os << " &object) { return object._getOpaquePointer(); }\n";

        os << "  template<class T>\n";
        os << "  static inline ";
        printCxxTypeName(os, SD);
        os << " returnNewValue(T callable) {\n";
        os << "    auto result = ";
        printCxxTypeName(os, SD);
        os << "::_make();\n";
        os << "    callable(result._getOpaquePointer());\n";
        os << "    return result;\n";
        os << "  }\n";

        os << "};\n";
      });

  printCValueTypeStorageStruct(cPrologueOS, SD, *typeSizeAlign);
}

/// Print the name of the C stub struct for passing/returning a value type
/// directly to/from swiftcc function.
static void printStubCTypeName(raw_ostream &os, const NominalTypeDecl *type) {
  os << "swift_interop_stub_";
  printCTypeName(os, type);
}

/// Print out the C stub struct that's used to pass/return a value type directly
/// to/from swiftcc function.
static void
printCStructStubForDirectPassing(raw_ostream &os, const NominalTypeDecl *SD,
                                 PrimitiveTypeMapping &typeMapping,
                                 SwiftToClangInteropContext &interopContext) {
  // Print out a C stub for this value type.
  os << "// Stub struct to be used to pass/return values to/from Swift "
        "functions.\n";
  os << "struct ";
  printStubCTypeName(os, SD);
  os << " {\n";
  llvm::SmallVector<std::pair<clang::CharUnits, clang::CharUnits>, 8> fields;
  interopContext.getIrABIDetails().enumerateDirectPassingRecordMembers(
      SD->getDeclaredType(),
      [&](clang::CharUnits offset, clang::CharUnits end, Type t) {
        auto info =
            typeMapping.getKnownCTypeInfo(t->getNominalOrBoundGenericNominal());
        if (!info)
          return;
        os << "  " << info->name;
        if (info->canBeNullable)
          os << " _Null_unspecified";
        os << " _" << (fields.size() + 1) << ";\n";
        fields.push_back(std::make_pair(offset, end));
      });
  os << "};\n\n";

  // Emit a stub that returns a value directly from swiftcc function.
  os << "static inline void swift_interop_returnDirect_";
  printCTypeName(os, SD);
  os << "(char * _Nonnull result, struct ";
  printStubCTypeName(os, SD);
  os << " value";
  os << ") __attribute__((always_inline)) {\n";
  for (size_t i = 0; i < fields.size(); ++i) {
    os << "  memcpy(result + " << fields[i].first.getQuantity() << ", "
       << "&value._" << (i + 1) << ", "
       << (fields[i].second - fields[i].first).getQuantity() << ");\n";
  }
  os << "}\n\n";

  // Emit a stub that is used to pass value type directly to swiftcc function.
  os << "static inline struct ";
  printStubCTypeName(os, SD);
  os << " swift_interop_passDirect_";
  printCTypeName(os, SD);
  os << "(const char * _Nonnull value) __attribute__((always_inline)) {\n";
  os << "  struct ";
  printStubCTypeName(os, SD);
  os << " result;\n";
  for (size_t i = 0; i < fields.size(); ++i) {
    os << "  memcpy(&result._" << (i + 1) << ", value + "
       << fields[i].first.getQuantity() << ", "
       << (fields[i].second - fields[i].first).getQuantity() << ");\n";
  }
  os << "  return result;\n";
  os << "}\n\n";
}

void ClangValueTypePrinter::printCStubTypeName(const NominalTypeDecl *type) {
  printStubCTypeName(os, type);
  // Ensure the stub is declared in the header.
  interopContext.runIfStubForDeclNotEmitted(type, [&]() {
    printCStructStubForDirectPassing(cPrologueOS, type, typeMapping,
                                     interopContext);
  });
}

void ClangValueTypePrinter::printValueTypeParameterType(
    const NominalTypeDecl *type, OutputLanguageMode outputLang) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  if (outputLang != OutputLanguageMode::Cxx) {
    // C functions only take stub values directly as parameters.
    os << "struct ";
    printCStubTypeName(type);
    return;
  }
  os << "const ";
  printCxxTypeName(os, type);
  os << '&';
}

void ClangValueTypePrinter::printParameterCxxToCUseScaffold(
    bool isIndirect, const NominalTypeDecl *type,
    llvm::function_ref<void()> cxxParamPrinter) {
  // A Swift value type is passed to its underlying Swift function
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  if (!isIndirect) {
    os << cxx_synthesis::getCxxImplNamespaceName() << "::"
       << "swift_interop_passDirect_";
    printCTypeName(os, type);
    os << '(';
  }
  os << cxx_synthesis::getCxxImplNamespaceName() << "::";
  printCxxImplClassName(os, type);
  os << "::getOpaquePointer(";
  cxxParamPrinter();
  os << ')';
  if (!isIndirect)
    os << ')';
}

void ClangValueTypePrinter::printValueTypeReturnType(
    const NominalTypeDecl *type, OutputLanguageMode outputLang) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  if (outputLang == OutputLanguageMode::Cxx) {
    printCxxTypeName(os, type);
  } else {
    os << "struct ";
    printCStubTypeName(type);
  }
}

void ClangValueTypePrinter::printValueTypeIndirectReturnScaffold(
    const NominalTypeDecl *type,
    llvm::function_ref<void(StringRef)> bodyPrinter) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  os << "  return " << cxx_synthesis::getCxxImplNamespaceName() << "::";
  printCxxImplClassName(os, type);
  os << "::returnNewValue([&](void * _Nonnull result) {\n    ";
  bodyPrinter("result");
  os << ";\n";
  os << "  });\n";
}

void ClangValueTypePrinter::printValueTypeDirectReturnScaffold(
    const NominalTypeDecl *type, llvm::function_ref<void()> bodyPrinter) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  os << "  return " << cxx_synthesis::getCxxImplNamespaceName() << "::";
  printCxxImplClassName(os, type);
  os << "::returnNewValue([&](char * _Nonnull result) {\n";
  os << "    ";
  os << cxx_synthesis::getCxxImplNamespaceName() << "::"
     << "swift_interop_returnDirect_";
  printCTypeName(os, type);
  os << "(result, ";
  bodyPrinter();
  os << ");\n";
  os << "  });\n";
}
