import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

import lustre/attribute
import lustre/event


/// Helper to convert errors from gleam/dynamic/decode back to gleam/dynamic, so Lustre understands it.
fn downgrade_error(res: Result(a, List(decode.DecodeError))) -> Result(a, List(dynamic.DecodeError)) {
  let map_err = fn(e: decode.DecodeError) { dynamic.DecodeError(e.expected, e.found, e.path) }
  result.map_error(res, list.map(_, map_err))
}

// Helper to convert a decoder from gleam/dynamic/decode back to gleam/dynamic, so Lustre understands it.
fn downgrade_decoder(decoder: decode.Decoder(a)) -> dynamic.Decoder(a) {
  fn(input: dynamic.Dynamic) { decode.run(input, decoder) |> downgrade_error }
}

/// Indicates which modiers were pressed during an event.
pub type ModifierState {
    ModifierState(alt: Bool, ctrl: Bool, meta: Bool, shift: Bool)
}

/// A decoder for ModifierState, which contains the key state of all modifier keys.
fn modifier_state_decoder() -> decode.Decoder(ModifierState) {
    use alt <- decode.field("altKey", decode.bool)
    use ctrl <- decode.field("ctrlKey", decode.bool)
    use meta <- decode.field("metaKey", decode.bool)
    use shift <- decode.field("shiftKey", decode.bool)
    ModifierState(alt:, ctrl:, meta:, shift:) |> decode.success
}

/// Helper to create a decoder in the old dynamic module that parses the modifier keys state,
/// and the pressed key, and converts it to a message, and allows the user to choose to call
/// preventDefault.
fn modifier_state_key_decoder(to_msg: fn(#(ModifierState, String)) -> #(msg, Bool)) -> dynamic.Decoder(msg) {
  let decoder = {
    use ms <- decode.then(modifier_state_decoder())
    use key <- decode.field("key", decode.string)
    #(ms, key) |> decode.success
  } |> downgrade_decoder

  fn(input) {
    use decode_result <- result.try(decoder(input))
    let #(msg, pd) = to_msg(decode_result)
    case pd { True -> event.prevent_default(input) False -> Nil }
    Ok(msg)
  }
}

/// on_click, but allows the user to inspect the state of the modifier keys.
pub fn on_click_mod(to_msg: fn(ModifierState) -> msg) -> attribute.Attribute(msg) {
 let decoder = {
   use ms <- decode.then(modifier_state_decoder())
   to_msg(ms) |> decode.success
 } |> downgrade_decoder

  event.on("click", decoder)
}

/// on_keydown, but allows the user to inspect the state of the modifier keys.
pub fn on_keydown_mod(to_msg: fn(#(ModifierState, String)) -> #(msg, Bool)) -> attribute.Attribute(msg) {
  event.on("keydown", modifier_state_key_decoder(to_msg))
}
