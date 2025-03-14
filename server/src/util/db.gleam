import sqlight.{type Connection}

/// A wrapper around sqlight.with_connection, that can start a transaction.
pub fn with_connection(path: String, use_transaction: Bool, f: fn(Connection) -> a) -> a {
  use conn <- sqlight.with_connection(path)

  case use_transaction {
    True -> { let assert Ok(_) = sqlight.exec("BEGIN TRANSACTION", conn) Nil }
    False -> Nil
  }

  f(conn)
}

/// Commits the transaction active in a connection.
pub fn commit(conn: Connection, f: fn() -> a) -> a {
  let assert Ok(_) = sqlight.exec("COMMIT TRANSACTION", conn)
  f()
}
