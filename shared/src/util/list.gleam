import gleam/list
import gleam/option.{type Option}

// Returns a list with only the Some values.
pub fn somes(list: List(Option(a))) -> List(a) {
  list |> list.filter_map(option.to_result(_, ""))
}
