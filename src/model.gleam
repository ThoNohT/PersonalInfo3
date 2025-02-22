import gleam/list
import gleam/option.{type Option, None}
import gleam/order.{Gt, Lt}

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
  // 1. Order events by -> Holiday, ClockEvent ; Time ascending.
  // 2. Odd clock events are in, even are out.

  let compare_event = fn(a: DayEvent, b : DayEvent) {
    case a, b {
      ClockEvent(..), HolidayBooking(..) -> Gt
      HolidayBooking(..), ClockEvent(..) -> Lt
      ClockEvent(time: t1, ..), ClockEvent(time: t2, ..) -> time.compare_time(t1, t2)
      HolidayBooking(kind: Gain, ..), HolidayBooking(kind: Use, ..) -> Lt
      HolidayBooking(kind: Use, ..), HolidayBooking(kind: Gain, ..) -> Gt
      HolidayBooking(amount: a1, ..), HolidayBooking(amount: a2, ..) -> time.compare_duration(a1, a2)
    }
  }

  let calc_kind = fn(i) { case i % 2 { 0 -> In _ -> Out } }

  let folder = fn(acc, elem: DayEvent) {
    let #(gc, cc, acc) = acc
    case elem {
      HolidayBooking(..) as h ->
        #(gc + 1, cc, [ HolidayBooking(..h, index: gc), ..acc ])
      ClockEvent(..) as c ->
        #(gc + 1, cc + 1, [ ClockEvent(..c, index: gc, kind: calc_kind(cc)), ..acc ])
    }
  }

  events
  |> list.sort(compare_event)
  |> list.fold(#(0, 0, []), folder)
  |> fn(x) { x.2 }
  |> list.reverse
}
