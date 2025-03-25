import gleam/list
import gleam/option.{type Option, Some}
import gleam/string

import model.{
  type DayEvent, type DayState, ClockEvent, DayState, Gain, HolidayBooking, Home,
  In, Office, Use,
}
import util/day
import util/duration.{type Duration}
import util/parser.{type Parser} as p
import util/parsers
import util/prim

/// Parsed data for constructing the state.
pub type StateInput {
  StateInput(
    week_target: Duration,
    travel_distance: Float,
    history: List(DayState),
  )
}

/// A parser for the letter that indicates whether lunch is enabled this day.
fn lunch_parser() -> Parser(Bool) {
  use ch <- p.then(p.alt(p.char("L"), p.char("N")))

  case ch {
    "L" -> True
    "N" -> False
    _ -> panic as "Should always be L or N"
  }
  |> p.success
}

fn day_event_parser() -> Parser(DayEvent) {
  use dur <- p.then(duration.int_parser())
  use typ <- p.then(p.pchar())

  // Return the right type of day event. Note that clock events need a time,
  // so they can only be returned if the duration is not longer than a time can be.
  case typ {
    "O" -> {
      use time <- p.then(duration.to_time(dur) |> p.from_option)
      p.success(ClockEvent(0, time, Office, In))
    }
    "H" -> {
      use time <- p.then(duration.to_time(dur) |> p.from_option)
      p.success(ClockEvent(0, time, Home, In))
    }
    "v" -> p.success(HolidayBooking(0, dur, Gain))
    "V" -> p.success(HolidayBooking(0, dur, Use))
    _ -> p.failure()
  }
}

/// A parser for a DayState.
fn day_state_parser() -> Parser(DayState) {
  use date <- p.then(day.int_parser())
  use target <- p.then(duration.int_parser())
  use lunch <- p.then(lunch_parser())
  use events <- p.then(p.star(day_event_parser()))
  p.success(DayState(date: date, target: target, lunch: lunch, events: events))
}

fn parse_line(acc: Option(StateInput), line: String) -> Option(StateInput) {
  use <- prim.check(acc, !{ string.is_empty(line) })
  // Skip empty lines.
  use si <- option.then(acc)

  let parser = {
    use checkpoint <- p.save_state()
    use ch <- p.then(p.pchar())
    case ch {
      // Try to parse the week target.
      "W" -> {
        use dur <- p.then(duration.int_parser())
        use <- p.do(p.end())
        p.success(StateInput(..si, week_target: dur))
      }

      // Try to parse the travel distance.
      "T" -> {
        use d <- p.then(parsers.pos_float())
        use <- p.do(p.end())
        p.success(StateInput(..si, travel_distance: d))
      }

      // Otherwise try to parse a day state.
      _ -> {
        use <- p.restore(checkpoint)
        use st <- p.then(day_state_parser())
        use <- p.do(p.end())
        p.success(StateInput(..si, history: [st, ..si.history]))
      }
    }
  }

  p.run(parser, line)
}

pub fn parse_state_input(input: String) -> Option(StateInput) {
  input
  // Split in lines.
  |> string.replace("\r", "")
  |> string.split("\n")
  // Parse input (history will be reversed).
  |> list.fold(Some(StateInput(duration.zero(), 0.0, [])), parse_line)
}
