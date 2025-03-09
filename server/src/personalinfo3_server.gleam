import gleam/erlang/process

import mist
import wisp
import wisp/wisp_mist

pub fn middleware(req: wisp.Request, handle_request: fn(wisp.Request) -> wisp.Response) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  
  // Serve static files, and a dedicated handler for the empty path which should host index.html.
  use <- wisp.serve_static(req, under: "/static", from: "..//client//dist")
  case wisp.path_segments(req) {
    [] -> wisp.ok()
          |> wisp.set_body(wisp.File("..//client//dist//index.html"))
    _ -> handle_request(req)
  }
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  use _req <- middleware(req)
  wisp.not_found() |> wisp.string_body("Not found!")
}

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(5500)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}
