open Biocaml_internal_pervasives
module Range = Biocaml_range

type t = Range.t list (* retained in canonical form *)
type range = Range.t
exception Bad of string
let raise_bad msg = raise (Bad msg)

let empty = []
let size t = List.fold_left ~f:(fun ans v -> ans + Range.size v) ~init:0 t
let is_empty t = size t = 0

(* A canonical interval list is one in which adjacent intervals have gap between them and intervals retained in ascending order according to their coordinates. *)
let rec is_canonical (vl : Range.t list) : bool =
  match vl with
    | [] | _::[] -> true
    | u::(v::vl as tail) -> u.Range.hi < v.Range.lo && is_canonical tail
        
let to_canonical (vl : Range.t list) : Range.t list =
  (* Order relation such that subset and after are larger. *)
  let compare_intervals =
    Order.compose
      (Order.reversep Range.compare_containment)
      Range.compare_positional
  in
  
  let vl = List.sort ~cmp:compare_intervals vl in
  
  let rec canonize ans vl =
    match vl with
      | [] -> ans
      | v::[] -> v::ans
      | u::(v::vl as tail) ->
          if u = v then
            canonize ans tail
          else if Range.superset u v then
            canonize ans (u::vl)
          else if Range.before u v then
            match Range.union u v with
              | uv::[] -> canonize ans (uv::vl)
              | u::v::[] -> canonize (u::ans) tail
              | _ -> invalid_arg "impossible to get here"
          else
            invalid_arg "impossible to get here"
  in
  let ans = List.rev (canonize [] vl) in
  assert(is_canonical ans);
  ans
    
let of_range_list l = 
  let f acc (x,y) =
    match Range.make_opt x y with
      | Some range -> range::acc 
      | None -> acc
  in
  to_canonical (List.fold ~f ~init:[] l)

let to_range_list t = List.map ~f:Range.to_pair t

let to_list t = List.concat (List.map ~f:Range.to_list t)  
let union s t = to_canonical (s @ t) (* better implementation possible *)

let inter s t =
  let rec loop ans s t =
    match (s,t) with
      | (_, []) -> ans
      | ([], _) -> ans
      | ((u::s as ul), (v::t as vl)) ->
          if u.Range.lo > v.Range.hi then
            loop ans ul t
          else if u.Range.hi < v.Range.lo then
            loop ans s vl
          else
            match Range.intersect u v with
              | None -> invalid_arg "impossible to get here"
              | Some w ->
                  match Pervasives.compare u.Range.hi v.Range.hi with
                    | -1 -> loop (w::ans) s vl
                    |  0 -> loop (w::ans) s t
                    |  1 -> loop (w::ans) ul t
                    |  _ -> invalid_arg "impossible to get here"
  in
  to_canonical (loop [] s t) (* canoninicity could maybe be obtained simply by List.rev *)
    
let diff s t =
  let rec loop ans s t =
    match (s,t) with
      | (_,[]) -> ans @ (List.rev s)
      | ([],_) -> ans
      | ((u::s as ul), (v::t as vl)) ->
          if u.Range.lo > v.Range.hi then
            loop ans ul t
          else if u.Range.hi < v.Range.lo then
            loop (u::ans) s vl
          else
            match Range.intersect u v with
              | None -> invalid_arg "impossible to get here"
              | Some w ->
                  let u_pre = Range.make_opt u.Range.lo (w.Range.lo - 1) in
                  let u_post = Range.make_opt (w.Range.hi + 1) u.Range.hi in
                  (* v_pre = Range.make_opt v.Range.lo (w.Range.lo - 1)
                   ** v_pre not needed, note also that u_pre and v_pre cannot both be None *)
                  let v_post = Range.make_opt (w.Range.hi + 1) v.Range.hi in
                  let ans = match u_pre with None -> ans | Some x -> x::ans in
                  let s = match u_post with None -> s | Some x -> x::s in
                  let t = match v_post with None -> t | Some x -> x::t in
                  loop ans s t
  in
  to_canonical (loop [] s t)

let subset s t = is_empty (diff s t)

  
