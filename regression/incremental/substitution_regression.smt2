(set-logic QF_LRA)
(declare-fun b () Real)
(define-fun _2 () Real b)
(declare-fun a () Real)
(check-sat)
(assert (and (= a b) (distinct b 0.0)))
(check-sat)