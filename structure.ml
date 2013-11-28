(** A structure represents the contents of a ".ml" file. *)
open Typedtree
open Types
open PPrint

(** A value is a toplevel definition made with a "let". *)
module Value = struct
  type t = {
    name : Name.t;
    free_type_vars : Name.t list; (** Polymorphic type variables. *)
    args : (Name.t * Type.t) list; (** Names and types of the arguments. *)
    body : Exp.t * Type.t; (** Body and type of the body. *)
    is_rec : Recursivity.t (** If the function is recursive. *) }
  
  (** Pretty-print a value definition. *)
  let pp (value : t) : document =
    group (flow (break 1) [
      (match value.is_rec with
        | Recursivity.Recursive -> !^ "Fixpoint"
        | Recursivity.NonRecursive -> !^ "Definition");
      Name.pp value.name;
      (match value.free_type_vars with
      | [] -> empty
      | xs -> group (flow (break 1) [
        !^ "{" ^^ flow (break 1) (List.map Name.pp xs); !^ ":"; !^ "Type}"]));
      group (flow (break 1) (value.args |> List.map (fun (x, t) ->
        group (flow (break 1) [lparen ^^ Name.pp x; !^ ":"; Type.pp false t ^^ rparen]))));
      !^ ":"; Type.pp false (snd value.body);
      !^ ":="; Exp.pp false (fst value.body) ^^ !^ "."])
end

(** A definition of a sum type. *)
module Inductive = struct
  type t = {
    name : Name.t;
    free_type_vars : Name.t list; (** Polymorphic type variables. *)
    constructors : (Name.t * Type.t list) list (** The list of constructors, each with a name and the list of the types of the arguments. *) }
  
  (** Pretty-print a sum type definition. *)
  let pp (ind : t) : document =
    group (flow (break 1) [
      !^ "Inductive"; Name.pp ind.name;
      (if ind.free_type_vars = [] then empty
      else group (flow (break 1) [
        lparen ^^ flow (break 1) (List.map Name.pp ind.free_type_vars);
        !^ ":"; !^ "Type" ^^ rparen]));
      !^ ":"; !^ "Type"; !^ ":=" ^^ hardline ^^
      flow hardline (ind.constructors |> List.map (fun (constr, args) ->
        group (flow (break 1) [
          !^ "|";Name.pp constr; !^ ":";
          flow empty (args |> List.map (fun arg -> Type.pp true arg ^/^ !^ "->" ^^ break 1)); Name.pp ind.name;
          flow (break 1) (List.map Name.pp ind.free_type_vars)]))) ^^ !^ "." ^^ hardline ^^
      flow hardline (ind.constructors |> List.map (fun (name, args) ->
        group (flow (break 1) [
          !^ "Arguments"; Name.pp name;
          flow (break 1) (ind.free_type_vars |> List.map (fun x -> !^ "{" ^^ Name.pp x ^^ !^ "}"));
          flow (break 1) (List.map (fun _ -> !^ "_") args) ^^ !^ "."])))])
end

(** A definition of a record. *)
module Record = struct
  type t = {
    name : Name.t;
    fields : (Name.t * Type.t) list (** The names of the fields with their types. *) }

  (** Pretty-print a record definition. *)
  let pp (r : t) : document =
    group (flow (break 1) [
      !^ "Record"; Name.pp r.name;!^ ":="; !^ "{" ^^ hardline ^^
      flow (!^ ";" ^^ hardline) (r.fields |> List.map (fun (x, typ) ->
        group (nest 2 (flow (break 1) [Name.pp x; !^ ":"; Type.pp false typ]))));
      !^ "}."])
end

(** The "open" construct to open a module. *)
module Open = struct
  type t = PathName.t

  (** Pretty-print an open construct. *)
  let pp (o : t): document =
    group (!^ "Require Import" ^/^ PathName.pp o ^^ !^ ".")
end

(** A structure. *)
type t =
  | Value of Value.t
  | Inductive of Inductive.t
  | Record of Record.t
  | Open of Open.t
  | Module of Name.t * t list

(** Import an OCaml structure. *)
let rec of_structure (structure : structure) : t list =
  let of_structure_item (item : structure_item) : t =
    match item.str_desc with
    | Tstr_value (rec_flag, [{vb_pat = {pat_desc = Tpat_var (name, _)}; vb_expr = e}]) ->
      let name = Name.of_ident name in
      let schema = Schema.of_type (Type.of_type_expr e.exp_type) in
      let free_type_vars = schema.Schema.variables in
      let (arg_names, body_exp) = Exp.open_function (Exp.of_expression e) in
      let (arg_typs, body_typ) = Type.open_function schema.Schema.typ (List.length arg_names) in
      Value {
        Value.name = name;
        free_type_vars = free_type_vars;
        args = List.combine arg_names (List.map Type.monadise arg_typs);
        body = (Exp.simplify @@ Exp.monadise body_exp, Type.Monad (Type.monadise body_typ));
        is_rec = Recursivity.of_rec_flag rec_flag }
    | Tstr_type [{typ_id = name; typ_type = typ}] ->
      (match typ.type_kind with
      | Type_variant cases ->
        let constructors = List.map (fun {cd_id = constr; cd_args = typs} ->
          (Name.of_ident constr, List.map (fun typ -> Type.of_type_expr typ) typs))
          cases in
        let free_type_vars = List.map (fun x ->
          match Type.of_type_expr x with
          | Type.Variable x -> x
          | _ -> failwith "The type parameter was expected to be a variable.")
          typ.type_params in
        Inductive {
          Inductive.name = Name.of_ident name;
          free_type_vars = free_type_vars;
          constructors = constructors }
      | Type_record (fields, _) ->
        Record {
          Record.name = Name.of_ident name;
          fields = List.map (fun {ld_id = x; ld_type = typ} -> (Name.of_ident x, Type.of_type_expr typ)) fields }
      | _ -> failwith "Type definition not handled.")
    | Tstr_open (_, path, _, _) -> Open (PathName.of_path path)
    | Tstr_module {mb_id = name; mb_expr = { mod_desc = Tmod_structure structure }} ->
      Module (Name.of_ident name, of_structure structure)
    | Tstr_exception _ -> failwith "Imperative structure item not handled."
    | _ -> failwith "Structure item not handled." in
  List.map of_structure_item structure.str_items

(** Pretty-print a structure. *)
let rec pp (defs : t list) : document =
  let pp_one (def : t) : document =
    match def with
    | Value value -> Value.pp value
    | Inductive ind -> Inductive.pp ind
    | Record record -> Record.pp record
    | Open o -> Open.pp o
    | Module (name, defs) ->
      group (flow (break 1) [
        !^ "Module"; Name.pp name ^^ !^ "." ^^ hardline ^^
        nest 2 (pp defs) ^^ hardline ^^
        !^ "End"; Name.pp name ^^ !^ "."]) in
  flow (hardline ^^ hardline) (List.map pp_one defs)