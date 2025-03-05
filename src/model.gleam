import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/order.{Gt, Lt, Eq}

import birl.{type Day, Day}
import lustre_http as http

import util/prim
import util/time.{type Time, Time}
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

/// The different amounts that can be moved through the history.
pub type DateMoveAmount { MoveDay MoveWeek MoveMonth MoveYear ToToday }

/// Moves the day by the specified amount, but keeping it between the provided min and max(today) day.
pub fn move_date(day: Day, amount: DateMoveAmount, direction: MoveDirection, min: Day, today: Day) -> Day {
  // If we are at the min edge, we will always move by one bakward. Otherwise, always cap it between min and max.
  use _ <- prim.check(day.prev(day), !{ direction == Backward && day == min })

  let move_week = fn(d: Day, dir: MoveDirection) {
    let weekday = day.weekday(d) |> day.weekday_to_int

    case dir, weekday {
      Backward, 0 -> day.add_days(d, -7)
      Forward, 0 -> day.add_days(d, 7)
      Backward, _ -> day.add_days(d, -1 * weekday)
      Forward, _ -> day.add_days(d, 7 - weekday)
    }
  }

  let move_month = fn(d: Day, dir: MoveDirection) -> Day {
    case dir {
      Forward -> {
        let ym = case d.month + 1 {
          m if m > 12 -> #(d.year + 1, 1)
          m -> #(d.year, m)
        }
        Day(ym.0, ym.1, 1)
      }

      Backward if d.date > 1 -> Day(d.year, d.month, 1)
      Backward -> {
        let ym = case d.month - 1 {
          m if m < 1 -> #(d.year - 1, 12)
          m -> #(d.year, m)
        }
        Day(ym.0, ym.1, 1)
      }
    }
  }

  let move_year = fn(d: Day, dir: MoveDirection) -> Day {
    case dir {
      Backward if d.month > 1 || d.date > 1 -> Day(d.year, 1, 1)
      Backward -> Day(d.year - 1, 1, 1)
      Forward -> Day(d.year + 1, 1, 1)
    }
  }

  case amount, direction {
    MoveDay, Backward -> day.prev(day)
    MoveDay, Forward -> day.next(day)
    MoveWeek, _ -> move_week(day, direction)
    MoveMonth, _ -> move_month(day, direction)
    MoveYear, _ -> move_year(day, direction)
    ToToday, _ -> today
  } |> day.clamp(min, today)
}


/// The different amounts that can be moved through time/durations.
pub type TimeMoveAmount { MoveMinute MoveQuarter MoveStartQuarter MoveHour MoveStartHour ToNow }

/// The directions in which can be moved through time.
pub type MoveDirection { Forward Backward }

pub type Msg {
  NoOp
  LoadState(Result(String, http.HttpError))
  Tick
  TimeInputChanged(new_time: String)
  TimeInputKeyDown(amount: TimeMoveAmount, dir: MoveDirection)
  HolidayInputChanged(new_duration: String)
  HolidayInputKeyDown(amount: TimeMoveAmount, dir: MoveDirection)
  TargetChanged(new_target: String)
  TargetKeyDown(amount: TimeMoveAmount, dir: MoveDirection)
  LunchChanged(new_lunch: Bool)
  SelectListItem(index: Int)
  DeleteListItem(index: Int)
  ToggleHome(index: Int)
  AddClockEvent
  AddHolidayBooking(kind: HolidayBookingKind)
  ChangeDay(amount: DateMoveAmount, dir: MoveDirection)
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

  let add_week = fn(stats: DayStatistics, amount: Duration) {
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

/// Adds a new DayState at the specified day in the state history.
pub fn add_day_state(state: State, day: Day) -> State {
  let lunch = case day.weekday(day) { birl.Sat | birl.Sun -> False _ -> True }
  let target = case day.weekday(day) { birl.Sat | birl.Sun -> duration.zero() _ -> duration.hours(8) }
  let current_state = DayState(date: day, target:, lunch:, events: [])

  let folder = fn(acc: #(List(DayState), Option(DayState)), state: DayState) -> #(List(DayState), Option(DayState)) {
    case acc.1, day.compare(day, state.date) {
      Some(_), _ -> #([state, ..acc.0], acc.1)
      None, Eq -> #([state, ..acc.0], Some(state))
      None, Gt -> #([state, ..acc.0], acc.1)
      // The first time the day is smaller than the history entry, prepend it.
      None, Lt -> #([state, current_state, ..acc.0], Some(current_state))
    }
  }

  let result = state.history |> list.fold(#([], None), folder)
  State(..state, current_state: result.1 |> option.unwrap(current_state), history: result.0)
}

/// Calculates the new time based on a move amount and direction, and the current time input.
pub fn calculate_target_time(current: Option(Time), amount: TimeMoveAmount, dir: MoveDirection, now: Time) -> Option(Time) {
  use _ <- prim.check(Some(now), amount != ToNow)
  use current <- option.then(current)

  case amount, dir {
   MoveMinute, Forward -> time.add_minutes(current, 1)
   MoveMinute, Backward -> time.add_minutes(current, -1)
   MoveQuarter, Forward -> time.add_minutes(current, 15)
   MoveQuarter, Backward -> time.add_minutes(current, -15)
   MoveStartQuarter, Forward -> time.add_minutes_to(current, 15)
   MoveStartQuarter, Backward -> time.add_minutes_to(current, -15)
   MoveHour, Forward -> time.add_minutes(current, 60)
   MoveHour, Backward -> time.add_minutes(current, -60)
   MoveStartHour, Forward -> time.add_minutes_to(current, 60)
   MoveStartHour, Backward -> time.add_minutes_to(current, -60)
   ToNow, _ -> now // This is already handled above, but we need to cover all cases anyway.
  } |> Some
}

/// Calculates the new duration based on a move amount and direction, and the current duration input.
pub fn calculate_target_duration(current: Option(Duration), amount: TimeMoveAmount, dir: MoveDirection, max: Int) -> Option(Duration) {
  use current <- option.then(current)

  case amount, dir {
   MoveMinute, Forward -> duration.add_minutes(current, 1, max)
   MoveMinute, Backward -> duration.add_minutes(current, -1, max)
   MoveQuarter, Forward -> duration.add_minutes(current, 15, max)
   MoveQuarter, Backward -> duration.add_minutes(current, -15, max)
   MoveStartQuarter, Forward -> duration.add_minutes_to(current, 15, max)
   MoveStartQuarter, Backward -> duration.add_minutes_to(current, -15, max)
   MoveHour, Forward -> duration.add_minutes(current, 60, max)
   MoveHour, Backward -> duration.add_minutes(current, -60, max)
   MoveStartHour, Forward -> duration.add_minutes_to(current, 60, max)
   MoveStartHour, Backward -> duration.add_minutes_to(current, -60, max)
   ToNow, _ -> current // This should never happen, it doesn't do anything anyway.
  } |> Some
}
