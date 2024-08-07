target_sources(swiftSILOptimizer PRIVATE
  AccessEnforcementSelection.cpp
  AccessMarkerElimination.cpp
  AddressLowering.cpp
  CapturePromotion.cpp
  ClosureLifetimeFixup.cpp
  ConsumeOperatorCopyableAddressesChecker.cpp
  ConsumeOperatorCopyableValuesChecker.cpp
  PhiStorageOptimizer.cpp
  ConstantPropagation.cpp
  DebugInfoCanonicalizer.cpp
  DefiniteInitialization.cpp
  DIMemoryUseCollector.cpp
  DataflowDiagnostics.cpp
  DiagnoseInfiniteRecursion.cpp
  DiagnoseInvalidEscapingCaptures.cpp
  DiagnoseLifetimeIssues.cpp
  DiagnoseStaticExclusivity.cpp
  DiagnoseUnreachable.cpp
  Differentiation.cpp
  FlowIsolation.cpp
  IRGenPrepare.cpp
  LexicalLifetimeEliminator.cpp
  LowerHopToActor.cpp
  MandatoryInlining.cpp
  MovedAsyncVarDebugInfoPropagator.cpp
  MoveOnlyAddressCheckerUtils.cpp
  MoveOnlyAddressCheckerTester.cpp
  MoveOnlyBorrowToDestructureUtils.cpp
  MoveOnlyBorrowToDestructureTester.cpp
  MoveOnlyDeinitInsertion.cpp
  MoveOnlyDiagnostics.cpp
  MoveOnlyObjectCheckerUtils.cpp
  MoveOnlyObjectCheckerTester.cpp
  MoveOnlyChecker.cpp
  MoveOnlyUtils.cpp
  NestedSemanticFunctionCheck.cpp
  OptimizeHopToExecutor.cpp
  PerformanceDiagnostics.cpp
  PredictableMemOpt.cpp
  PMOMemoryUseCollector.cpp
  RawSILInstLowering.cpp
  ReferenceBindingTransform.cpp
  SILGenCleanup.cpp
  YieldOnceCheck.cpp
  OSLogOptimization.cpp
  MoveOnlyWrappedTypeEliminator.cpp
  OwnershipModelEliminator.cpp)
