Require Import OCaml.OCaml.

Local Open Scope Z_scope.
Local Open Scope type_scope.
Import ListNotations.

Definition op_plus_plus_plus (x : Z) (y : Z) : Z := Z.add x y.

Definition op_tilde_tilde (x : Z) : Z := Z.opp x.

Definition z : Z := op_plus_plus_plus (op_tilde_tilde 12) 14.
