import gleam/option.{type Option, Some, None}

import sqlight.{type Connection}

import model.{type User, User}
import util/server_result.{sql_try}

/// Retrieves the user with the specified username from the database.
pub fn get_user(conn: Connection, username: String) -> Result(Option(User), String) {
  let sql = "SELECT UserId, Username, Password FROM Users WHERE Username = ?"
  use user <- sql_try(
    sqlight.query(sql, conn, [sqlight.text(username)], model.user_decoder()),
    "Could not load user.",
  )

  case user {
    [] -> Ok(None)
    [user, ..] -> Ok(Some(user))
  }
}
