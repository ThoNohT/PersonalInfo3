import gleam/option.{type Option}
import gleam/order.{type Order, Eq}
import gleam/result

/// A very generic version of option.then and result.try.
pub fn then(default: b, option: Option(a), apply fun: fn(a) -> b) -> b {
  case option {
    option.None -> default
    option.Some(val) -> fun(val)
  }
}

/// Like then, but checks a boolean. The resulting value is Nil.
pub fn check(default: a, value: Bool, apply fun: fn() -> a) -> a {
  case value {
    False -> default
    True -> fun()
  }
}

/// A way to short-circuit order checking. If the order is Eq, more comparisons can be done. Otherwise, the provided
/// order is returned.
pub fn compare_try(order: Order, apply fun: fn() -> Order) -> Order {
  case order {
    Eq -> fun()
    _ -> order
  }
}

/// Result.try, but does not accept a resulting value.
pub fn res(res: Result(a, b), apply fun: fn() -> Result(c, b)) -> Result(c, b) {
  use _ <- result.try(res)
  fun()
}
