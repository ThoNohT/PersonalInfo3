import wisp

import model.{type Context}

pub fn handler(req: wisp.Request, _context: Context) -> wisp.Response {
  let assert ["api", "events", ..path] = wisp.path_segments(req)
  case path {
    _ -> wisp.not_found() |> wisp.string_body("Events method found!")
  }
}
