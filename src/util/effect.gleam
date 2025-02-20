import gleam/option.{type Option}

import lustre/effect.{type Effect}

import util/prim

/// Return a new state, without sending a message.
pub fn just(val) { #(val, effect.none()) }

/// Simply dispatches an event to be processed next.
pub fn dispatch(val) { effect.from(fn(dispatch) { dispatch(val) }) }

/// Option.then, that can be used for short-circuiting message and effect loops.
pub fn then(default: b, option: Option(a), apply fun: fn(a) -> #(b, Effect(c))) -> #(b, Effect(c)) {
  prim.then(just(default), option, fun)
}

/// Then, but it checks a boolean value rather than an option.
pub fn check(default: a, value: Bool, apply fun: fn(Bool) -> #(a, Effect(b))) -> #(a, Effect(b)) {
  prim.check(just(default), value, fun)
}