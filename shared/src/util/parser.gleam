import gleam/io
import gleam/option.{type Option, Some, None}
import gleam/string

pub type ParseSuccess(a) { ParseSuccess(result: a, remaining: List(String)) }
pub type ParseResult(a) = Option(ParseSuccess(a))
pub type Parser(a) = fn(List(String)) -> ParseResult(a)

/// Runs a parser.
pub fn run(p: Parser(a), input: String) -> Option(a) {
  input |> string.to_graphemes |> p |> option.map(fn(x) { x.result })
}

/// A parser that returns the specified value and doesnt't consume anything.
pub fn success(res: a) -> Parser(a) {
  fn(input) { Some(ParseSuccess(res, input)) }
}

/// A parser that always fails.
pub fn failure() -> Parser(a) { fn(_) { None } }

/// Converts a Result into a parser.
pub fn from_result(res: Result(a, b)) -> Parser(a) {
  case res {
    Ok(r) -> success(r)
    Error(_) -> failure()
  }
}

/// Converts an Option into a parser.
pub fn from_option(res: Option(a)) -> Parser(a) {
  case res {
    Some(r) -> success(r)
    None -> failure()
  }
}

/// A parser that consumes a single character and returns it.
pub fn pchar() -> Parser(String) {
  fn(input) {
    case input {
      [ head, ..remaining ] -> Some(ParseSuccess(head, remaining))
      [] -> None
    }
  }
}

/// A parser that succeeds if there is no more input left, and fails otherwise.
pub fn end() -> Parser(Nil) {
  fn(input) {
    case input { [] -> Some(ParseSuccess(Nil, input)) _ -> None }
  }
}

/// Combines two parser by running the second parser after the first one, using its result.
/// This should allow parsers to be used in a use block.
pub fn then(p: Parser(a), then: fn(a) -> Parser(b)) -> Parser(b) {
  fn(input) {
    case p(input) {
      Some(ps) -> then(ps.result)(ps.remaining)
      None -> None
    }
  }
}

/// Combines two parser by running the second parser after the first one, ignoring the result of the first one.
/// This should allow parsers to be used in a use block, without having to bind to the result.
pub fn do(p: Parser(a), then: fn() -> Parser(b)) -> Parser(b) {
  fn(input) {
    case p(input) {
      Some(ps) -> then()(ps.remaining)
      None -> None
    }
  }
}

/// Maps the specified function over the result of a parser.
pub fn map(p: Parser(a), f: fn(a) -> b) -> Parser(b) {
  use res <- then(p)
  success(f(res))
}

/// Binds the specified function returning a parser over the result of a parser.
pub fn bind(p: Parser(a), fp: fn(a) -> Parser(b)) -> Parser(b) {
  use res <- then(p)
  fp(res)
}

/// A parser that parses a single character, and succeeds only if it matches the predicate.
pub fn check(pred: fn(String) -> Bool) -> Parser(String) {
  use char <- then(pchar())
  case pred(char) {
    True -> success(char)
    False -> failure()
  }
}

/// A parser that parses the specified character.
pub fn char(char: String) -> Parser(String) { check(fn(c) { c == char }) }

/// A parser that parses characters as long as a predicate matches, and converts it into a string.
pub fn string_check(pred: fn(String) -> Bool) -> Parser(String) {
  plus(check(pred)) |> map(string.concat)
}

/// A parser that parses the specified string.
pub fn string(str: String) -> Parser(String) {
  case string.pop_grapheme(str) {
    Error(_) -> success("")
    Ok(#(x, xs)) -> {
      use hd <- then(char(x))
      use tl <- then(string(xs))
      success(string.concat([hd, tl]))
    }
  }
}

/// A parser that combines two parsers, by trying the first one first, and only if it fails,
/// trying the second one on the same input.
pub fn alt(p1: Parser(a), p2: Parser(a)) -> Parser(a) {
  fn(input) {
    case p1(input) {
      Some(r) -> Some(r)
      None -> p2(input)
    }
  }
}

/// A parser that tries all parsers in the provided list in turn, returning the result of the first
/// one that succeeds, or failure if all fail.
pub fn one_of(ps: List(Parser(a))) -> Parser(a) {
  case ps {
    [] -> failure()
    [single] -> single
    [head, ..tail] -> alt(head, one_of(tail))
  }
}

/// Runs a parser zero or more times.
pub fn star(p: Parser(a)) -> Parser(List(a)) {
  let combined = {
    use elem <- then(p)
    use rest <- then(star(p))

    success([ elem, ..rest ])
  }

  alt(combined, success([]))
}

/// Runs a parser one or more times.
pub fn plus(p: Parser(a)) -> Parser(List(a)) {
  use fst <- then(p)
  use rest <- then(star(p))
  success([ fst, ..rest ])
}

/// Runs a parser exactly the specified number of times.
pub fn repeat(p: Parser(a), count: Int) -> Parser(List(a)) {
  case count {
    1 -> map(p, fn(x) { [ x ] })
    _ if count > 1 -> {
      use fst <- then(p)
      use rest <- then(repeat(p, count - 1))

      success([ fst, ..rest ])
    }
    _ -> success([])
  }
}

// ---------- Helpers ----------

/// Returns the UtfCodepoint for the specified character.
/// Will fail if more than one character is provided.
pub fn get_ucp(input: String) -> UtfCodepoint {
  let assert [ codepoint ] = string.to_utf_codepoints(input)
  codepoint
}

/// Converts a string ofa single character to an int representing this character's ascii value/utf8 codepoint.
/// Will fail if more than one character is provided.
pub fn char_to_int(input: String) -> Int {
  input |> get_ucp |> string.utf_codepoint_to_int
}

/// Indicates whether a character is a digit.
pub fn char_is_digit(char: String) -> Bool {
  let cint = char_to_int(char)
  cint <= char_to_int("9") && cint >= char_to_int("0")
}

/// A parser that prints the input string for debugging purposes.
pub fn debug(fail: Bool) -> Parser(Nil) {
  fn(input) {
    io.println("Debug: " <> string.concat(input))
    case fail { False -> Some(ParseSuccess(Nil, input)) True -> None }
  }
}

/// A helper to save a snapshot of the current parser state.
pub fn save_state(next: fn(List(String)) -> Parser(b)) -> Parser(b) {
  let p = fn(input) { Some(ParseSuccess(input, input)) }
  then(p, next)
}

/// A helper to restore a snapshot of a parser state before moving on to the next parser.
pub fn restore(state, next: fn() -> Parser(b)) -> Parser(b) {
  let p = fn(_) { Some(ParseSuccess(Nil, state)) }
  do(p, next)
}
