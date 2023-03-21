//===--- OptimizerBridging.h - header for the OptimizerBridging module ----===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_SILOPTIMIZER_OPTIMIZERBRIDGING_H
#define SWIFT_SILOPTIMIZER_OPTIMIZERBRIDGING_H

#include "swift/SIL/SILBridging.h"
#include "swift/SILOptimizer/PassManager/PassManager.h"
#include "swift/SILOptimizer/Analysis/AliasAnalysis.h"
#include "swift/SILOptimizer/Analysis/BasicCalleeAnalysis.h"
#include "swift/SILOptimizer/Analysis/DeadEndBlocksAnalysis.h"
#include "swift/SILOptimizer/Analysis/DominanceAnalysis.h"

SWIFT_BEGIN_NULLABILITY_ANNOTATIONS

struct BridgedPassContext;

struct BridgedAliasAnalysis {
  swift::AliasAnalysis * _Nonnull aa;

  swift::MemoryBehavior getMemBehavior(BridgedInstruction inst, BridgedValue addr) const {
    return aa->computeMemoryBehavior(inst.getInst(), addr.getSILValue());
  }

  typedef swift::MemoryBehavior (* _Nonnull GetMemEffectFn)(
        BridgedPassContext context, BridgedValue, BridgedInstruction);
  typedef bool (* _Nonnull Escaping2InstFn)(
        BridgedPassContext context, BridgedValue, BridgedInstruction);
  typedef bool (* _Nonnull Escaping2ValFn)(
        BridgedPassContext context, BridgedValue, BridgedValue);
  typedef bool (* _Nonnull Escaping2ValIntFn)(
        BridgedPassContext context, BridgedValue, BridgedValue, SwiftInt);

  static void registerAnalysis(GetMemEffectFn getMemEffectsFn,
                               Escaping2InstFn isObjReleasedFn,
                               Escaping2ValIntFn isAddrVisibleFromObjFn,
                               Escaping2ValFn mayPointToSameAddrFn);
};

struct BridgedCalleeAnalysis {
  swift::BasicCalleeAnalysis * _Nonnull ca;

  SWIFT_IMPORT_UNSAFE
  swift::CalleeList getCallees(BridgedValue callee) const;

  SWIFT_IMPORT_UNSAFE
  swift::CalleeList getDestructors(swift::SILType type, bool isExactType) const;

  SWIFT_IMPORT_UNSAFE
  static BridgedFunction getCallee(swift::CalleeList cl, SwiftInt index) {
    return {cl.get(index)};
  }

  typedef bool (* _Nonnull IsDeinitBarrierFn)(BridgedInstruction, BridgedCalleeAnalysis bca);
  typedef swift::MemoryBehavior (* _Nonnull GetMemBehvaiorFn)(
        BridgedPassContext context, BridgedInstruction apply, bool observeRetains);

  static void registerAnalysis(IsDeinitBarrierFn isDeinitBarrierFn,
                               GetMemBehvaiorFn getEffectsFn);
};

struct BridgedDeadEndBlocksAnalysis {
  swift::DeadEndBlocks * _Nonnull deb;

  bool isDeadEnd(BridgedBasicBlock block) const {
    return deb->isDeadEnd(block.getBlock());
  }
};

struct BridgedDomTree {
  swift::DominanceInfo * _Nonnull di;

  bool dominates(BridgedBasicBlock dominating, BridgedBasicBlock dominated) const {
    return di->dominates(dominating.getBlock(), dominated.getBlock());
  }
};

struct BridgedBasicBlockSet {
  swift::BasicBlockSet * _Nonnull set;

  bool contains(BridgedBasicBlock block) const {
    return set->contains(block.getBlock());
  }

  bool insert(BridgedBasicBlock block) const {
    return set->insert(block.getBlock());
  }

  void erase(BridgedBasicBlock block) const {
    set->erase(block.getBlock());
  }

  SWIFT_IMPORT_UNSAFE
  BridgedFunction getFunction() const {
    return {set->getFunction()};
  }
};

struct BridgedNodeSet {
  swift::NodeSet * _Nonnull set;

  bool containsValue(BridgedValue value) const {
    return set->contains(value.getSILValue());
  }

  bool insertValue(BridgedValue value) const {
    return set->insert(value.getSILValue());
  }

  void eraseValue(BridgedValue value) const {
    set->erase(value.getSILValue());
  }

  bool containsInstruction(BridgedInstruction inst) const {
    return set->contains(inst.getInst()->asSILNode());
  }

  bool insertInstruction(BridgedInstruction inst) const {
    return set->insert(inst.getInst()->asSILNode());
  }

  void eraseInstruction(BridgedInstruction inst) const {
    set->erase(inst.getInst()->asSILNode());
  }

  SWIFT_IMPORT_UNSAFE
  BridgedFunction getFunction() const {
    return {set->getFunction()};
  }
};

struct BridgedPostDomTree {
  swift::PostDominanceInfo * _Nonnull pdi;

  bool postDominates(BridgedBasicBlock dominating, BridgedBasicBlock dominated) const {
    return pdi->dominates(dominating.getBlock(), dominated.getBlock());
  }
};

struct BridgedPassContext {
  swift::SwiftPassInvocation * _Nonnull invocation;

  SWIFT_IMPORT_UNSAFE
  BridgedChangeNotificationHandler asNotificationHandler() const {
    return {invocation};
  }
  // Analysis

  SWIFT_IMPORT_UNSAFE
  BridgedAliasAnalysis getAliasAnalysis() const {
    return {invocation->getPassManager()->getAnalysis<swift::AliasAnalysis>(invocation->getFunction())};
  }

  SWIFT_IMPORT_UNSAFE
  BridgedCalleeAnalysis getCalleeAnalysis() const {
    return {invocation->getPassManager()->getAnalysis<swift::BasicCalleeAnalysis>()};
  }

  SWIFT_IMPORT_UNSAFE
  BridgedDeadEndBlocksAnalysis getDeadEndBlocksAnalysis() const {
    auto *dba = invocation->getPassManager()->getAnalysis<swift::DeadEndBlocksAnalysis>();
    return {dba->get(invocation->getFunction())};
  }

  SWIFT_IMPORT_UNSAFE
  BridgedDomTree getDomTree() const {
    auto *da = invocation->getPassManager()->getAnalysis<swift::DominanceAnalysis>();
    return {da->get(invocation->getFunction())};
  }

  SWIFT_IMPORT_UNSAFE
  BridgedPostDomTree getPostDomTree() const {
    auto *pda = invocation->getPassManager()->getAnalysis<swift::PostDominanceAnalysis>();
    return {pda->get(invocation->getFunction())};
  }

  // SIL modifications

  SWIFT_IMPORT_UNSAFE
  BridgedBasicBlock splitBlock(BridgedInstruction bridgedInst) const {
    auto *inst = bridgedInst.getInst();
    auto *block = inst->getParent();
    return {block->split(inst->getIterator())};
  }

  void eraseInstruction(BridgedInstruction inst) const {
    invocation->eraseInstruction(inst.getInst());
  }

  void eraseBlock(BridgedBasicBlock block) const {
    block.getBlock()->eraseFromParent();
  }

  bool tryDeleteDeadClosure(BridgedInstruction closure) const;

  SWIFT_IMPORT_UNSAFE
  BridgedValue getSILUndef(swift::SILType type) const {
    return {swift::SILUndef::get(type, *invocation->getFunction())};
  }

  // Sets

  SWIFT_IMPORT_UNSAFE
  BridgedBasicBlockSet allocBasicBlockSet() const {
    return {invocation->allocBlockSet()};
  }

  void freeBasicBlockSet(BridgedBasicBlockSet set) const {
    invocation->freeBlockSet(set.set);
  }

  SWIFT_IMPORT_UNSAFE
  BridgedNodeSet allocNodeSet() const {
    return {invocation->allocNodeSet()};
  }

  void freeNodeSet(BridgedNodeSet set) const {
    invocation->freeNodeSet(set.set);
  }

  // Stack nesting

  void notifyInvalidatedStackNesting() const {
    invocation->setNeedFixStackNesting(true);
  }

  bool getNeedFixStackNesting() const {
    return invocation->getNeedFixStackNesting();
  }

  void fixStackNesting(BridgedFunction function) const;

  // Slabs

  struct Slab {
    swift::FixedSizeSlabPayload * _Nullable data = nullptr;

    static SwiftInt getCapacity() {
      return (SwiftInt)swift::FixedSizeSlabPayload::capacity;
    }

    Slab(swift::FixedSizeSlab * _Nullable slab) {
      if (slab) {
        data = slab;
        assert((void *)data == slab->dataFor<void>());
      }
    }

    swift::FixedSizeSlab * _Nullable getSlab() const {
      if (data)
        return static_cast<swift::FixedSizeSlab *>(data);
      return nullptr;
    }

    SWIFT_IMPORT_UNSAFE
    Slab getNext() const {
      return &*std::next(getSlab()->getIterator());
    }

    SWIFT_IMPORT_UNSAFE
    Slab getPrevious() const {
      return &*std::prev(getSlab()->getIterator());
    }
  };

  SWIFT_IMPORT_UNSAFE
  Slab allocSlab(Slab afterSlab) const {
    return invocation->allocSlab(afterSlab.getSlab());
  }

  SWIFT_IMPORT_UNSAFE
  Slab freeSlab(Slab slab) const {
    return invocation->freeSlab(slab.getSlab());
  }

  // Access SIL module data structures

  SWIFT_IMPORT_UNSAFE
  OptionalBridgedFunction getFirstFunctionInModule() const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    if (mod->getFunctions().empty())
      return {nullptr};
    return {&*mod->getFunctions().begin()};
  }

  SWIFT_IMPORT_UNSAFE
  static OptionalBridgedFunction getNextFunctionInModule(BridgedFunction function) {
    auto *f = function.getFunction();
    auto nextIter = std::next(f->getIterator());
    if (nextIter == f->getModule().getFunctions().end())
      return {nullptr};
    return {&*nextIter};
  }

  struct VTableArray {
    swift::SILVTable * const _Nonnull * _Nullable base;
    SwiftInt count;
  };

  SWIFT_IMPORT_UNSAFE
  VTableArray getVTables() const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    auto vTables = mod->getVTables();
    return {vTables.data(), (SwiftInt)vTables.size()};
  }

  SWIFT_IMPORT_UNSAFE
  OptionalBridgedWitnessTable getFirstWitnessTableInModule() const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    if (mod->getWitnessTables().empty())
      return {nullptr};
    return {&*mod->getWitnessTables().begin()};
  }

  SWIFT_IMPORT_UNSAFE
  static OptionalBridgedWitnessTable getNextWitnessTableInModule(BridgedWitnessTable table) {
    auto *t = table.table;
    auto nextIter = std::next(t->getIterator());
    if (nextIter == t->getModule().getWitnessTables().end())
      return {nullptr};
    return {&*nextIter};
  }

  SWIFT_IMPORT_UNSAFE
  OptionalBridgedDefaultWitnessTable getFirstDefaultWitnessTableInModule() const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    if (mod->getDefaultWitnessTables().empty())
      return {nullptr};
    return {&*mod->getDefaultWitnessTables().begin()};
  }

  SWIFT_IMPORT_UNSAFE
  static OptionalBridgedDefaultWitnessTable getNextDefaultWitnessTableInModule(BridgedDefaultWitnessTable table) {
    auto *t = table.table;
    auto nextIter = std::next(t->getIterator());
    if (nextIter == t->getModule().getDefaultWitnessTables().end())
      return {nullptr};
    return {&*nextIter};
  }

  SWIFT_IMPORT_UNSAFE
  OptionalBridgedFunction loadFunction(llvm::StringRef name) const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    return {mod->loadFunction(name, swift::SILModule::LinkingMode::LinkNormal)};
  }

  SWIFT_IMPORT_UNSAFE
  swift::SubstitutionMap getContextSubstitutionMap(swift::SILType type) const {
    auto *ntd = type.getASTType()->getAnyNominal();
    auto *mod = invocation->getPassManager()->getModule()->getSwiftModule();
    return type.getASTType()->getContextSubstitutionMap(mod, ntd);
  }

  // Passmanager housekeeping

  void beginTransformFunction(BridgedFunction function) const {
    invocation->beginTransformFunction(function.getFunction());
  }

  void endTransformFunction() const {
    invocation->endTransformFunction();
  }

  bool continueWithNextSubpassRun(OptionalBridgedInstruction inst) const {
    swift::SILPassManager *pm = invocation->getPassManager();
    return pm->continueWithNextSubpassRun(inst.getInst(),
                                          invocation->getFunction(),
                                          invocation->getTransform());
  }

  // Options

  bool enableStackProtection() const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    return mod->getOptions().EnableStackProtection;
  }

  bool enableMoveInoutStackProtection() const {
    swift::SILModule *mod = invocation->getPassManager()->getModule();
    return mod->getOptions().EnableMoveInoutStackProtection;
  }

  bool enableSimplificationFor(BridgedInstruction inst) const;
};

//===----------------------------------------------------------------------===//
//                          Pass registration
//===----------------------------------------------------------------------===//

struct BridgedFunctionPassCtxt {
  BridgedFunction function;
  BridgedPassContext passContext;
} ;

struct BridgedInstructionPassCtxt {
  BridgedInstruction instruction;
  BridgedPassContext passContext;
};

typedef void (* _Nonnull BridgedModulePassRunFn)(BridgedPassContext);
typedef void (* _Nonnull BridgedFunctionPassRunFn)(BridgedFunctionPassCtxt);
typedef void (* _Nonnull BridgedInstructionPassRunFn)(BridgedInstructionPassCtxt);

void SILPassManager_registerModulePass(llvm::StringRef name,
                                       BridgedModulePassRunFn runFn);
void SILPassManager_registerFunctionPass(llvm::StringRef name,
                                         BridgedFunctionPassRunFn runFn);
void SILCombine_registerInstructionPass(llvm::StringRef instClassName,
                                        BridgedInstructionPassRunFn runFn);

SWIFT_END_NULLABILITY_ANNOTATIONS

#endif
