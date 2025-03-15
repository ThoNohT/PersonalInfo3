import gleam/dynamic
import gleam/dynamic/decode.{type Decoder} as d
import gleam/list
import gleam/result

/// Takes a decoder, and turns it into a decoder that accepts an object where the 
/// first field can be decoded using the specified decoder.
/// The result of the decoder is then returned if successful.
pub fn one(decoder: Decoder(a)) -> Decoder(a) {
  use val <- d.field(0, decoder)
  d.success(val)
}

/// Helper to convert errors from gleam/dynamic/decode back to gleam/dynamic, so Lustre understands it.
pub fn downgrade_error(
  res: Result(a, List(d.DecodeError)),
) -> Result(a, List(dynamic.DecodeError)) {
  let map_err = fn(e: d.DecodeError) {
    dynamic.DecodeError(e.expected, e.found, e.path)
  }
  result.map_error(res, list.map(_, map_err))
}

/// Helper to convert a decoder from gleam/dynamic/decode back to gleam/dynamic, so Lustre understands it.
pub fn downgrade_decoder(decoder: d.Decoder(a)) -> dynamic.Decoder(a) {
  fn(input: dynamic.Dynamic) { d.run(input, decoder) |> downgrade_error }
}

/// Converts a result into a decoder.
/// decode.failure requires a zero element, so one must be passed to this function as well.
pub fn from_result(res: Result(a, b), zero: a) -> d.Decoder(a) {
  case res {
    Ok(a) -> d.success(a)
    Error(_) -> d.failure(zero, "Result")
  }
}
