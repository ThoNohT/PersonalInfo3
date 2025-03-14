import gleam/bit_array
import gleam/http
import gleam/json
import gleam/option

import birl
import birl/duration
import wisp

import model.{type Context}
import repository
import util/db
import util/handler_helpers as hh
import util/prim
import util/random

pub fn handler(req: wisp.Request, ctx: Context) -> wisp.Response {
  // The route should start with "api/", or this function should not be called.
  let assert ["api", ..path] = wisp.path_segments(req)
  case path {
    // User functions
    ["user", "login"] -> login(req, ctx.conn_str)
    ["user", "logout"] -> logout(req, ctx.conn_str)
    ["user", "init"] -> init_user(req, ctx)

    // Simple state functions.
    ["simplestate", key] -> load_or_save_simple_state(req, ctx.conn_str, key)

    _ -> wisp.not_found() |> wisp.string_body("Not found!")
  }
}

// Attempts to login the user.
fn login(req: wisp.Request, conn_str: String) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  use creds <- hh.decode_body(400, req, model.credentials_decoder())

  use conn <- db.with_connection(conn_str, True)
  use user <- hh.try(500, repository.get_user(conn, creds.username))
  // If not found, return 401 unauthorized.
  use user <- hh.then(401, user)

  // Check password
  use <- hh.check(401, model.check_password(creds.password, user))

  repository.clear_expired_sessions(conn)

  // Store session.
  let session_id = random.ascii_string(128)
  let expires_at = birl.add(birl.utc_now(), duration.hours(6))
  use _ <- hh.try(
    500,
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

  use creds <- hh.decode_body(400, req, model.credentials_decoder())

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

/// Loads or save simple state, based on the method.
fn load_or_save_simple_state(
  req: wisp.Request,
  conn_str: String,
  key: String,
) -> wisp.Response {
  case req.method {
    http.Get -> load_simple_state(req, conn_str, key)
    http.Put -> save_simple_state(req, conn_str, key)
    _ -> wisp.method_not_allowed(allowed: [http.Get, http.Put])
  }
}

fn load_simple_state(
  req: wisp.Request,
  conn_str: String,
  key: String,
) -> wisp.Response {
  use token <- hh.require_header(401, req, "authorization")

  use conn <- db.with_connection(conn_str, False)
  use user_id <- hh.try(500, repository.find_user_from_session(conn, token))
  use user_id <- hh.then(401, user_id)

  use state <- hh.try(500, repository.try_get_simple_state(conn, user_id, key))
  use text <- hh.try(500, bit_array.to_string(option.unwrap(state, <<>>)))

  wisp.ok() |> wisp.string_body(text)
}

fn save_simple_state(
  req: wisp.Request,
  conn_str: String,
  key: String,
) -> wisp.Response {
  use token <- hh.require_header(401, req, "authorization")

  use conn <- db.with_connection(conn_str, True)
  use user_id <- hh.try(500, repository.find_user_from_session(conn, token))
  use user_id <- hh.then(401, user_id)

  use value <- hh.try(400, wisp.read_body_to_bitstring(req))

  use _ <- hh.try(500, repository.set_simple_state(conn, user_id, key, value))

  use <- db.commit(conn)
  wisp.ok()
}
