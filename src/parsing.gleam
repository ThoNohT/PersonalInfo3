import gleam/int
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/string

import birl.{type Day, Day}

import util/numbers.{Pos}
import util/duration.{type Duration, Duration}
import model.{
  type DayState, DayState,
  type DayEvent, ClockEvent, HolidayBooking,
  In, Home, Office, Gain, Use}

/// Returns the first character from a string as a UtfCodepoint and the remaining string,
/// if is not empty. Returns None otherwise.
fn string_head(input: String) -> ParseResult(UtfCodepoint) {
  case string.to_utf_codepoints(input) {
    [head, ..tail] -> Success(#(head, string.from_utf_codepoints(tail)))
    _ -> Failed
  }
}

/// Returtns the UtfCodepoint for the specified character.
/// Will fail if more than one character is provided.
fn get_ucp(input: String) -> UtfCodepoint {
  let assert [ codepoint ] = string.to_utf_codepoints(input)
  codepoint
}

/// Indicates whether a character is a digit.
fn char_is_digit(char: UtfCodepoint) -> Bool {
  let cint = string.utf_codepoint_to_int(char)
  cint <= string.utf_codepoint_to_int(get_ucp("9")) && cint >= string.utf_codepoint_to_int(get_ucp("0"))
}

/// Parsed data for constructhing the state.
pub type StateInput {
  StateInput(week_target: Duration, travel_distance: Float, history: List(DayState))
}

/// Shorthand for a function that parses a string to a value.
type Parser(a) = fn(String) -> ParseResult(a)

/// The parser state contains a parser result, and the remaining input string.
type ParseState(a) = #(a, String)

/// A parse result can either be failure, or success with a remaining parser state.
type ParseResult(a) {
  Failed
  Success(ParseState(a))
}

/// Converts an Option to a ParseResult.
fn pr_from_option(option: Option(a), remaining: String) -> ParseResult(a) {
  case option {
    Some(st) -> Success(#(st, remaining))
    None -> Failed
  }
}

/// Converts a Result to a ParseResult.
fn pr_from_result(option: Result(a, b), remaining: String) -> ParseResult(a) {
  case option {
    Ok(st) -> Success(#(st, remaining))
    Error(_) -> Failed
  }
}

/// Converts a ParseResult to an Option.
fn pr_to_option(pr: ParseResult(a)) -> Option(a) {
  case pr {
    Success(x) -> Some(x.0)
    Failed -> None
  }
}

/// option.when for ParseResult.
fn pr_when(result: ParseResult(a), check: fn(a) -> Bool) -> ParseResult(a) {
  use st <- pr_then(result)
  case check(st.0) {
    True -> Success(st)
    False -> Failed
  }
}

/// option.then for ParseResult.
fn pr_then(result: ParseResult(a), apply fun: fn(ParseState(a)) -> ParseResult(b)) -> ParseResult(b) {
  case result {
    Failed -> Failed
    Success(result) -> fun(result)
  }
}

/// Parses the specified character.
fn pchar(state: String, char: String) -> ParseResult(UtfCodepoint) {
  pcheck(state, fn(c) { c == get_ucp(char) })
}

/// A parser that succeeds if one character can be parsed, and the provided check on it succeeds.
fn pcheck(state: String, check: fn(UtfCodepoint) -> Bool) -> ParseResult(UtfCodepoint) {
  state |> string_head |> pr_when(check)
}

/// Checks a parse result that there is no more remaining input, and changes it to failure otherwise.
fn end(result: ParseResult(a)) -> ParseResult(a) {
  use state <- pr_then(result)
  case string.is_empty(state.1) {
    True -> Success(state)
    False -> Failed 
  }
}

/// Tries the first parser first, and the second if it fails.
fn alt(state: String, first: Parser(a), second: Parser(a)) -> ParseResult(a) {
  case first(state) {
    Success(r) -> Success(r)
    Failed -> second(state)
  }
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

/// Applies the specified parser zero or more times, and returns the result as a list.
fn star(state: String, parser: Parser(b)) -> ParseResult(List(b)) {
  star_recurse([], state, parser, None)
}

/// Applies the specified parser one or more times, and returns the result as a list.
fn plus(state: String, parser: Parser(a)) -> ParseResult(List(a)) {
  use first <- pr_then(parser(state))
  star_recurse([ first.0 ], first.1, parser, None)
}

/// Applies the specified parser exactly the specified number of times.
fn repeat(state: String, parser: Parser(a), length: Int) -> ParseResult(List(a)) {
  star_recurse([], state, parser, Some(length))
}

/// Applies the provided function returning an Option over the parse result.
/// Fails if the option is None.
fn pr_bind(pr: ParseResult(a), f: fn(a) -> Option(b)) -> ParseResult(b) {
  use st <- pr_then(pr)
  f(st.0) |> pr_from_option(st.1)
}

/// Applies the provided function over the parse result.
fn pr_map(pr: ParseResult(a), f: fn(a) -> b) -> ParseResult(b) {
  use st <- pr_then(pr)
  Success(ps_map(st, f))
}

/// Applies the provided function over the parse state.
fn ps_map(pr: ParseState(a), f: fn(a) -> b) -> ParseState(b) {
  #(f(pr.0), pr.1)
}

/// Parses a positive Int.
fn parse_pos_int(input: String) -> ParseResult(Int) {
  use int_str <- pr_then(plus(input, pcheck(_, char_is_digit)) |> pr_map(string.from_utf_codepoints))
  int.parse(int_str.0) |> pr_from_result(int_str.1)
}

/// Parses a Duration, where the last 2 digits are the minutes, and everything before the hours.
fn parse_duration(input: String) -> ParseResult(Duration) {
  parse_pos_int(input)
  |> pr_map(fn(nr) { Duration(nr / 100, nr % 100, Pos, None) })
}

/// Parses a Float, where the decimal separator is a ".".
fn parse_float(input: String) -> ParseResult(Float) {
  use int_part <- pr_then(parse_pos_int(input) |> pr_map(int.to_float))
  case pchar(int_part.1, ".") {
    Failed -> Success(int_part)
    Success(_) -> parse_pos_int(input) |> pr_map(fn(d) { int_part.0 +. numbers.decimalify(d) })
  }
}

/// Parses a Day.
fn parse_date(input: String) -> ParseResult(Day) {
  use year <- pr_then(
    repeat(input, pcheck(_, char_is_digit), 4) 
    |> pr_map(string.from_utf_codepoints)
    |> pr_bind(fn(x) { int.parse(x) |> option.from_result })
  )
  use month <- pr_then(
    repeat(year.1, pcheck(_, char_is_digit), 2)
    |> pr_map(string.from_utf_codepoints)
    |> pr_bind(fn(x) { int.parse(x) |> option.from_result })
  )
  use day <- pr_then(
    repeat(month.1, pcheck(_, char_is_digit), 2)
    |> pr_map(string.from_utf_codepoints)
    |> pr_bind(fn(x) { int.parse(x) |> option.from_result })
    )

  let res = Success(#(Day(year.0, month.0, day.0), day.1))
  res
}

/// Parses the letter that indicates whether lunch is enabled this day.
fn parse_lunch(input: String) -> ParseResult(Bool) {
  alt(input, pchar(_, "L"), pchar(_, "N")) 
  |> pr_map(fn(l) {
    case string.from_utf_codepoints([ l ]) {
      "L" -> True 
      "N" -> False
      _ -> panic as "Should always be L or N" 
    }
  })
}

fn parse_day_event(input: String) -> ParseResult(DayEvent) {
  use dur <- pr_then(parse_duration(input))
  use typ <- pr_then(pcheck(dur.1, fn(_) { True }))

  // Return the right type of day event. Note that clock events need a time,
  // so they can only be returned if the duration is not longer than a time can be.
  case string.from_utf_codepoints([ typ.0 ]) {
    "O" -> {
      use time <- pr_then(duration.to_time(dur.0) |> pr_from_option(typ.1))
      Success(#(ClockEvent(0, time.0, Office, In), typ.1))
    }
    "H" -> {
      use time <- pr_then(duration.to_time(dur.0) |> pr_from_option(typ.1))
      Success(#(ClockEvent(0, time.0, Home, In), typ.1))
    }
    "v" -> Success(#(HolidayBooking(0, dur.0, Gain), typ.1))
    "V" -> Success(#(HolidayBooking(0, dur.0, Use), typ.1))
    _ -> Failed
  }
}

/// Parses a DayState.
fn parse_day_state(input: String) -> ParseResult(DayState) {
  use date <- pr_then(parse_date(input))
  use target <- pr_then(parse_duration(date.1))
  use lunch <- pr_then (parse_lunch(target.1))
  use events <- pr_then(star(lunch.1, parse_day_event))
  Success(#(DayState(date: date.0, target: target.0, lunch: lunch.0, events: events.0), events.1))
}

fn parse_line(acc: ParseResult(StateInput), line: String) -> ParseResult(StateInput) {
  use si <- pr_then(acc)

  case string.pop_grapheme(line) {
    // Try to parse the week target.
    Ok(#("W", rest)) ->
      parse_duration(rest) |> end 
      |> pr_map(fn(t) { StateInput(..si.0, week_target: t) })

    // Try to parse the travel distance.
    Ok(#("T", rest)) ->
      parse_float(rest) |> end
      |> pr_map(fn(d) { StateInput(..si.0, travel_distance: d) })

    Error(_) -> Success(si) // Empty line, let's ignore it.

    // Otherwise try to parse a day state.
    _ ->
      parse_day_state(line) |> end
      |> pr_map(fn(d) { StateInput(..si.0, history: [ d, ..si.0.history ]) })
  }
}

pub fn parse_state_input(input: String) -> Option(StateInput) {
  let init = #(StateInput(duration.zero(), 0.0, []), "")
  input
    |> string.replace("\r", "") |> string.split("\n") // Split in lines.
    |> list.fold(Success(init), parse_line) // Parse input (history will be reversed).
    |> pr_map(fn(st) { StateInput(..st, history: list.reverse(st.history)) }) // Reverse history.
    |> pr_to_option
}
