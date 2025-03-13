import gleam/io
import gleam/result

import simplifile
import sqlight

import util/prim

fn describe_sqlight_error(error: sqlight.Error) -> String {
  let sqlight.SqlightError(message:, ..) = error
  message
}

pub fn do(
  res: Result(a, b),
  prefix: String,
  err_convert: fn(b) -> String,
  then: fn() -> Nil,
) -> Nil {
  use _ <- prim.try(
    Nil,
    res
    |> result.map_error(err_convert)
    |> result.map_error(fn(str) { prefix <> ": " <> str })
    |> result.map_error(fn(str) {
      io.println_error(str)
      str
    }),
  )

  then()
}

pub fn try(
  res: Result(a, b),
  prefix: String,
  err_convert: fn(b) -> String,
  then: fn(a) -> Result(c, String),
) -> Result(c, String) {
  use converted <- result.then(
    res
    |> result.map_error(err_convert)
    |> result.map_error(fn(str) { prefix <> ": " <> str })
    |> result.map_error(fn(str) {
      io.println_error(str)
      str
    }),
  )

  then(converted)
}

/// result.try, but with conversion of a sqlight error to a string.
pub fn sql_try(res, prefix, then) {
  try(res, prefix, describe_sqlight_error, then)
}

/// like sql_try, but ignores the error, only prints it.
pub fn sql_do(res, prefix, then: fn() -> Nil) -> Nil {
  do(res, prefix, describe_sqlight_error, then)
}

/// result.try, but with conversion of a file-system error to a string.
pub fn fs_try(res, prefix, then) {
  try(res, prefix, simplifile.describe_error, then)
}
