
open OUnit
open Core.Std

module TS = Biocaml_transform.Pull_based
let make_stream ?more_columns file =
  let filename = "src/tests/data/" ^ file in
  let parser = Biocaml_bed.parser ?more_columns ~filename () in
  let stream = TS.of_file ~buffer_size:10 filename parser in
  stream
    
let test_parser () =
  let s = make_stream "bed_01.bed" in
  assert_bool "01 chrA" (TS.next s = `output ("chrA", 42, 45, []));
  assert_bool "01 chrB" (TS.next s = `output ("chrB", 100, 130, []));
  assert_bool "01 chrC" (TS.next s = `output ("chrC", 200, 245, []));
  assert_bool "01 EOF" (TS.next s = `end_of_stream);

  let s = make_stream "bed_02_incomplete_line.bed" in
  assert_bool "02 chrA" (TS.next s = `output ("chrA", 42, 45, []));
  assert_bool "02 chrB error "
    (match TS.next s with
    | `error (`incomplete_line (_, _)) -> true
    | _ -> false);

  let s =
    make_stream ~more_columns:[`string; `int; `float] "bed_03_more_cols.bed" in
  let the_expected_list = [`String "some_string"; `Int 42; `Float 3.14] in
  assert_bool "03 chrA" (TS.next s = `output ("chrA",  42,  45, the_expected_list));
  assert_bool "03 chrB" (TS.next s = `output ("chrB", 100, 130, the_expected_list));
  assert_bool "03 chrC" (TS.next s = `output ("chrC", 200, 245, the_expected_list));
  assert_bool "03 EOF" (TS.next s = `end_of_stream);

  let s =
    make_stream ~more_columns:[`string; `int; `float] "bed_04_more_cols_error.bed" in
  let the_expected_list = [`String "some_string"; `Int 42; `Float 3.14] in
  assert_bool "04 chrA" (TS.next s = `output ("chrA",  42,  45, the_expected_list));
  assert_bool "04 chrB error "
    (match TS.next s with
    | `error (`not_an_int (_, "forty_two")) -> true
    | _ -> false);
  assert_bool "04 chrC error "
    (match TS.next s with
    | `error (`wrong_number_of_columns (_, l)) when List.length l = 5 -> true
    | _ -> false);
  assert_bool "04 EOF" (TS.next s = `end_of_stream);
  
  ()

let make_printer_stream ?more_columns file =
  let filename = "src/tests/data/" ^ file in
  let parser = Biocaml_bed.parser ?more_columns ~filename () in
  let printer = Biocaml_bed.printer () in
  let trans = Biocaml_transform.compose parser printer in
  let stream = TS.of_file ~buffer_size:10 filename trans in
  stream
    
let test_printer () =
  let s =
    make_printer_stream
      ~more_columns:[`string; `int; `float] "bed_03_more_cols.bed" in
  let camlstream =
    Biocaml_transform.Pull_based.to_stream_exn
      ~error_to_exn:(fun e -> failwith "Unexpected error in camlstream") s in
  
  let l = Stream.npeek max_int camlstream in
  assert_equal
    ~printer:(fun l -> List.map ~f:(sprintf "Output: %S") l |! String.concat ~sep:", ")
    l ["chrA 42 45 some_string 42 3.14\n";
       "chrB 100 130 some_string 42 3.14\n";
       "chrC 200 245 some_string 42 3.14\n"; ];
  
  ()

let tests = "BED" >::: [
  "Parse BED" >:: test_parser;
  "Print BED" >:: test_printer;

]
