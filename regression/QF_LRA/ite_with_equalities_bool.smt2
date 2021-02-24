(set-info :status unsat)
(set-logic QF_LRA)
(declare-fun x8 () Real)
(declare-fun x7 () Real)
(declare-fun x9 () Real)
(declare-fun a () Bool)
(assert (and
	(ite (= x8 0) (= x7 x8) (= x7 0))
	(not (= x7 0))
))
(check-sat)
(exit)
