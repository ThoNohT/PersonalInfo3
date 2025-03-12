import gleam/dynamic/decode
import gleam/http
import gleam/string_tree

import sqlight
import wisp

import model
import repository
import util/prim

pub fn handler(req: wisp.Request, conn_str: String) -> wisp.Response {
  // The route should start with "api/", or this function should not be called.
  let assert ["api", ..path] = wisp.path_segments(req)
  case path {
    ["login"] -> login(req, conn_str)
    _ -> wisp.not_found() |> wisp.string_body("Not found!")
  }
}

// Attempts to login the user.
fn login(req: wisp.Request, conn_str: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  let login_decoder = {
    use username <- decode.field("username", decode.string)
    use password <- decode.field("password", decode.string)

    decode.success(#(username, password))
  }

  use body <- wisp.require_json(req)
  use creds <- prim.try(wisp.bad_request(), decode.run(body, login_decoder))

  use conn <- sqlight.with_connection(conn_str)
  use user <- prim.try(
    wisp.internal_server_error(),
    repository.get_user(conn, creds.0),
  )
  // If not found, return 401 unauthorized.
  use user <- prim.then(wisp.response(401), user)

  // Check password
  use <- prim.check(
    wisp.response(401),
    user.password_hash == model.hash_password(creds.1, user),
  )

  // TODO: Insert session, cleanup session, return session id.
  wisp.json_response(string_tree.from_string(""), 200)
}
