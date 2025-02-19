import lustre/effect

/// Return a new state, without sending a message.
pub fn just(val) { #(val, effect.none()) }

/// Simply dispatches an event to be processed next.
pub fn dispatch(val) { effect.from(fn(dispatch) { dispatch(val) }) }

