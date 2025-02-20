import gleam/list
import gleam/option.{type Option, None}

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

pub fn unvalidated() -> Validated(a) { Validated("", None) }

pub type ClockLocation { Home Office }

pub fn switch_location(location) {
  case location {
    Home -> Office
    Office -> Home
  }
}

pub type ClockKind { In Out }

pub type HolidayBookingKind { Gain Use }

pub type DayEvent {
  ClockEvent(index: Int, time: Time, location: ClockLocation, kind: ClockKind)
  HolidayBooking(index: Int, amount: Duration, kind: HolidayBookingKind)
}

pub type DayState {
  DayState(date: Day, target: Duration, events: List(DayEvent))
}

pub fn daystate_has_clock_event_at(ds: DayState, time: Time) {
  let is_ce_at = fn(ce: DayEvent) {
    case ce { ClockEvent(time: cet, ..) -> cet == time _ -> False }
  }

  ds.events |> list.any(is_ce_at)
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
  Loaded(
    today: Day,
    current_state: DayState,
    selected_event: Option(DayEvent),
    week_target: Duration,
    input_state: InputState)
}


pub type Msg {
  LoadState
  TimeInputChanged(new_time: String)
  HolidayInputChanged(new_duration: String)
  TargetChanged(new_target: String)
  SelectListItem(index: Int)
  DeleteListItem(index: Int)
  ToggleHome(index: Int)
  AddClockEvent
  AddHolidayBooking(kind: HolidayBookingKind)
}

pub fn recalculate_events(events: List(DayEvent)) -> List(DayEvent) {
  events |> list.index_map(fn(e, i) {
    case e {
      ClockEvent(..) as c -> ClockEvent(..c, index: i)
      HolidayBooking(..) as h -> HolidayBooking(..h, index: i)
    }
  })
}
