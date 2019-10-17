theory ValidState
imports Semantics
begin

lemma refundOne_preserves_valid_map_accounts :
  "valid_map oldAccounts \<Longrightarrow>
   refundOne oldAccounts = Some ((party, money), newAccounts)
   \<Longrightarrow> valid_map newAccounts"
  apply (induction oldAccounts rule:refundOne.induct)
  apply (metis MList.sublist_valid Pair_inject option.inject refundOne.simps(1))
  by simp

lemma reductionStep_preserves_valid_state_Refund :
  "valid_state state \<Longrightarrow>
   reduceContractStep env state Close = Reduced wa ef newState newCont \<Longrightarrow>
   state = \<lparr>accounts = oldAccounts, choices = oldChoices, boundValues = oldBoundValues, minSlot = oldMinSlot\<rparr> \<Longrightarrow>
   newState = \<lparr>accounts = newAccounts, choices = newChoices, boundValues = newBoundValues, minSlot = newMinSlot\<rparr> \<Longrightarrow>
   valid_state newState"
  apply (cases "refundOne oldAccounts")
  using refundOne_preserves_valid_map_accounts by auto

lemma updateMoneyInAccount_preserves_valid_map :
  "valid_map accs \<Longrightarrow>
   valid_map (updateMoneyInAccount accId ammount accs)"
  using MList.delete_valid MList.insert_valid by fastforce

lemma giveMoney_preserves_valid_map :
  "valid_map accs \<Longrightarrow>
   giveMoney payee ammount accs = (a, newAccs) \<Longrightarrow>
   valid_map newAccs"
  by (metis addMoneyToAccount.simps giveMoney.elims snd_conv updateMoneyInAccount_preserves_valid_map)

lemma reductionStep_preserves_valid_state_Pay :
  "valid_state state \<Longrightarrow> reduceContractStep env state (Pay accId payee val cont) = Reduced wa ef newState newCont \<Longrightarrow>
   valid_state newState"
  apply (simp only:reduceContractStep.simps)
  apply (cases "evalValue env state val \<le> 0")
  apply simp
  apply (cases "giveMoney payee (min (moneyInAccount accId (accounts state)) (evalValue env state val))
           (updateMoneyInAccount accId (moneyInAccount accId (accounts state) - min (moneyInAccount accId (accounts state)) (evalValue env state val))
             (accounts state))")
  apply (simp only:Product_Type.prod.case if_False Let_def)
  by (metis ReduceStepResult.inject State.select_convs(1) State.select_convs(2) State.select_convs(3) State.surjective State.update_convs(1) giveMoney_preserves_valid_map updateMoneyInAccount_preserves_valid_map valid_state.simps)

lemma reductionStep_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   reduceContractStep env state cont = Reduced wa ef newState newCont \<Longrightarrow>
   valid_state newState"
  apply (cases cont)
  apply (metis (full_types) State.surjective old.unit.exhaust reductionStep_preserves_valid_state_Refund)
  using reductionStep_preserves_valid_state_Pay apply blast
  apply simp
  apply (smt ReduceStepResult.distinct(1) ReduceStepResult.distinct(3) ReduceStepResult.inject case_prod_unfold reduceContractStep.simps(4))
  apply (cases "state")
  apply (cases "newState")
  apply simp
  by (metis MList.insert_valid ReduceStepResult.inject State.ext_inject valid_map.simps)

lemma reductionLoop_preserves_valid_state_aux :
  "(\<And>x11 x12 x13 x14 x xa.
       reduceContractStep env state contract = Reduced x11 x12 x13 x14 \<Longrightarrow>
       x = (if x11 = ReduceNoWarning then warnings else x11 # warnings) \<Longrightarrow>
       xa = (case x12 of ReduceNoPayment \<Rightarrow> payments | ReduceWithPayment payment \<Rightarrow> payment # payments) \<Longrightarrow>
       valid_state x13 \<Longrightarrow> reductionLoop env x13 x14 x xa = ContractQuiescent newWa newPa newState newCont \<Longrightarrow> valid_state newState) \<Longrightarrow>
   valid_state state \<Longrightarrow> reductionLoop env state contract warnings payments = ContractQuiescent newWa newPa newState newCont \<Longrightarrow> valid_state newState"
  apply (simp only:reductionLoop.simps [of env state contract warnings payments])
  apply (cases "reduceContractStep env state contract")
  apply (simp only:HOL.Let_def ReduceStepResult.case)
  apply (metis reductionStep_preserves_valid_state)
  by simp_all

lemma reductionLoop_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   reductionLoop env state cont wa pa =
     ContractQuiescent newWa newPa newState newCont \<Longrightarrow>
   valid_state newState"
  apply (induction env state cont wa pa rule:reductionLoop.induct)
  using reductionLoop_preserves_valid_state_aux by blast

lemma applyCases_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   applyCases env state input caseList = Applied wa newState newCont \<Longrightarrow>
   valid_state newState"
  apply (induction env state input caseList rule:applyCases.induct)
  apply (simp only:Let_def addMoneyToAccount.simps applyCases.simps valid_state.simps)
  apply (smt ApplyResult.inject State.select_convs(1) State.select_convs(2) State.select_convs(3) State.surjective State.update_convs(1) updateMoneyInAccount_preserves_valid_map)
  apply (simp only:Let_def applyCases.simps valid_state.simps)
  apply (metis ApplyResult.inject MList.insert_valid State.select_convs(1) State.select_convs(2) State.select_convs(3) State.surjective State.update_convs(2))
  apply (metis ApplyResult.inject applyCases.simps(3))
  by auto

lemma applyInput_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   applyInput env state headInp redCon = Applied intWa intState intCont \<Longrightarrow>
   valid_state intState"
  apply (cases redCon)
  apply (simp only:applyInput.simps)
  apply simp
  apply simp
  apply simp
  apply (metis applyCases_preserves_valid_state applyInput.simps(1))
  by simp

lemma applyAllLoop_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   applyAllLoop env state cont inp wa pa = ApplyAllSuccess newWa newPa newState newCont \<Longrightarrow>
   valid_state newState"
  apply (induct env state cont inp wa pa rule:applyAllLoop.induct)
  subgoal for env state contract inputs warnings payments
    apply (simp only:applyAllLoop.simps [of env state contract inputs warnings payments])
    apply (cases inputs)
    apply (simp only:list.case)
    apply (cases "reduceContractUntilQuiescent env state contract")
    apply (metis ApplyAllResult.inject ReduceResult.simps(4) reduceContractUntilQuiescent.simps reductionLoop_preserves_valid_state)
    apply simp
    apply (simp only:list.case)
    apply (cases "reduceContractUntilQuiescent env state contract")
    apply (simp only:ReduceResult.case)
    subgoal for a list x11 x12 x13 x14
      apply (cases "applyInput env x13 a x14")
      apply (simp only:ApplyResult.case)
      apply (metis applyInput_preserves_valid_state reduceContractUntilQuiescent.simps reductionLoop_preserves_valid_state)
      by simp
    by simp
  done

lemma applyAllInputs_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   applyAllInputs env state cont inp = ApplyAllSuccess wa pa newState newCont \<Longrightarrow>
   valid_state newState"
  by (metis applyAllInputs.simps applyAllLoop_preserves_valid_state)

lemma fixInterval_preserves_valid_state :
  "valid_state state \<Longrightarrow>
   fixInterval (a, b) state = IntervalTrimmed newEnv newState \<Longrightarrow>
   valid_state newState"
  apply (simp only:fixInterval.simps)
  apply (cases "b < a")
  apply simp
  apply (cases "b < minSlot state")
  apply simp
  apply (simp del:valid_state.simps add:Let_def)
  by auto

lemma computeTransaction_preserves_valid_state_aux :
  "valid_state newState \<Longrightarrow>
    (case applyAllInputs newEnv newState cont (inputs \<lparr>interval = intervalI, inputs = inputsI\<rparr>) of
       ApplyAllSuccess warnings payments newState conta \<Rightarrow>
         if cont = conta then TransactionError TEUselessTransaction
         else TransactionOutput \<lparr>txOutWarnings = warnings, txOutPayments = payments, txOutState = newState, txOutContract = conta\<rparr>
     | ApplyAllNoMatchError \<Rightarrow> TransactionError TEApplyNoMatchError | ApplyAllAmbiguousSlotIntervalError \<Rightarrow> TransactionError TEAmbiguousSlotIntervalError)
     = TransactionOutput \<lparr>txOutWarnings = txOutWarningsO, txOutPayments = txOutPaymentsO, txOutState = txOutStateO, txOutContract = txOutContractO\<rparr> \<Longrightarrow>
   valid_state txOutStateO"
  apply (cases "applyAllInputs newEnv newState cont (inputs \<lparr>interval = intervalI, inputs = inputsI\<rparr>)")
  apply (smt ApplyAllResult.simps(8) TransactionOutput.distinct(2) TransactionOutput.inject(1) TransactionOutputRecord.select_convs(3) applyAllInputs.simps applyAllLoop_preserves_valid_state)
  by simp_all

lemma computeTransaction_preserves_valid_state_aux2 :
  "valid_state state \<Longrightarrow>
   computeTransaction  \<lparr>interval = intervalI, inputs = inputsI\<rparr> state cont
      = TransactionOutput \<lparr>txOutWarnings = txOutWarningsO, txOutPayments = txOutPaymentsO, txOutState = txOutStateO, txOutContract = txOutContractO\<rparr> \<Longrightarrow>
   valid_state (txOutStateO)"
  apply (simp only:computeTransaction.simps Let_def)
  apply (cases "fixInterval (interval \<lparr>interval = intervalI, inputs = inputsI\<rparr>) state")
  apply (simp only:IntervalResult.case)
  apply (metis (no_types, lifting) computeTransaction_preserves_valid_state_aux fixInterval_preserves_valid_state surj_pair)
  by simp

lemma computeTransaction_preserves_valid_state :
  "valid_state state \<Longrightarrow> computeTransaction tran state cont = TransactionOutput out \<Longrightarrow> valid_state (txOutState out) "
  by (metis (full_types) Transaction.surjective TransactionOutputRecord.surjective computeTransaction_preserves_valid_state_aux2 old.unit.exhaust)

end