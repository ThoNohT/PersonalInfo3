import gleam/bit_array
import gleam/http
import gleam/option

import wisp

import repository
import util/db
import util/handler_helpers as hh

/// Loads or save simple state, based on the method.
pub fn handler(
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
