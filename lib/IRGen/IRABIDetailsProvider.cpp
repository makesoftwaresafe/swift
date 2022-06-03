//===--- IRABIDetailsProvider.cpp - Get ABI details for decls ---*- C++ -*-===//
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

#include "swift/IRGen/IRABIDetailsProvider.h"
#include "FixedTypeInfo.h"
#include "GenType.h"
#include "IRGen.h"
#include "IRGenModule.h"

#include "swift/AST/ASTContext.h"
#include "swift/AST/IRGenOptions.h"
#include "swift/AST/Types.h"
#include "swift/SIL/SILModule.h"

using namespace swift;
using namespace irgen;

namespace swift {

class IRABIDetailsProviderImpl {
public:
  IRABIDetailsProviderImpl(ModuleDecl &mod, const IRGenOptions &opts)
      : typeConverter(mod),
        silMod(SILModule::createEmptyModule(&mod, typeConverter, silOpts)),
        IRGen(opts, *silMod), IGM(IRGen, IRGen.createTargetMachine()) {}

  llvm::Optional<IRABIDetailsProvider::SizeAndAlignment>
  getTypeSizeAlignment(const NominalTypeDecl *TD) {
    auto *TI = &IGM.getTypeInfoForUnlowered(TD->getDeclaredTypeInContext());
    auto *fixedTI = dyn_cast<FixedTypeInfo>(TI);
    if (!fixedTI)
      return None;
    return IRABIDetailsProvider::SizeAndAlignment{
        fixedTI->getFixedSize().getValue(),
        fixedTI->getFixedAlignment().getValue()};
  }

private:
  Lowering::TypeConverter typeConverter;
  // Default silOptions are sufficient, as we don't need to generated SIL.
  SILOptions silOpts;
  std::unique_ptr<SILModule> silMod;
  IRGenerator IRGen;
  IRGenModule IGM;
};

} // namespace swift

IRABIDetailsProvider::IRABIDetailsProvider(ModuleDecl &mod,
                                           const IRGenOptions &opts)
    : impl(std::make_unique<IRABIDetailsProviderImpl>(mod, opts)) {}

IRABIDetailsProvider::~IRABIDetailsProvider() {}

llvm::Optional<IRABIDetailsProvider::SizeAndAlignment>
IRABIDetailsProvider::getTypeSizeAlignment(const NominalTypeDecl *TD) {
  return impl->getTypeSizeAlignment(TD);
}
