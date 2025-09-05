import wisp

import api/events
import api/simplestate
import api/user
import model.{type Context}

pub fn handler(req: wisp.Request, ctx: Context) -> wisp.Response {
  // The route should start with "api/", or this function should not be called.
  let assert ["api", ..path] = wisp.path_segments(req)
  case path {
    // User functions
    ["user", ..] -> user.handler(req, ctx)

    // Simple state functions.
    ["simplestate", key] -> simplestate.handler(req, ctx.conn_str, key)
    ["simplestate", ..] ->
      wisp.not_found() |> wisp.string_body("Unknown simple state method!")

    // Events functions.
    ["events", ..] -> events.handler(req, ctx)

    _ -> wisp.not_found() |> wisp.string_body("API not found!")
  }
}
