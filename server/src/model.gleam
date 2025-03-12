import gleam/dynamic/decode.{type Decoder}
import gleam/bit_array
import gleam/crypto

pub type User {
  User(id: Int, username: String, salt: String, password_hash: String)
}

pub fn user_decoder() -> Decoder(User) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  use password_hash <- decode.field(2, decode.string)
  use salt <- decode.field(3, decode.string)

  decode.success(User(id:, username:, password_hash:, salt:))
}

import gleam/io
/// Hashes a password.
pub fn hash_password(password: String, user: User) -> String {
  io.println_error("Calculating: " <> password <> " - " <> user.salt)
  { password <> user.salt }
  |> bit_array.from_string
  |> crypto.hash(crypto.Sha512, _)
  |> bit_array.base64_encode(True)
}
