import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/result

import birl
import simplifile
import sqlight.{type Connection}

import util/prim
import util/decode as dec
import util/parser.{type Parser} as p
import util/db
import util/server_result.{fs_try, sql_try, try}

type Migration {
  Migration(id: Int, name: String, full_name: String)
}

/// A parser for a migration.
fn migration_parser() -> Parser(Migration) {
  use int_str <- p.then(p.string_pred(p.char_is_digit))
  use id <- p.then(int_str |> int.parse() |> p.from_result)

  use <- p.do(p.string(". "))

  use name <- p.then(p.string_pred(fn(c) { c != "." }))

  use <- p.do(p.string(".sql"))
  use <- p.do(p.end())

  p.success(Migration(id, name, ""))
}

/// Creates the history table, if it doesn't already exist.
fn create_history_table(conn: Connection) {
  let sql =
    "CREATE TABLE IF NOT EXISTS SchemaHistory (
  Id INTEGER NOT NULL PRIMARY KEY,
  Name TEXT NOT NULL,
  AppliedAt TEXT NOT NULL
)"

  use _ <- sql_try(sqlight.exec(sql, conn), "Could not create history table")

  Ok(Nil)
}

/// Checks if a migration is applied.
fn is_migration_applied(migration: Migration, applied_migrations: List(Int)) {
  list.contains(applied_migrations, migration.id)
}

/// Runs a migration, if it was not already applied.
fn run_migration(
  conn: Connection,
  migration: Migration,
  applied_migrations: List(Int),
) {
  let name = int.to_string(migration.id) <> ". " <> migration.name
  case is_migration_applied(migration, applied_migrations) {
    True -> {
      io.println_error("Migration: " <> name <> " already applied.")
      Ok(Nil)
    }
    False -> {
      io.println("Running migration: " <> name)
      use contents <- fs_try(
        simplifile.read(migration.full_name),
        "Could not read file " <> name,
      )
      use _ <- sql_try(
        sqlight.exec(contents, conn),
        "Could not execute sql in file " <> name,
      )

      let sql =
        "INSERT INTO SchemaHistory (Id, Name, AppliedAt) VALUES (?, ?, ?)"
      let params = [
        sqlight.int(migration.id),
        sqlight.text(migration.name),
        sqlight.text(prim.date_time_string(birl.utc_now())),
      ]
      use _ <- sql_try(
        sqlight.query(sql, conn, params, decode.int),
        "Could not store application of migration " <> name,
      )
      Ok(Nil)
    }
  }
}

/// Reads all files in the specified directory that are recognized as migration files.
fn get_migration_files(
  migrations_path: String,
) -> Result(List(Migration), String) {
  let check_file = fn(name: String) -> Result(Migration, Nil) {
    let unerr = fn(r: Result(a, b)) -> Result(a, Nil) {
      result.map_error(r, fn(_) { Nil })
    }

    let full_name = migrations_path <> "/" <> name
    use fi <- result.try(full_name |> simplifile.file_info |> unerr)
    let ft = simplifile.file_info_type(fi)

    case ft, p.run(migration_parser(), name) {
      simplifile.File, Some(m) -> Ok(Migration(..m, full_name:))
      _, _ -> Error(Nil)
    }
  }

  // Retrieves all files in the path that are a file and end in .sql.
  use migration_files <- try(
    simplifile.read_directory(migrations_path),
    "Could not read directory " <> migrations_path,
    simplifile.describe_error,
  )
  migration_files |> list.map(check_file) |> result.values |> Ok
}

/// Retrieve the identifiers of all applied migrations.
fn get_applied_migrations(conn: Connection) -> Result(List(Int), String) {
  use applied_migrations <- sql_try(
    sqlight.query("SELECT Id FROM SchemaHistory", conn, [], dec.one(decode.int)),
    "Could not determine applied migrations.",
  )
  Ok(applied_migrations)
}

/// Checks if any migrations in the migrations path still need to be executed, and if so,
/// executes them.
pub fn migrate_database(
  conn_str: String,
  migrations_path: String,
) -> Result(Nil, String) {
  io.println("Running database migrations...")
  use conn <- db.with_connection(conn_str, True)
  use <- prim.res(create_history_table(conn))
  use migration_files <- result.try(get_migration_files(migrations_path))
  use applied_migrations <- result.try(get_applied_migrations(conn))

  // Run all migrations.
  use <- prim.res(
    migration_files
    |> list.map(run_migration(conn, _, applied_migrations))
    |> result.all,
  )
  use <- db.commit(conn)

  Ok(Nil)
}
