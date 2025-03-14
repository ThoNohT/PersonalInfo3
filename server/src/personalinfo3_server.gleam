import gleam/erlang/process
import gleam/io
import gleam/option.{Some, None}
import gleam/result

import mist
import sqlight
import wisp
import wisp/wisp_mist

import util/prim
import util/random
import api
import model.{type Context, Context}
import db_migrate
import repository

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  // Serve static files, and a dedicated handler for the empty path which should host index.html.
  use <- wisp.serve_static(req, under: "/static", from: "..//client//dist")
  case wisp.path_segments(req) {
    [] -> wisp.ok() |> wisp.set_body(wisp.File("..//client//dist//index.html"))
    _ -> handle_request(req)
  }
}

fn handle_request(req: wisp.Request, context: Context) -> wisp.Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["api", ..] -> api.handler(req, context)
    _ -> wisp.not_found() |> wisp.string_body("Not found.")
  }
}

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // Perform startup logic.
  let conn_str = "file:../pi3.db"
  use <- prim.res(
    db_migrate.migrate_database(conn_str, "../migrations")
    |> result.map_error(io.println_error),
  )

  let context = {
    use conn <- sqlight.with_connection(conn_str)
    let assert Ok(can_init) = repository.can_init(conn)
    let secret_key = case can_init {
      False -> None
      True -> {
        let secret = random.ascii_string(32)
        io.println("There are no users in the database yet.")
        io.println("You can use the following key to create the first user:")
        io.println("\"" <> secret <> "\"")
        io.println("")
        secret |> Some
      }
    }
    Context(conn_str, secret_key)
  }

  let handle_request = handle_request(_, context)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(5500)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
  Ok(Nil)
}
