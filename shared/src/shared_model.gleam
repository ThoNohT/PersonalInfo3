import gleam/dynamic/decode.{type Decoder}
import gleam/json

import util/decode as d
import util/prim

import birl

/// Credentials, provided by the client.
pub type Credentials {
  Credentials(username: String, password: String)
}

/// A decoder for credentials.
pub fn credentials_decoder() -> Decoder(Credentials) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)

  decode.success(Credentials(username, password))
}

/// Encodes credentials.
pub fn encode_credentials(cred: Credentials) -> json.Json {
  json.object([
    #("username", json.string(cred.username)),
    #("password", json.string(cred.password)),
  ])
}

// Information about a session received after logging in.
pub type SessionInfo {
  SessionInfo(session_id: String, expires_at: birl.Time)
}

/// A decoder for session info.
pub fn session_info_decoder() -> Decoder(SessionInfo) {
  use session_id <- decode.field("sessionId", decode.string)
  use expires_at <- decode.field("expiresAt", decode.string)
  use expires_at <- decode.then(
    birl.parse(expires_at) |> d.from_result(birl.unix_epoch),
  )

  decode.success(SessionInfo(session_id, expires_at))
}

/// Encodes session info.
pub fn encode_session_info(si: SessionInfo) -> json.Json {
  json.object([
    #("sessionId", json.string(si.session_id)),
    #("expiresAt", json.string(prim.date_time_string(si.expires_at))),
  ])
}
