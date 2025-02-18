import gleam/option.{type Option}

import birl.{type Day}
import util/time.{type Time, Time, type Duration, Duration}

pub type Validated(a) {
  Validated(input: String, parsed: Option(a))
}

/// Checks whether a Validated(a) is valid.
pub fn is_valid(input: Validated(a)) -> Bool { input.parsed |> option.is_some }

/// Creates a new Validated(a) from an input strig using a validation function.
pub fn validate(input: String, with validation: fn(String) -> Option(a)) -> Validated(a) {
  Validated(input, validation(input))
}

pub type DayEvent {
  ClockEvent(time: Time, home: Bool, in: Bool)
  HolidayBooking(amount: Float)
}

pub type DayState {
  DayState(date: Day, target: Duration, events: List(DayEvent))
}

pub type InputState {
  InputState(
    clock_input: Validated(Time),
    holiday_input: Validated(Duration),
    target_input: Validated(Duration)
  )
}

pub type State {
  Loading
  Loaded(today: Day, current_state: DayState, week_target: Float, input_state: InputState)
}

pub type Msg {
  LoadState
  TimeInputChanged(new_time: String)
  HolidayInputChanged(new_duration: String)
  TargetChanged(new_target: String)
}
