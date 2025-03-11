import gleam/option.{type Option, None, Some}

pub fn when(opt: Option(a), when: fn(a) -> Bool) -> Option(a) {
  use val <- option.then(opt)
  case when(val) {
    True -> Some(val)
    False -> None
  }
}
