import gleam/string
import gleam/list
import gleam/option.{type Option, Some, None}

/// Shorthand for a function that parses a string to a value.
pub type Parser(a) = fn(String) -> ParseResult(a)

/// The parser state contains a parser result, and the remaining input string.
pub type ParseState(a) = #(a, String)

/// A parse result can either be failure, or success with a remaining parser state.
pub type ParseResult(a) {
  Failed
  Success(ParseState(a))
}

/// Converts an Option to a ParseResult.
pub fn from_option(option: Option(a), remaining: String) -> ParseResult(a) {
  case option {
    Some(st) -> Success(#(st, remaining))
    None -> Failed
  }
}

/// Converts a Result to a ParseResult.
pub fn from_result(option: Result(a, b), remaining: String) -> ParseResult(a) {
  case option {
    Ok(st) -> Success(#(st, remaining))
    Error(_) -> Failed
  }
}

/// Converts a ParseResult to an Option.
pub fn to_option(pr: ParseResult(a)) -> Option(a) {
  case pr {
    Success(x) -> Some(x.0)
    Failed -> None
  }
}

/// option.then for ParseResult.
pub fn then(result: ParseResult(a), apply fun: fn(ParseState(a)) -> ParseResult(b)) -> ParseResult(b) {
  case result {
    Failed -> Failed
    Success(result) -> fun(result)
  }
}

/// Applies the provided function over the parse result.
pub fn map(pr: ParseResult(a), f: fn(a) -> b) -> ParseResult(b) {
  use st <- then(pr)
  Success(#(f(st.0), st.1))
}

/// Applies the provided function returning an Option over the parse result.
/// Fails if the option is None.
pub fn bind(pr: ParseResult(a), f: fn(a) -> Option(b)) -> ParseResult(b) {
  use st <- then(pr)
  f(st.0) |> from_option(st.1)
}

/// option.when for ParseResult.
fn when(result: ParseResult(a), check: fn(a) -> Bool) -> ParseResult(a) {
  use st <- then(result)
  case check(st.0) {
    True -> Success(st)
    False -> Failed
  }
}

// ---------- Parsers ---------- 

/// A parser that succeeds if one character can be parsed, and the provided check on it succeeds.
pub fn pcheck(state: String, check: fn(UtfCodepoint) -> Bool) -> ParseResult(UtfCodepoint) {
  state |> string_head |> when(check)
}

/// Parses the specified character.
pub fn pchar(state: String, char: String) -> ParseResult(UtfCodepoint) {
  pcheck(state, fn(c) { c == get_ucp(char) })
}

// ---------- Combinators ---------- 

/// Checks a parse result that there is no more remaining input, and changes it to failure otherwise.
pub fn end(result: ParseResult(a)) -> ParseResult(a) {
  use state <- then(result)
  case string.is_empty(state.1) {
    True -> Success(state)
    False -> Failed 
  }
}

/// Tries the first parser first, and the second if it fails.
pub fn alt(state: String, first: Parser(a), second: Parser(a)) -> ParseResult(a) {
  case first(state) {
    Success(r) -> Success(r)
    Failed -> second(state)
  }
}

/// Applies the specified parser zero or more times, and returns the result as a list.
pub fn star(state: String, parser: Parser(b)) -> ParseResult(List(b)) {
  star_recurse([], state, parser, None)
}

/// Applies the specified parser one or more times, and returns the result as a list.
pub fn plus(state: String, parser: Parser(a)) -> ParseResult(List(a)) {
  use first <- then(parser(state))
  star_recurse([ first.0 ], first.1, parser, None)
}

/// Applies the specified parser exactly the specified number of times.
pub fn repeat(state: String, parser: Parser(a), length: Int) -> ParseResult(List(a)) {
  star_recurse([], state, parser, Some(length))
}

// ---------- Helpers ---------- 

/// Returtns the UtfCodepoint for the specified character.
/// Will fail if more than one character is provided.
pub fn get_ucp(input: String) -> UtfCodepoint {
  let assert [ codepoint ] = string.to_utf_codepoints(input)
  codepoint
}

/// Returns the first character from a string as a UtfCodepoint and the remaining string,
/// if is not empty. Returns None otherwise.
fn string_head(input: String) -> ParseResult(UtfCodepoint) {
  case string.to_utf_codepoints(input) {
    [head, ..tail] -> Success(#(head, string.from_utf_codepoints(tail)))
    _ -> Failed
  }
}

/// Indicates whether a character is a digit.
pub fn char_is_digit(char: UtfCodepoint) -> Bool {
  let cint = string.utf_codepoint_to_int(char)
  cint <= string.utf_codepoint_to_int(get_ucp("9")) && cint >= string.utf_codepoint_to_int(get_ucp("0"))
}

/// Recursion helper for star and plus.
fn star_recurse(acc: List(a), state: String, parser: Parser(a), target: Option(Int)) -> ParseResult(List(a)) {
  case parser(state) {
    Failed ->
      case target {
        Some(0) | None -> Success(#(list.reverse(acc), state))
        _ -> Failed
      }

    Success(new_state) -> {
      let res = [ new_state.0, ..acc ]
      case target {
        None -> star_recurse(res, new_state.1, parser, None)
        Some(1) -> Success(#(list.reverse(res), new_state.1))
        Some(t) -> star_recurse(res, new_state.1, parser, Some(t-1))
      }
    }
  }
}

