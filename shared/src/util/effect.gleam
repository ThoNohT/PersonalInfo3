import gleam/option.{type Option}

import lustre/effect.{type Effect}

import util/short_circuit as sc

/// Return a new state, without sending a message.
pub fn just(val) {
  #(val, effect.none())
}

/// Simply dispatches an event to be processed next.
pub fn dispatch(val: msg) -> Effect(msg) {
  effect.from(fn(dispatch) { dispatch(val) })
}

/// short_circuit.result_default, that can be used for short-circuiting message and effect loops.
pub fn result_default(
  default: b,
  option: Result(a, d),
) -> sc.ShortCircuitable(a, d, #(b, Effect(e))) {
  sc.result_default(option, just(default))
}

/// short_circuit.option_default, that can be used for short-circuiting message and effect loops.
pub fn option_default(
  default: b,
  option: Option(a),
) -> sc.ShortCircuitable(a, Nil, #(b, Effect(c))) {
  sc.option_default(option, just(default))
}

/// short_circuit.check, that can be used for short-circuiting message and effect loops.
pub fn check(
  default: a,
  value: Bool,
) -> sc.ShortCircuitable(Nil, Nil, #(a, Effect(f))) {
  sc.check(just(default), value)
}

@target(javascript)
/// Dispatches the specified message every specified interval in milliseconds.
pub fn every(interval: Int, tick: msg) -> Effect(msg) {
  effect.from(fn(dispatch) { do_every(interval, fn() { dispatch(tick) }) })
}

@target(javascript)
@external(javascript, "./ffi.mjs", "every")
fn do_every(_interval: Int, _cb: fn() -> Nil) -> Nil
