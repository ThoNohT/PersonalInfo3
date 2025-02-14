import lustre/effect

// Return a new state, without sending a message.
pub fn just(val) { #(val, effect.none()) }

