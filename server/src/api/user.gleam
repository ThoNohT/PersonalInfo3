import gleam/http
import gleam/json
import shared_model

import birl
import birl/duration
import wisp

import model.{type Context}
import repository/user as repository
import util/db
import util/handler_helpers as hh
import util/random

pub fn handler(req: wisp.Request, context: Context) -> wisp.Response {
  let assert ["api", "user", ..path] = wisp.path_segments(req)
  case path {
    ["login"] -> login(req, context.conn_str)
    ["check_session"] -> check_session(req, context.conn_str)
    ["logout"] -> logout(req, context.conn_str)
    ["init"] -> init_user(req, context)
    _ -> wisp.not_found() |> wisp.string_body("Unknown user method!")
  }
}

// Attempts to login the user.
fn login(req: wisp.Request, conn_str: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  use creds <- hh.decode_body(400, req, shared_model.credentials_decoder())

  use conn <- db.with_connection(conn_str, True)
  use user <- hh.try(500, repository.get_user(conn, creds.username))
  // If not found, return 401 unauthorized.
  use user <- hh.then(401, user)

  // Check password
  use <- hh.check(401, model.check_password(creds.password, user))

  repository.clear_expired_sessions(conn)

  // Store session.
  let session_info =
    shared_model.SessionInfo(
      session_id: random.ascii_string(128),
      expires_at: birl.add(birl.utc_now(), duration.hours(6)),
    )
  use _ <- hh.try(500, repository.add_session(conn, user, session_info))

  use <- db.commit(conn)

  let body = shared_model.encode_session_info(session_info)
  wisp.json_response(json.to_string_tree(body), 200)
}

// Checks whether a session is valid.
fn check_session(req: wisp.Request, conn_str: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  use token <- hh.require_header(401, req, "authorization")

  use conn <- db.with_connection(conn_str, True)
  use user_id <- hh.try(500, repository.find_user_from_session(conn, token))
  use _ <- hh.then(401, user_id)

  repository.clear_expired_sessions(conn)
  use <- db.commit(conn)

  wisp.ok()
}

// Attempts to login the user.
fn logout(req: wisp.Request, conn_str: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use token <- hh.require_header(401, req, "authorization")

  use conn <- db.with_connection(conn_str, True)
  repository.remove_session(conn, token)
  use <- db.commit(conn)

  wisp.ok()
}

// Creates an initial user, if there are no users in the database yet.
fn init_user(req: wisp.Request, context: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  // Check the secret.
  use secret <- hh.then(401, context.init_secret)
  use input_secret <- hh.require_header(401, req, "secret")
  use <- hh.check(401, secret == input_secret)

  use creds <- hh.decode_body(400, req, shared_model.credentials_decoder())

  // There must still be no users in the database.
  use conn <- db.with_connection(context.conn_str, True)
  use can_init <- hh.try(400, repository.can_init(conn))
  use <- hh.check(401, can_init)

  let salt = random.ascii_string(32)
  let password_hash = model.hash_password(creds.password, salt)
  use _ <- hh.try(
    500,
    repository.create_user(conn, creds.username, password_hash, salt),
  )

  use <- db.commit(conn)

  wisp.ok()
}
