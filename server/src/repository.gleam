import shared_model
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}

import birl
import sqlight.{type Connection}

import model.{type User, User}
import util/decode as dec
import util/option as opt
import util/prim
import util/server_result.{sql_do, sql_try}

/// Retrieves the user with the specified username from the database.
pub fn get_user(
  conn: Connection,
  username: String,
) -> Result(Option(User), String) {
  let sql =
    "SELECT UserId, Username, Password, Salt FROM Users WHERE Username = ?"
  use user <- sql_try(
    sqlight.query(sql, conn, [sqlight.text(username)], model.user_decoder()),
    "Could not load user.",
  )

  case user {
    [] -> Ok(None)
    [user, ..] -> Ok(Some(user))
  }
}

/// Clears all sessions that are expired.
pub fn clear_expired_sessions(conn: Connection) {
  let sql = "DELETE FROM Sessions WHERE ExpiresAt <= ?"
  let param = [sqlight.text(prim.date_time_string(birl.utc_now()))]
  use <- sql_do(
    sqlight.query(sql, conn, param, decode.int),
    "Could not clear expired sessions.",
  )

  Nil
}

/// Adds a new session for the specified user.
pub fn add_session(
  conn: Connection,
  user: User,
  session_info: shared_model.SessionInfo,
) -> Result(Nil, String) {
  let sql =
    "INSERT INTO Sessions (UserId, SessionId, ExpiresAt) VALUES (?, ?, ?)"
  let param = [
    sqlight.int(user.id),
    sqlight.text(session_info.session_id),
    sqlight.text(prim.date_time_string(session_info.expires_at)),
  ]
  use _ <- sql_try(
    sqlight.query(sql, conn, param, decode.int),
    "Could not add new session.",
  )

  Ok(Nil)
}

/// Checks if the system can be initialized, allowing one user to be
/// made with a random string generated at startup.
/// This can be done only if there are no users yet, so no user has to be made manually.
pub fn can_init(conn: Connection) -> Result(Bool, String) {
  let sql = "SELECT COUNT(0) FROM Users"
  use count <- sql_try(
    sqlight.query(sql, conn, [], dec.one(decode.int)),
    "Could not determine the number of users.",
  )
  Ok(count == [0])
}

/// Adds a new user to the database.
pub fn create_user(
  conn: Connection,
  username: String,
  password: BitArray,
  salt: String,
) -> Result(Nil, String) {
  let sql = "INSERT INTO Users (Username, Password, Salt) VALUES (?, ?, ?)"
  let param = [
    sqlight.text(username),
    sqlight.blob(password),
    sqlight.text(salt),
  ]
  use _ <- sql_try(
    sqlight.query(sql, conn, param, decode.int),
    "Could not add new session.",
  )
  Ok(Nil)
}

/// Removes the specified session.
pub fn remove_session(conn: Connection, token: String) {
  let sql = "DELETE FROM Sessions WHERE SessionId = ?"
  let param = [sqlight.text(token)]
  use <- sql_do(
    sqlight.query(sql, conn, param, decode.int),
    "Could not delete a session.",
  )
  Nil
}

/// Tries to find a user with the specified session id.
/// Returns None if no session with this identifier was found.
pub fn find_user_from_session(
  conn: Connection,
  token: String,
) -> Result(Option(Int), String) {
  let sql =
    "
SELECT u.UserId FROM Users u
INNER JOIN Sessions s
ON u.UserId = s.UserId
WHERE s.SessionId = ? AND s.ExpiresAt > ?"
  let param = [
    sqlight.text(token),
    sqlight.text(prim.date_time_string(birl.now())),
  ]

  use user <- sql_try(
    sqlight.query(sql, conn, param, dec.one(decode.int)),
    "could not load session for user.",
  )

  opt.head(user) |> Ok
}

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
