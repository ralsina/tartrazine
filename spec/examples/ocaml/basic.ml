(* a small module with a variant type *)
type shape =
  | Circle of float
  | Rect of float * float

let area = function
  | Circle r -> Float.pi *. r *. r
  | Rect (w, h) -> w *. h

let rec sum = function
  | [] -> 0
  | x :: xs -> x + sum xs

module Counter = struct
  let count = ref 0
  let incr () = count := !count + 1
end

let () =
  let shapes = [Circle 1.0; Rect (2.0, 3.5)] in
  List.iter (fun s -> Printf.printf "%.2f\n" (area s)) shapes;
  Counter.incr ();
  print_endline (string_of_int (sum [1; 2; 3]) ^ " " ^ "done")
