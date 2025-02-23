import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/order.{Gt, Lt}

import birl.{type Day}
import util/time.{type Time, Time}
import util/duration.{type Duration, Duration}

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

pub fn compare_day_event(a: DayEvent, b : DayEvent) -> order.Order {
  case a, b {
    ClockEvent(..), HolidayBooking(..) -> Lt
    HolidayBooking(..), ClockEvent(..) -> Gt
    ClockEvent(time: t1, ..), ClockEvent(time: t2, ..) -> time.compare(t1, t2)
    HolidayBooking(kind: Gain, ..), HolidayBooking(kind: Use, ..) -> Lt
    HolidayBooking(kind: Use, ..), HolidayBooking(kind: Gain, ..) -> Gt
    HolidayBooking(amount: a1, ..), HolidayBooking(amount: a2, ..) -> duration.compare(a1, a2)
  }
}

pub type DayStatistics {
  DayStatistics(
    eta: Duration,
    total: Duration, total_office: Duration, total_home: Duration,
    remaining_holiday: Duration)
}

pub type DayState {
  DayState(date: Day, target: Duration, lunch: Bool, events: List(DayEvent), stats: DayStatistics)
}


pub fn daystate_has_clock_event_at(ds: DayState, time: Time) {
  let is_ce_at = fn(ce: DayEvent) { case ce { ClockEvent(time: cet, ..) -> cet == time _ -> False } }
  ds.events |> list.any(is_ce_at)
}

pub fn daystate_has_clock_events(ds: DayState) {
  let is_ce = fn(ce) { case ce { ClockEvent(..) -> True _ -> False } }
  ds.events |> list.any(is_ce)
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
  LunchChanged(new_lunch: Bool)
  SelectListItem(index: Int)
  DeleteListItem(index: Int)
  ToggleHome(index: Int)
  AddClockEvent
  AddHolidayBooking(kind: HolidayBookingKind)
}

pub fn recalculate_events(events: List(DayEvent)) -> List(DayEvent) {
  let calc_kind = fn(i) { case i % 2 { 0 -> In _ -> Out } }

  let folder = fn(acc, event: DayEvent) {
    let #(gc, cc, acc) = acc
    case event {
      HolidayBooking(..) as h ->
        #(gc + 1, cc, [ HolidayBooking(..h, index: gc), ..acc ])
      ClockEvent(..) as c ->
        #(gc + 1, cc + 1, [ ClockEvent(..c, index: gc, kind: calc_kind(cc)), ..acc ])
    }
  }

  events
  // 1. Order events by -> Holiday, ClockEvent ; Time ascending.
  |> list.sort(compare_day_event)
  // 2. Odd clock events are in, even are out.
  |> list.fold(#(0, 0, []), folder)
  |> fn(x) { x.2 }
  |> list.reverse
}

pub fn recalculate_statistics(st: DayState) -> DayState {
  let add_hours = fn(stats: DayStatistics, location: ClockLocation, amount: Duration) {
    case location {
        Office -> DayStatistics(..stats,
            total: duration.add(stats.total, amount),
            total_office: duration.add(stats.total_office, amount))
        Home -> DayStatistics(..stats,
            total: duration.add(stats.total, amount),
            total_home: duration.add(stats.total_home, amount))
    }
  }

  let folder = fn(acc: #(DayStatistics, Option(#(ClockLocation, Time))), event: DayEvent) {
    case event {
      HolidayBooking(_, dur, Gain) ->
        #(DayStatistics(..acc.0, remaining_holiday: duration.add(acc.0.remaining_holiday, dur))
         , acc.1)
      HolidayBooking(_, dur, Use) ->
        #(DayStatistics(..acc.0, remaining_holiday: duration.subtract(acc.0.remaining_holiday, dur))
         , acc.1)

      // Here, we assume clock events are always alternating In and then Out, this should be true if before calling
      // this fuction, recalculate_events was called. Otherwise, we will fail.
      ClockEvent(_, time, loc, In) -> {
        let assert None = acc.1
        #(acc.0, Some(#(loc, time)))
      }
      ClockEvent(_, time, _, Out) -> {
        // Location can be ignored here. We will use the location of the clock-in event.
        let assert Some(state) = acc.1
        #(add_hours(acc.0, state.0, duration.between(from: state.1, to: time)), None)
      }
    }
  }

  // Determine the totals.
  let stats = DayStatistics(duration.zero(), duration.zero(), duration.zero(), duration.zero(), duration.zero())
  let stats = st.events |> list.fold(#(stats, None), folder)

  // Add the time between the last event and now, if the last event was an in-event.
  let stats = case stats.1, time.today() == st.date {
    Some(state), True ->
      add_hours(stats.0, state.0, duration.between(from: state.1, to: time.now()))
    _, _ -> stats.0
  }

  // If we had lunch, add half an hour to the target, but only if there are any bookings this day.
  let actual_target = case st.lunch, daystate_has_clock_events(st) {
    True, True -> duration.add(st.target, Duration(0, 30, None))
    _, _ -> st.target
  }

  let stats = DayStatistics(..stats, eta: duration.subtract(actual_target, stats.total))

  DayState(..st, stats: stats)
}
