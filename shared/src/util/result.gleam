/// Flips a result turning an Ok into an Error, and an Error into an Ok.
pub fn flip(
  res: Result(ok, err),
  map_ok: fn(ok) -> err2,
  map_err: fn(err) -> ok2,
) -> Result(ok2, err2) {
  case res {
    Ok(x) -> Error(map_ok(x))
    Error(x) -> Ok(map_err(x))
  }
}
