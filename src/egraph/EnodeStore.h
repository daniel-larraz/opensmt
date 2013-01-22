#ifndef ENODESTORE_H
#define ENODESTORE_h

#include "Enode.h"
#include "Term.h"
#include "Pterm.h"

class EnodeStore {
    Map<SigPair,ERef,SigHash,Equal<const SigPair&> > sig_tab;
    EnodeAllocator      ea;
    ERef                ERef_Nil;
  public:
    EnodeStore() :
        ea(1024*1024, &sig_tab)
      , ERef_Nil(ea.alloc(TRef_Nil))
        { Enode::ERef_Nil = ERef_Nil; }
    ERef addTerm(ERef t);
    ERef addSymb(TRef t);
    ERef cons(ERef x, ERef y);
    ERef get_Nil() const { return ERef_Nil; }
    void free(ERef er) { ea.free(er); }
    vec<ERef>           id_to_enode;
    Enode& operator[] (ERef e) { return ea[e]; }
    Map<PTRef,ERef,ERefHash,Equal<ERef> > termToERef;
};

#endif