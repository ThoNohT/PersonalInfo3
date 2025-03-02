import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/order.{Gt, Lt}

import birl.{type Day}
import lustre_http as http

import util/prim
import util/time.{type Time, Time}
import util/event as uev
import util/day
import util/numbers.{Pos}
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
    week: Duration, week_eta: Duration,
    remaining_holiday: Duration)
}

pub fn stats_zero() -> DayStatistics {
  DayStatistics(duration.zero(), duration.zero(), duration.zero(), duration.zero(), duration.zero(), duration.zero(), duration.zero())
}

pub type DayState {
  DayState(date: Day, target: Duration, lunch: Bool, events: List(DayEvent))
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

pub type Model {
  Loading
  Err(String)
  Loaded(state: State)
}

pub type State {
  State(
    today: Day,
    now: Time,
    history: List(DayState),
    current_state: DayState,
    stats: DayStatistics,
    selected_event_index: Option(Int),
    week_target: Duration,
    travel_distance: Float,
    input_state: InputState)
}

pub type Msg {
  LoadState(Result(String, http.HttpError))
  Tick
  TimeInputChanged(new_time: String)
  HolidayInputChanged(new_duration: String)
  TargetChanged(new_target: String)
  LunchChanged(new_lunch: Bool)
  SelectListItem(index: Int)
  DeleteListItem(index: Int)
  ToggleHome(index: Int)
  AddClockEvent
  AddHolidayBooking(kind: HolidayBookingKind)
  PrevDay(modifiers: uev.ModifierState)
  NextDay(modifiers: uev.ModifierState)
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

pub fn update_history(state: State) -> State {
  let update = fn(ds: DayState) {
     case state.current_state.date == ds.date {
       False -> ds
       True -> state.current_state
     }
  }

  State(..state, history: state.history |> list.map(update))
}

pub fn recalculate_statistics(state: State) -> State {
  let st = state.current_state
  let hist = state.history

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

  let add_week =fn(stats: DayStatistics, amount: Duration) { 
    DayStatistics(..stats, week: duration.add(stats.week, amount))
  }
  
  let folder = fn(acc: #(DayStatistics, Option(#(ClockLocation, Time))), event: #(DayEvent, Day)) {
    let curr_day = event.1 == st.date
    let this_week = day.week_number(event.1) == day.week_number(st.date)

    case event.0 {
      HolidayBooking(_, dur, Gain) ->
        #(DayStatistics(..acc.0, remaining_holiday: duration.add(acc.0.remaining_holiday, dur)), acc.1)
      HolidayBooking(_, dur, Use) ->
        #(DayStatistics(..acc.0, remaining_holiday: duration.subtract(acc.0.remaining_holiday, dur)), acc.1)

      ClockEvent(_, time, loc, In) -> {
        use _ <- prim.check(acc, this_week)
        #(acc.0, Some(#(loc, time)))
      }

      ClockEvent(_, time, _, Out) -> {
        // Location can be ignored here. We will use the location of the clock-in event.
        use _ <- prim.check(acc, this_week)
        let assert Some(state) = acc.1
        let acc = #(add_week(acc.0, duration.between(from: state.1, to: time)), acc.1)
        use _ <- prim.check(acc, curr_day)
        #(add_hours(acc.0, state.0, duration.between(from: state.1, to: time)), None)
      }
    }
  }

  // Calculate all totals.
  let stats = hist
    |> list.filter(fn(s) { day.compare(s.date, st.date) != Gt })
    |> list.map(fn(s) { s.events |> recalculate_events |> list.map(fn(e) { #(e, s.date) }) }) |> list.flatten
    |> list.fold(#(stats_zero(), None), folder)

  // Add the time between the last event and now, if the last event was an in-event.
  let stats = case stats.1, state.today == st.date {
    Some(s), True -> {
      stats.0
      |> add_hours(s.0, duration.between(from: s.1, to: state.now))
      |> add_week(duration.between(from: s.1, to: state.now))
    }
    _, _ -> stats.0
  }

  let stats = DayStatistics(..stats, week_eta: duration.subtract(state.week_target, stats.week))

  // If lunch is included, assume half an hour of clocked time doesn't exist. Take it from the longest period
  // of office or home, but prefer office if this cannot be determined. If no clock events, then don't
  // take any lunch away, since we didn't work at all.
  let stats = case st.lunch, daystate_has_clock_events(st) {
    True, True -> {
      let half_hour = Duration(0, 30, Pos, None)
      case duration.compare(stats.total_office, stats.total_home) {
        Lt -> DayStatistics(..stats,
          total: duration.subtract(stats.total, half_hour),
          total_home: duration.subtract(stats.total_home, half_hour))
        _ -> DayStatistics(..stats,
          total: duration.subtract(stats.total, half_hour),
          total_office: duration.subtract(stats.total_office, half_hour))
      }
    }
    _, _ -> stats
  }

  State(..state, stats: DayStatistics(..stats, eta: duration.subtract(st.target, stats.total)))
}

