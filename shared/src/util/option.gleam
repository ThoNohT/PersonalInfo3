import gleam/option.{type Option, None, Some}

/// Filters an option using the provided predicate.
pub fn when(opt: Option(a), when: fn(a) -> Bool) -> Option(a) {
  use val <- option.then(opt)
  case when(val) {
    True -> Some(val)
    False -> None
  }
}

/// Attempts to get the first element from a list, returns None if the list is empty.
pub fn head(list: List(a)) -> Option(a) {
  case list {
    [hd, ..] -> Some(hd)
    _ -> None
  }
}
