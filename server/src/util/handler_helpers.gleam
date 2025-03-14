import gleam/dynamic/decode.{type Decoder}
import gleam/list

import util/prim
import wisp.{type Request, type Response}

/// prim.then for wisp handlers that returns an error response.
pub fn then(error_code: Int, option, apply fun: fn(a) -> Response) -> Response {
  prim.then(wisp.response(error_code), option, fun)
}

/// prim.check for wisp handlers that returns an error response.
pub fn check(error_code: Int, value, apply fun: fn() -> Response) -> Response {
  prim.check(wisp.response(error_code), value, fun)
}

/// prim.try for wisp handlers that returns an error response.
pub fn try(error_code: Int, res, apply fun: fn(a) -> Response) -> Response {
  prim.try(wisp.response(error_code), res, fun)
}

/// Checks that the specified header is present, and returns it.
/// Returns the provided response if it was not present.
pub fn require_header(
  on_failure: Int,
  req: Request,
  name: String,
  then: fn(String) -> Response,
) -> Response {
  use header <- prim.try(
    wisp.response(on_failure),
    req.headers |> list.find(fn(t) { t.0 == name }),
  )

  then(header.1)
}

/// Requires a json body, and runs the provided decoder on it,
/// failing with the provided failure if the decoder failed.
pub fn decode_body(
  on_failure: Int,
  req: Request,
  decoder: Decoder(a),
  then: fn(a) -> Response,
) -> Response {
  use body <- wisp.require_json(req)
  use result <- prim.try(wisp.response(on_failure), decode.run(body, decoder))
  then(result)
}
