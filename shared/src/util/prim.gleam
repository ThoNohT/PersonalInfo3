import gleam/io
import gleam/string

import birl

/// Converts a time into a date + time string.
pub fn date_time_string(time: birl.Time) {
  birl.to_naive_date_string(time) <> " " <> birl.to_naive_time_string(time)
}

/// Like echo, but doesn't print the location, and allows a prefix.
pub fn dbg(value: a, prefix: String) -> a {
  io.println(prefix <> ": " <> value |> string.inspect)
  value
}
