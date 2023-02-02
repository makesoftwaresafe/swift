//===--- MoveOnlyDiagnostics.cpp ------------------------------------------===//
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

#define DEBUG_TYPE "sil-move-only-checker"

#include "MoveOnlyDiagnostics.h"

#include "swift/AST/DiagnosticsSIL.h"
#include "swift/SIL/DebugUtils.h"
#include "swift/SIL/FieldSensitivePrunedLiveness.h"
#include "swift/SIL/SILArgument.h"
#include "llvm/Support/Debug.h"

using namespace swift;
using namespace swift::siloptimizer;

static llvm::cl::opt<bool> SilentlyEmitDiagnostics(
    "move-only-diagnostics-silently-emit-diagnostics",
    llvm::cl::desc(
        "For testing purposes, emit the diagnostic silently so we can "
        "filecheck the result of emitting an error from the move checkers"),
    llvm::cl::init(false));

//===----------------------------------------------------------------------===//
//                              MARK: Utilities
//===----------------------------------------------------------------------===//

template <typename... T, typename... U>
static void diagnose(ASTContext &Context, SourceLoc loc, Diag<T...> diag,
                     U &&...args) {
  // If for testing reasons we want to return that we emitted an error but not
  // emit the actual error itself, return early.
  if (SilentlyEmitDiagnostics)
    return;
  Context.Diags.diagnose(loc, diag, std::forward<U>(args)...);
}

static StringRef getVariableNameForValue(MarkMustCheckInst *mmci) {
  if (auto *allocInst = dyn_cast<AllocationInst>(mmci->getOperand())) {
    DebugVarCarryingInst debugVar(allocInst);
    if (auto varInfo = debugVar.getVarInfo()) {
      return varInfo->Name;
    } else {
      if (auto *decl = debugVar.getDecl()) {
        return decl->getBaseName().userFacingName();
      }
    }
  }

  if (auto *use = getSingleDebugUse(mmci)) {
    DebugVarCarryingInst debugVar(use->getUser());
    if (auto varInfo = debugVar.getVarInfo()) {
      return varInfo->Name;
    } else {
      if (auto *decl = debugVar.getDecl()) {
        return decl->getBaseName().userFacingName();
      }
    }
  }

  return "unknown";
}

//===----------------------------------------------------------------------===//
//                           MARK: Misc Diagnostics
//===----------------------------------------------------------------------===//

void DiagnosticEmitter::emitCheckerDoesntUnderstandDiagnostic(
    MarkMustCheckInst *markedValue) {
  // If we failed to canonicalize ownership, there was something in the SIL
  // that copy propagation did not understand. Emit a we did not understand
  // error.
  if (markedValue->getType().isMoveOnlyWrapped()) {
    diagnose(fn->getASTContext(), markedValue->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_not_understand_no_implicit_copy);
  } else {
    diagnose(fn->getASTContext(), markedValue->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_not_understand_moveonly);
  }
  registerDiagnosticEmitted(markedValue);
}

//===----------------------------------------------------------------------===//
//                          MARK: Object Diagnostics
//===----------------------------------------------------------------------===//

void DiagnosticEmitter::emitObjectGuaranteedDiagnostic(
    MarkMustCheckInst *markedValue) {
  auto &astContext = fn->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  // See if we have any closure capture uses and emit a better diagnostic.
  if (getCanonicalizer().hasPartialApplyConsumingUse()) {
    diagnose(astContext,
             markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_guaranteed_value_captured_by_closure,
             varName);
    emitObjectDiagnosticsForPartialApplyUses();
    registerDiagnosticEmitted(markedValue);
  }

  // If we do not have any non-partial apply consuming uses... just exit early.
  if (!getCanonicalizer().hasNonPartialApplyConsumingUse())
    return;

  // Check if this value is closure captured. In such a case, emit a special
  // error.
  if (auto *fArg = dyn_cast<SILFunctionArgument>(
          lookThroughCopyValueInsts(markedValue->getOperand()))) {
    if (fArg->isClosureCapture()) {
      diagnose(astContext,
               markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
               diag::sil_moveonlychecker_let_value_consumed_in_closure,
               varName);
      emitObjectDiagnosticsForFoundUses(true /*ignore partial apply uses*/);
      registerDiagnosticEmitted(markedValue);
      return;
    }
  }

  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_guaranteed_value_consumed, varName);

  emitObjectDiagnosticsForFoundUses(true /*ignore partial apply uses*/);
  registerDiagnosticEmitted(markedValue);
}

void DiagnosticEmitter::emitObjectOwnedDiagnostic(
    MarkMustCheckInst *markedValue) {
  auto &astContext = fn->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_owned_value_consumed_more_than_once,
           varName);

  emitObjectDiagnosticsForFoundUses();
  registerDiagnosticEmitted(markedValue);
}

void DiagnosticEmitter::emitObjectDiagnosticsForFoundUses(
    bool ignorePartialApplyUses) const {
  auto &astContext = fn->getASTContext();

  for (auto *consumingUse : getCanonicalizer().consumingUsesNeedingCopy) {
    // See if the consuming use is an owned moveonly_to_copyable whose only
    // user is a return. In that case, use the return loc instead. We do this
    // b/c it is illegal to put a return value location on a non-return value
    // instruction... so we have to hack around this slightly.
    auto *user = consumingUse->getUser();
    auto loc = user->getLoc();
    if (auto *mtc = dyn_cast<MoveOnlyWrapperToCopyableValueInst>(user)) {
      if (auto *ri = mtc->getSingleUserOfType<ReturnInst>()) {
        loc = ri->getLoc();
      }
    }

    if (ignorePartialApplyUses &&
        isa<PartialApplyInst>(consumingUse->getUser()))
      continue;
    diagnose(astContext, loc.getSourceLoc(),
             diag::sil_moveonlychecker_consuming_use_here);
  }

  for (auto *consumingUse : getCanonicalizer().finalConsumingUses) {
    // See if the consuming use is an owned moveonly_to_copyable whose only
    // user is a return. In that case, use the return loc instead. We do this
    // b/c it is illegal to put a return value location on a non-return value
    // instruction... so we have to hack around this slightly.
    auto *user = consumingUse->getUser();
    auto loc = user->getLoc();
    if (auto *mtc = dyn_cast<MoveOnlyWrapperToCopyableValueInst>(user)) {
      if (auto *ri = mtc->getSingleUserOfType<ReturnInst>()) {
        loc = ri->getLoc();
      }
    }

    if (ignorePartialApplyUses &&
        isa<PartialApplyInst>(consumingUse->getUser()))
      continue;

    diagnose(astContext, loc.getSourceLoc(),
             diag::sil_moveonlychecker_consuming_use_here);
  }
}

void DiagnosticEmitter::emitObjectDiagnosticsForPartialApplyUses() const {
  auto &astContext = fn->getASTContext();

  for (auto *consumingUse : getCanonicalizer().consumingUsesNeedingCopy) {
    // See if the consuming use is an owned moveonly_to_copyable whose only
    // user is a return. In that case, use the return loc instead. We do this
    // b/c it is illegal to put a return value location on a non-return value
    // instruction... so we have to hack around this slightly.
    auto *user = consumingUse->getUser();
    auto loc = user->getLoc();
    if (auto *mtc = dyn_cast<MoveOnlyWrapperToCopyableValueInst>(user)) {
      if (auto *ri = mtc->getSingleUserOfType<ReturnInst>()) {
        loc = ri->getLoc();
      }
    }

    if (!isa<PartialApplyInst>(consumingUse->getUser()))
      continue;
    diagnose(astContext, loc.getSourceLoc(),
             diag::sil_moveonlychecker_consuming_closure_use_here);
  }

  for (auto *consumingUse : getCanonicalizer().finalConsumingUses) {
    // See if the consuming use is an owned moveonly_to_copyable whose only
    // user is a return. In that case, use the return loc instead. We do this
    // b/c it is illegal to put a return value location on a non-return value
    // instruction... so we have to hack around this slightly.
    auto *user = consumingUse->getUser();
    auto loc = user->getLoc();
    if (auto *mtc = dyn_cast<MoveOnlyWrapperToCopyableValueInst>(user)) {
      if (auto *ri = mtc->getSingleUserOfType<ReturnInst>()) {
        loc = ri->getLoc();
      }
    }

    if (!isa<PartialApplyInst>(consumingUse->getUser()))
      continue;

    diagnose(astContext, loc.getSourceLoc(),
             diag::sil_moveonlychecker_consuming_closure_use_here);
  }
}

//===----------------------------------------------------------------------===//
//                         MARK: Address Diagnostics
//===----------------------------------------------------------------------===//

void DiagnosticEmitter::emitAddressExclusivityHazardDiagnostic(
    MarkMustCheckInst *markedValue, SILInstruction *consumingUse) {
  if (!useWithDiagnostic.insert(consumingUse).second)
    return;
  registerDiagnosticEmitted(markedValue);

  auto &astContext = markedValue->getFunction()->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  LLVM_DEBUG(llvm::dbgs() << "Emitting error for exclusivity!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    Consuming use: " << *consumingUse);

  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_exclusivity_violation, varName);
  diagnose(astContext, consumingUse->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_consuming_use_here);
}

void DiagnosticEmitter::emitAddressDiagnostic(MarkMustCheckInst *markedValue,
                                              SILInstruction *lastLiveUse,
                                              SILInstruction *violatingUse,
                                              bool isUseConsuming,
                                              bool isInOutEndOfFunction) {
  if (!useWithDiagnostic.insert(violatingUse).second)
    return;
  registerDiagnosticEmitted(markedValue);

  auto &astContext = markedValue->getFunction()->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  LLVM_DEBUG(llvm::dbgs() << "Emitting error!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    Last Live Use: " << *lastLiveUse);
  LLVM_DEBUG(llvm::dbgs() << "    Last Live Use Is Consuming? "
                          << (isUseConsuming ? "yes" : "no") << '\n');
  LLVM_DEBUG(llvm::dbgs() << "    Violating Use: " << *violatingUse);

  // If our liveness use is the same as our violating use, then we know that we
  // had a loop. Give a better diagnostic.
  if (lastLiveUse == violatingUse) {
    diagnose(astContext,
             markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_value_consumed_in_a_loop, varName);
    diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_consuming_use_here);
    return;
  }

  if (isInOutEndOfFunction) {
    if (auto *pbi = dyn_cast<ProjectBoxInst>(markedValue->getOperand())) {
      if (auto *fArg = dyn_cast<SILFunctionArgument>(pbi->getOperand())) {
        if (fArg->isClosureCapture()) {
          diagnose(
              astContext,
              markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
              diag::
                  sil_moveonlychecker_inout_not_reinitialized_before_end_of_closure,
              varName);
          diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
                   diag::sil_moveonlychecker_consuming_use_here);
          return;
        }
      }
    }
    if (auto *fArg = dyn_cast<SILFunctionArgument>(markedValue->getOperand())) {
      if (fArg->isClosureCapture()) {
        diagnose(
            astContext,
            markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
            diag::
                sil_moveonlychecker_inout_not_reinitialized_before_end_of_closure,
            varName);
        diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
                 diag::sil_moveonlychecker_consuming_use_here);
        return;
      }
    }
    diagnose(
        astContext,
        markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
        diag::
            sil_moveonlychecker_inout_not_reinitialized_before_end_of_function,
        varName);
    diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_consuming_use_here);
    return;
  }

  // First if we are consuming emit an error for no implicit copy semantics.
  if (isUseConsuming) {
    diagnose(astContext,
             markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_owned_value_consumed_more_than_once,
             varName);
    diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_consuming_use_here);
    diagnose(astContext, lastLiveUse->getLoc().getSourceLoc(),
             diag::sil_moveonlychecker_consuming_use_here);
    return;
  }

  // Otherwise, use the "used after consuming use" error.
  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_value_used_after_consume, varName);
  diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_consuming_use_here);
  diagnose(astContext, lastLiveUse->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_nonconsuming_use_here);
}

void DiagnosticEmitter::emitInOutEndOfFunctionDiagnostic(
    MarkMustCheckInst *markedValue, SILInstruction *violatingUse) {
  if (!useWithDiagnostic.insert(violatingUse).second)
    return;
  registerDiagnosticEmitted(markedValue);

  assert(cast<SILFunctionArgument>(markedValue->getOperand())
             ->getArgumentConvention()
             .isInoutConvention() &&
         "Expected markedValue to be on an inout");

  auto &astContext = markedValue->getFunction()->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  LLVM_DEBUG(llvm::dbgs() << "Emitting inout error error!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    Violating Use: " << *violatingUse);

  // Otherwise, we need to do no implicit copy semantics. If our last use was
  // consuming message:
  if (auto *fArg = dyn_cast<SILFunctionArgument>(markedValue->getOperand())) {
    if (fArg->isClosureCapture()) {
      diagnose(
          astContext,
          markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
          diag::
              sil_moveonlychecker_inout_not_reinitialized_before_end_of_closure,
          varName);
      diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
               diag::sil_moveonlychecker_consuming_use_here);
      return;
    }
  }
  diagnose(
      astContext,
      markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
      diag::sil_moveonlychecker_inout_not_reinitialized_before_end_of_function,
      varName);
  diagnose(astContext, violatingUse->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_consuming_use_here);
}

void DiagnosticEmitter::emitAddressDiagnosticNoCopy(
    MarkMustCheckInst *markedValue, SILInstruction *consumingUse) {
  if (!useWithDiagnostic.insert(consumingUse).second)
    return;

  auto &astContext = markedValue->getFunction()->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  LLVM_DEBUG(llvm::dbgs() << "Emitting no copy error!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    Consuming Use: " << *consumingUse);

  // Otherwise, we need to do no implicit copy semantics. If our last use was
  // consuming message:
  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_guaranteed_value_consumed, varName);
  diagnose(astContext, consumingUse->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_consuming_use_here);
  registerDiagnosticEmitted(markedValue);
}

void DiagnosticEmitter::emitObjectDestructureNeededWithinBorrowBoundary(
    MarkMustCheckInst *markedValue, SILInstruction *destructureNeedingUse,
    TypeTreeLeafTypeRange destructureSpan,
    FieldSensitivePrunedLivenessBoundary &boundary) {
  if (!useWithDiagnostic.insert(destructureNeedingUse).second)
    return;

  auto &astContext = markedValue->getFunction()->getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);

  LLVM_DEBUG(llvm::dbgs() << "Emitting destructure can't be created error!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    Destructure Needing Use: "
                          << *destructureNeedingUse);

  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_moveonly_field_consumed, varName);
  diagnose(astContext, destructureNeedingUse->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_consuming_use_here);

  // Only emit errors for last users that overlap with our needed destructure
  // bits.
  for (auto pair : boundary.getLastUsers()) {
    if (llvm::any_of(destructureSpan.getRange(),
                     [&](unsigned index) { return pair.second.test(index); })) {
      LLVM_DEBUG(llvm::dbgs()
                 << "    Destructure Boundary Use: " << *pair.first);
      diagnose(astContext, pair.first->getLoc().getSourceLoc(),
               diag::sil_moveonlychecker_boundary_use);
    }
  }
  registerDiagnosticEmitted(markedValue);
}

void DiagnosticEmitter::emitObjectConsumesDestructuredValueTwice(
    MarkMustCheckInst *markedValue, Operand *firstUse, Operand *secondUse) {
  assert(firstUse->getUser() == secondUse->getUser());
  assert(firstUse->isConsuming());
  assert(secondUse->isConsuming());

  LLVM_DEBUG(
      llvm::dbgs() << "Emitting object consumes destructure twice error!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    User: " << *firstUse->getUser());
  LLVM_DEBUG(llvm::dbgs() << "    First Conflicting Operand: "
                          << firstUse->getOperandNumber() << '\n');
  LLVM_DEBUG(llvm::dbgs() << "    Second Conflicting Operand: "
                          << secondUse->getOperandNumber() << '\n');

  auto &astContext = markedValue->getModule().getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);
  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_owned_value_consumed_more_than_once,
           varName);
  diagnose(astContext, firstUse->getUser()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_two_consuming_uses_here);
  registerDiagnosticEmitted(markedValue);
}

void DiagnosticEmitter::emitObjectConsumesAndUsesDestructuredValue(
    MarkMustCheckInst *markedValue, Operand *consumingUse,
    Operand *nonConsumingUse) {
  assert(consumingUse->getUser() == nonConsumingUse->getUser());
  assert(consumingUse->isConsuming());
  assert(!nonConsumingUse->isConsuming());

  LLVM_DEBUG(
      llvm::dbgs() << "Emitting object consumes destructure twice error!\n");
  LLVM_DEBUG(llvm::dbgs() << "    Mark: " << *markedValue);
  LLVM_DEBUG(llvm::dbgs() << "    User: " << *consumingUse->getUser());
  LLVM_DEBUG(llvm::dbgs() << "    Consuming Operand: "
                          << consumingUse->getOperandNumber() << '\n');
  LLVM_DEBUG(llvm::dbgs() << "    Non Consuming Operand: "
                          << nonConsumingUse->getOperandNumber() << '\n');

  auto &astContext = markedValue->getModule().getASTContext();
  StringRef varName = getVariableNameForValue(markedValue);
  diagnose(astContext,
           markedValue->getDefiningInstruction()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_owned_value_consumed_and_used_at_same_time,
           varName);
  diagnose(astContext, consumingUse->getUser()->getLoc().getSourceLoc(),
           diag::sil_moveonlychecker_consuming_and_non_consuming_uses_here);
  registerDiagnosticEmitted(markedValue);
}
