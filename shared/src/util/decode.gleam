import gleam/dynamic/decode.{type Decoder} as d

/// Takes a decoder, and turns it into a decoder that accepts an object where the 
/// first field can be decoded using the specified decoder.
/// The result of the decoder is then returned if succesfull.
pub fn one(decoder: Decoder(a)) -> Decoder(a) {
  use val <- d.field(0, decoder)
  d.success(val)
}

