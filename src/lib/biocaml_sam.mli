(** SAM files. *)


type raw_alignment = {
  qname : string;
  flag : int;
  rname : string;
  pos : int;
  mapq : int;
  cigar : string;
  rnext : string;
  pnext : int;
  tlen : int;
  seq : string;
  qual : string;
  optional : (string * char * string) list
}
(** The contents of an alignment line. *)

type raw_item = [
| `comment of string
| `header of string * (string * string) list
| `alignment of raw_alignment
]
(** The "items" of a parsed SAM file stream. *)

type raw_parsing_error = [
| `incomplete_input of Biocaml_pos.t * string list * string option
| `invalid_header_tag of Biocaml_pos.t * string
| `invalid_tag_value_list of Biocaml_pos.t * string list
| `not_an_int of Biocaml_pos.t * string * string
| `wrong_alignment of Biocaml_pos.t * string
| `wrong_optional_field of Biocaml_pos.t * string
]
(** The possible errors one can get while parsing SAM files. *)

  
val raw_parser: ?filename:string -> unit ->
  (string, raw_item, raw_parsing_error) Biocaml_transform.t
(** Create a parsing "stoppable" transform. *)   

    
val raw_printer: unit ->
  (raw_item, string, Biocaml_transform.no_error) Biocaml_transform.t
(** Create a printing "stoppable" transform. *)   

type reference_sequence = {
  ref_name: string;
  ref_length: int;
  ref_assembly_identifier: string option;
  ref_checksum: string option;
  ref_species: string option;
  ref_uri: string option;
  ref_unknown: (string * string) list;
}

val reference_sequence :
  ?assembly_identifier:string ->
  ?checksum:string ->
  ?species:string ->
  ?uri:string ->
  ?unknown_data:(string * string) list ->
  string -> int -> reference_sequence

module Flags : sig
  type t = private int

  val of_int: int -> t
    
  val has_multiple_segments            : t -> bool
  val each_segment_properly_aligned    : t -> bool
  val segment_unmapped                 : t -> bool
  val next_segment_unmapped            : t -> bool
  val seq_is_reverse_complemented      : t -> bool
  val next_seq_is_reverse_complemented : t -> bool
  val first_segment                    : t -> bool
  val last_segment                     : t -> bool
  val secondary_alignment              : t -> bool
  val not_passing_quality_controls     : t -> bool
  val pcr_or_optical_duplicate         : t -> bool
end

type cigar_op = [
| `D of int
| `Eq of int
| `H of int
| `I of int
| `M of int
| `N of int
| `P of int
| `S of int
| `X of int ]

type optional_content_value = [
| `array of optional_content_value array
| `char of char
| `float of float
| `int of int
| `string of string ]
type optional_content = (string * char * optional_content_value) list   

type alignment = {
  query_template_name: string;
  flags: Flags.t;
  reference_sequence: [ `reference_sequence of reference_sequence
                      | `none
                      | `name of string ];
  position: int option;
  mapping_quality: int option;
  cigar_operations: cigar_op array;

  next_ref_name: [`qname | `none | `name of string
                 | `reference_sequence of reference_sequence ];
  next_ref_position: int option;

  tamplate_length: int option;

  sequence: [ `string of string | `reference | `none];
  quality: Biocaml_phred_score.t array;
  optional_content: optional_content;
}

type item = [
| `comment of string
| `header_line of
    string * [`unknown | `unsorted | `queryname | `coordinate ] *
      (string * string) list
| `reference_sequence_dictionary of reference_sequence array
| `header of string * (string * string) list
| `alignment of alignment
]

val parse_cigar_text: string ->
  (cigar_op array, [> `wrong_cigar_text of string ]) Core.Result.t

type optional_content_parsing_error = [
| `wrong_optional of (string * char * string) list *
    [ `not_a_char of string
    | `not_a_float of string
    | `not_an_int of string
    | `unknown_type of char
    | `wrong_array of
        [ `not_a_char of string
        | `not_a_float of string
        | `not_an_int of string
        | `wrong_type of string 
        | `unknown_type of char ]
    | `wrong_type of string ]
]

val parse_optional_content: (string * char * string) list ->
  (optional_content, optional_content_parsing_error) Core.Result.t
  
type item_parsing_error = [
| `comment_after_end_of_header of int * string
| `duplicate_in_reference_sequence_dictionary of reference_sequence array
| `header_after_end_of_header of int * (string * (string * string) list)
| `header_line_not_first of int
| `header_line_without_version of (string * string) list
| `header_line_wrong_sorting of string
| `missing_ref_sequence_length of (string * string) list
| `missing_ref_sequence_name of (string * string) list
| `wrong_cigar_text of string
| `wrong_flag of raw_alignment
| `wrong_mapq of raw_alignment
| `wrong_phred_scores of raw_alignment
| `wrong_pnext of raw_alignment
| `wrong_pos of raw_alignment
| `wrong_qname of raw_alignment
| `wrong_ref_sequence_length of (string * string) list
| `wrong_tlen of raw_alignment 
| optional_content_parsing_error
]

val item_parser: unit -> (raw_item, item, item_parsing_error) Biocaml_transform.t

