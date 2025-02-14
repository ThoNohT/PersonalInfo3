import gleam/int
import gleam/option.{type Option, Some, None}
import gleam/string

import birl.{type TimeOfDay, TimeOfDay, type Day}

pub type DayEvent {
  ClockEvent(time: TimeOfDay, home: Bool, in: Bool)
  HolidayBooking(amount: Float)
}

pub type DayState {
  DayState(date: Day, target: Float, events: List(DayEvent))
}

pub type InputState {
  InputState(time_input: String, parsed_time: Option(TimeOfDay))
}

pub type State {
  Loading
  Loaded(today: Day, current_state: DayState, week_target: Float, input_state: InputState)
}

pub type Msg {
  LoadState
  TimeChanged(new_time: String)
}


fn option_when(opt: Option(a), when: fn(a) -> Bool) -> Option(a) {
  use val <- option.then(opt)
  case when(val) { True -> Some(val) False -> None }
}

/// Validates a string for a time of day.
///
/// Valid representations are:
/// 1     -> 01:00
/// 12    -> 12:00
/// 123   -> 1:23
/// 1234  -> 12:34
/// 1:2   -> 01:02
/// 12:3  -> 12:03
/// 1:23  -> 01:23
/// 12:34 -> 12:34
///
/// Note that values that are recognized above but represent invalid times are not valid, for example:
/// 25 -> Would be 25:00
/// 261 -> Would be 02:61
/// 2500 -> Would be 24:00
/// 1261 -> Would be 12:61
/// a:b where a > 23 or b > 59 would naturally represent invalid times.
pub fn validate_time(time: String) -> Option(TimeOfDay) {
  // Parse a positive int.
  let parse_pos_int = fn(str) {
      int.base_parse(str, 10) 
      |> option.from_result 
      |> option_when(fn(x) { x >= 0})
  }

  let parse_split_time = fn(hour: String, minute: String) {
    use int_hr <- option.then(parse_pos_int(hour))
    use int_min <- option.then(parse_pos_int(minute))

    case int_hr, int_min {
      h, m if h >= 0 && h < 24 && m >= 0 && m < 60 -> TimeOfDay(h, m, 0, 0) |> Some
      _, _ -> None
    }
  }

  let parse_unsplit_time = fn(time: String) {
    use int_val <- option.then(parse_pos_int(time))

    case string.length(time) {
      0 -> None
      1 -> TimeOfDay(int_val, 0, 0, 0) |> Some
      2 if int_val < 24 -> TimeOfDay(int_val, 0, 0, 0) |> Some
      3 if int_val % 100 < 60 -> TimeOfDay(int_val / 100, int_val % 100, 0, 0) |> Some
      4 if int_val % 100 < 60 && int_val / 100 < 24 -> TimeOfDay(int_val / 100, int_val % 100, 0, 0) |> Some
      _ -> None
    }
  }

  case string.split(time, ":") {
    [hr, min] -> parse_split_time(hr, min)
    [time] -> parse_unsplit_time(time)
    _ -> None
  }
}

