import gleam/list
import gleam/option.{type Option, None, Some}

/// Returns a list with only the Some values.
pub fn somes(list: List(Option(a))) -> List(a) {
  list |> list.filter_map(option.to_result(_, ""))
}

/// Adds or updates an element to the list.
pub fn add_or_update(
  list: List(a),
  to_update: fn(a) -> Bool,
  new_value: a,
) -> List(a) {
  let result =
    list.fold(list, #([], False), fn(acc, elem) {
      case to_update(elem) {
        False -> #([elem, ..acc.0], acc.1)
        True -> #([new_value, ..acc.0], True)
      }
    })

  case result.1 {
    False -> list.reverse([new_value, ..result.0])
    _ -> list.reverse(result.0)
  }
}

/// Updates the element at the specified index in the list.
pub fn update_index(list: List(a), index: Int, update: fn(a) -> a) -> List(a) {
  list
  |> list.index_map(fn(v, i) {
    case i == index {
      True -> update(v)
      False -> v
    }
  })
}

/// Finds the index of the first element at that matches the provided predicate.
pub fn find_index(list: List(a), predicate: fn(a) -> Bool) -> Option(Int) {
  find_index_step(list, predicate, 0)
}

fn find_index_step(
  list: List(a),
  predicate: fn(a) -> Bool,
  start: Int,
) -> Option(Int) {
  case list {
    [] -> None
    [l, ..ls] ->
      case predicate(l) {
        True -> Some(start)
        False -> find_index_step(ls, predicate, start + 1)
      }
  }
}

/// Returns a new list with a sub-list removed.
pub fn splice(list: List(a), gap_start: Int, gap_length: Int) -> List(a) {
  list.append(
    list.take(list, gap_start),
    list.drop(list, gap_start + gap_length),
  )
}
