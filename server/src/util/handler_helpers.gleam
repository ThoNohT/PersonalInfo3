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
