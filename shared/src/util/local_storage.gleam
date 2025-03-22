@target(javascript)
import gleam/dynamic/decode.{type Decoder}
@target(javascript)
import gleam/json.{type Json}
@target(javascript)
import gleam/option.{type Option, None, Some}

@target(javascript)
import util/decode as dec
@target(javascript)
import util/prim

@target(javascript)
@external(javascript, "./ffi.mjs", "localstorage_get")
fn js_get(name: String) -> String

@target(javascript)
@external(javascript, "./ffi.mjs", "localstorage_set")
fn js_set(name: String, value: String) -> Nil

@target(javascript)
/// Removes the value at the spcified key from local storage.
@external(javascript, "./ffi.mjs", "localstorage_remove")
pub fn remove(name: String) -> Nil

@target(javascript)
/// Clears local storage.
@external(javascript, "./ffi.mjs", "localstorage_clear")
pub fn clear() -> Nil

@target(javascript)
/// Gets the value with the specified key from local storage.
pub fn get(name: String, decoder: Decoder(a)) -> Option(a) {
  let value = js_get(name)
  use result <- prim.try(
    None,
    json.decode(value, dec.downgrade_decoder(decoder)),
  )
  Some(result)
}

@target(javascript)
/// Sets the value with the specified key in local storage.
pub fn set(name: String, value: a, encoder: fn(a) -> Json) {
  let encoded = encoder(value)
  js_set(name, json.to_string(encoded))
}
