import gleam/http
import gleam/json

import birl
import birl/duration
import wisp

import model.{type Context}
import repository
import util/db
import util/handler_helpers as hh
import util/prim
import util/random

pub fn handler(req: wisp.Request, context: Context) -> wisp.Response {
  // The route should start with "api/", or this function should not be called.
  let assert ["api", ..path] = wisp.path_segments(req)
  case path {
    ["login"] -> login(req, context.conn_str)
    ["user", "init"] -> init_user(req, context)
    _ -> wisp.not_found() |> wisp.string_body("Not found!")
  }
}

// Attempts to login the user.
fn login(req: wisp.Request, conn_str: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  use creds <- hh.decode_body(wisp.bad_request(), req, model.credentials_decoder())

  use conn <- db.with_connection(conn_str, True)
  use user <- prim.try(
    wisp.internal_server_error(),
    repository.get_user(conn, creds.username),
  )
  // If not found, return 401 unauthorized.
  use user <- prim.then(wisp.response(401), user)

  // Check password
  use <- prim.check(wisp.response(401), model.check_password(creds.password, user))

  repository.clear_expired_sessions(conn)

  // Store session.
  let session_id = random.ascii_string(128)
  let expires_at = birl.add(birl.utc_now(), duration.hours(6))
  use _ <- prim.try(
    wisp.internal_server_error(),
    repository.add_session(conn, user, session_id, expires_at),
  )

  use <- db.commit(conn)

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

  use creds <- hh.decode_body(wisp.bad_request(), req, model.credentials_decoder())

  // There must still be no users in the database.
  use conn <- db.with_connection(context.conn_str, True)
  use can_init <- prim.try(
    wisp.internal_server_error(),
    repository.can_init(conn),
  )
  use <- prim.check(wisp.response(401), can_init)

  let salt = random.ascii_string(32)
  let password_hash = model.hash_password(creds.password, salt)
  use _ <- prim.try(
    wisp.internal_server_error(),
    repository.create_user(conn, creds.username, password_hash, salt),
  )

  use <- db.commit(conn)

  wisp.ok()
}
