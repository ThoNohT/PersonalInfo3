import gleam/dynamic/decode
import gleam/option.{type Option}

import sqlight.{type Connection}

import util/decode as dec
import util/option as opt
import util/server_result.{sql_try}

/// Tries to find the state for the specified user and key.
/// Returns None if not found.
pub fn try_get_simple_state(
  conn: Connection,
  user_id: Int,
  key: String,
) -> Result(Option(BitArray), String) {
  let sql = "SELECT VALUE FROM SimpleState WHERE UserId = ? AND Key = ?"
  let param = [sqlight.int(user_id), sqlight.text(key)]

  use value <- sql_try(
    sqlight.query(sql, conn, param, dec.one(decode.bit_array)),
    "Could not load simple state.",
  )

  opt.head(value) |> Ok
}

/// Sets the state for the specified user and key. If it was already present, it is updated.
pub fn set_simple_state(
  conn: Connection,
  user_id: Int,
  key: String,
  value: BitArray,
) -> Result(Nil, String) {
  let sql =
    "
INSERT INTO SimpleState (UserId, Key, Value) VALUES (?, ?, ?)
ON CONFLICT (UserId, Key) DO UPDATE SET Value = ?
WHERE UserId = ? AND Key = ?"
  let param = [
    sqlight.int(user_id),
    sqlight.text(key),
    sqlight.blob(value),
    sqlight.blob(value),
    sqlight.int(user_id),
    sqlight.text(key),
  ]

  use _ <- sql_try(
    sqlight.query(sql, conn, param, dec.one(decode.int)),
    "Could not set simple state.",
  )

  Ok(Nil)
}
