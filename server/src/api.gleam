import gleam/dynamic/decode
import gleam/http
import gleam/json

import birl
import birl/duration
import sqlight
import wisp

import util/prim
import util/random
import util/handler_helpers as hh
import model.{type Context}
import repository

pub fn handler(req: wisp.Request, context: Context) -> wisp.Response {
  // The route should start with "api/", or this function should not be called.
  let assert ["api", ..path] = wisp.path_segments(req)
  case path {
    ["login"] -> login(req, context.conn_str)
    ["user", "init" ] -> init_user(req, context)
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
  use <- prim.check(wisp.response(401), model.check_password(creds.1, user))

  repository.clear_expired_sessions(conn)

  // Store session.
  let session_id = random.ascii_string(128)
  let expires_at = birl.add(birl.utc_now(), duration.hours(6))
  use _ <- prim.try(
    wisp.internal_server_error(),
    repository.add_session(conn, user, session_id, expires_at),
  )

  let body =
    json.object([
      #("session_id", json.string(session_id)),
      #("expires_at", json.string(prim.date_time_string(expires_at))),
    ])
  wisp.json_response(json.to_string_tree(body), 200)
}

fn init_user(req: wisp.Request, context: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  // Check the secret.
  use secret <- prim.then(wisp.response(401), context.init_secret)
  use input_secret <- hh.require_header(wisp.response(401), req, "secret")
  use <- prim.check(wisp.response(401), secret == input_secret)

  // There must still be no users in the database.
  use conn <- sqlight.with_connection(context.conn_str)
  use _ <- prim.try(wisp.response(401), repository.can_init(conn))

  let login_decoder = {
    use username <- decode.field("username", decode.string)
    use password <- decode.field("password", decode.string)

    decode.success(#(username, password))
  }
  use body <- wisp.require_json(req)
  use creds <- prim.try(wisp.bad_request(), decode.run(body, login_decoder))

  let salt = random.ascii_string(32)
  let password = model.hash_password(creds.1, salt)
  use _ <- prim.try(
    wisp.internal_server_error(),
    repository.create_user(conn, creds.0, password, salt)
  )

  wisp.ok()
}
