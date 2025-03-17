//// Short-circuiting logic, allowing the same syntax for short-circuiting all kinds of types.
import gleam/option.{type Option, None}
import gleam/order.{type Order, Eq}

/// A type containing all information needed to short-circuit a computation using the Gleam use notation.
pub opaque type ShortCircuitable(a, b, c) {
  ShortCircuitable(default: fn(b) -> c, f: fn() -> Result(a, b))
}

/// Helper to short-circuit a ShortCircuitable, yielding the result in case of success.
pub fn bind(sc: ShortCircuitable(a, b, c), f: fn(a) -> c) -> c {
  case sc {
    ShortCircuitable(..) as scf -> {
      case scf.f() {
        Error(err) -> sc.default(err)
        Ok(res) -> f(res)
      }
    }
  }
}

/// Helper to short-circuit a ShortCircuitable, without accepting a result even on success.
pub fn do(sc: ShortCircuitable(a, b, c), f: fn() -> c) -> c {
  case sc {
    ShortCircuitable(..) as scf -> {
      case scf.f() {
        Error(err) -> sc.default(err)
        Ok(_) -> f()
      }
    }
  }
}

// ========== Option ==========

/// A way to short-circuit options. If the option is None, this is returned.
/// Otherwise, the value in the Option can be used in the remaining computation.
pub fn option(opt: Option(a)) -> ShortCircuitable(a, Nil, Option(b)) {
  ShortCircuitable(fn(_) { None }, fn() { opt |> option.to_result(Nil) })
}

/// A way to short-circuit options. If the option is None, the specified default is returned.
/// Otherwise, the value in the Option can be used in the remaining calculation.
pub fn option_default(opt: Option(a), default: c) -> ShortCircuitable(a, Nil, c) {
  ShortCircuitable(fn(_) { default }, fn() { opt |> option.to_result(Nil) })
}

// ========== Result ==========

/// A way to short-circuit results. If the result is an Error, this is returned.
/// Otherwise, the value in the Ok result can be used in the remaining calculation.
pub fn result(res: Result(a, b)) -> ShortCircuitable(a, b, b) {
  ShortCircuitable(fn(err) { err }, fn() { res })
}

/// A way to short-circuit results. If the result is an Error, the specified default is returned.
/// Otherwise, the value in the Ok result can be used in the remaining calculation.
pub fn result_default(
  res: Result(a, b),
  default: c,
) -> ShortCircuitable(a, b, c) {
  ShortCircuitable(fn(_) { default }, fn() { res })
}

/// A way to short-circuit results. If the result is an Error, the provided mapping over this error is returned.
/// Otherwise, the value in the Ok result can be used in the remaining calculation.
pub fn result_map(
  res: Result(a, b),
  map: fn(b) -> c,
) -> ShortCircuitable(a, b, c) {
  ShortCircuitable(fn(err) { map(err) }, fn() { res })
}

// ========== Boolean ==========

/// A way to short-circuit pre-condition checking. If the pre-condition fails, the specified default is returned.
/// Otherwise, the computation can continue.
pub fn check(default: c, cond: Bool) -> ShortCircuitable(Nil, Nil, c) {
  ShortCircuitable(fn(_) { default }, fn() {
    case cond {
      True -> Ok(Nil)
      False -> Error(Nil)
    }
  })
}

// ========== Order ==========

/// A way to short-circuit order checking. If the order is Eq, more comparisons can be done.
/// Otherwise, the provided order is returned.
pub fn compare(order: Order) -> ShortCircuitable(Nil, Order, Order) {
  ShortCircuitable(fn(o) { o }, fn() {
    case order {
      Eq -> Ok(Nil)
      _ -> Error(order)
    }
  })
}
