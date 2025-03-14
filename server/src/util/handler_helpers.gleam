import gleam/dynamic/decode.{type Decoder}
import gleam/list

import util/prim
import wisp.{type Request, type Response}

/// Checks that the specified header is present, and returns it.
/// Returns the provided response if it was not present.
pub fn require_header(
  on_failure: Response,
  req: Request,
  name: String,
  then: fn(String) -> Response,
) -> Response {
  use header <- prim.try(
    on_failure,
    req.headers |> list.find(fn(t) { t.0 == name }),
  )

  then(header.1)
}

/// Requires a json body, and runs the provided decoder on it,
/// failing with the provided failure if the decoder failed.
pub fn decode_body(
  on_failure: Response,
  req: Request,
  decoder: Decoder(a),
  then: fn(a) -> Response
) -> Response {
  use body <- wisp.require_json(req)
  use result <- prim.try(on_failure, decode.run(body, decoder))
  then(result)
}
