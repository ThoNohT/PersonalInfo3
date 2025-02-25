import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

import lustre/attribute
import lustre/event

// Helper to convert a decoder from dynamic/decode back to dynamic, so Lustre understands it.
fn downgrade_decoder(decoder: decode.Decoder(a)) -> dynamic.Decoder(a) {
  let old_to_new_errors =
    fn(error: decode.DecodeError) {
      dynamic.DecodeError(error.expected, error.found, error.path)
    }

  fn(input: dynamic.Dynamic) {
    let result = decode.run(input, decoder)
    result.map_error(result, list.map(_, old_to_new_errors))
  }
}

/// Indicates which modiers were pressed during an event.
pub type ModifierState {
    ModifierState(alt: Bool, ctrl: Bool, meta: Bool, shift: Bool)
}

/// on_click, but allows the user to inspect the state of the modifier keys.
pub fn on_click_mod(to_msg: fn(ModifierState) -> msg) -> attribute.Attribute(msg) {
  let decoder = {
      use alt <- decode.field("altKey", decode.bool)
      use ctrl <- decode.field("ctrlKey", decode.bool)
      use meta <- decode.field("metaKey", decode.bool)
      use shift <- decode.field("shiftKey", decode.bool)
      to_msg(ModifierState(alt:, ctrl:, meta:, shift:)) |> decode.success
  } |> downgrade_decoder

  event.on("click", decoder)
}
