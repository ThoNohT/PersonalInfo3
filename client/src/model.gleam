import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/string_tree

import birl.{type Day, Day}
import lustre_http as http

import shared_model.{type Credentials, type SessionInfo}
import util/day
import util/duration.{type Duration}
import util/numbers.{Pos}
import util/prim
import util/time.{type Time, Time}

pub type Validated(a) {
  Validated(input: String, parsed: Option(a))
}

/// Checks whether a Validated(a) is valid.
pub fn is_valid(input: Validated(a)) -> Bool {
  input.parsed |> option.is_some
}

/// Creates a new Validated(a) from an input strig using a validation function.
pub fn validate(
  input: String,
  with validation: fn(String) -> Option(a),
) -> Validated(a) {
  Validated(input, validation(input))
}

pub fn unvalidated() -> Validated(a) {
  Validated("", None)
}

pub type ClockLocation {
  Home
  Office
}

pub fn switch_location(location) {
  case location {
    Home -> Office
    Office -> Home
  }
}

pub type ClockKind {
  In
  Out
}

pub type HolidayBookingKind {
  Gain
  Use
}

pub type DayEvent {
  ClockEvent(index: Int, time: Time, location: ClockLocation, kind: ClockKind)
  HolidayBooking(index: Int, amount: Duration, kind: HolidayBookingKind)
}

pub fn compare_day_event(a: DayEvent, b: DayEvent) -> order.Order {
  case a, b {
    ClockEvent(..), HolidayBooking(..) -> Lt
    HolidayBooking(..), ClockEvent(..) -> Gt
    ClockEvent(time: t1, ..), ClockEvent(time: t2, ..) -> time.compare(t1, t2)
    HolidayBooking(kind: Gain, ..), HolidayBooking(kind: Use, ..) -> Lt
    HolidayBooking(kind: Use, ..), HolidayBooking(kind: Gain, ..) -> Gt
    HolidayBooking(amount: a1, ..), HolidayBooking(amount: a2, ..) ->
      duration.compare(a1, a2)
  }
}

pub type DayState {
  DayState(date: Day, target: Duration, lunch: Bool, events: List(DayEvent))
}

pub fn daystate_has_clock_event_at(ds: DayState, time: Time) {
  let is_ce_at = fn(ce: DayEvent) {
    case ce {
      ClockEvent(time: cet, ..) -> cet == time
      _ -> False
    }
  }
  ds.events |> list.any(is_ce_at)
}

pub fn daystate_has_clock_events(ds: DayState) {
  let is_ce = fn(ce) {
    case ce {
      ClockEvent(..) -> True
      _ -> False
    }
  }
  ds.events |> list.any(is_ce)
}

pub type InputState {
  InputState(
    clock_input: Validated(Time),
    holiday_input: Validated(Duration),
    target_input: Validated(Duration),
  )
}

pub type SettingsState {
  SettingsState(
    week_target_input: Validated(Duration),
    travel_distance_input: Validated(Float),
  )
}

pub type LoginModel {
  LoginModel(credentials: Credentials, failed: Bool)
}

pub type SettingsModel {
  SettingsModel(state: State, settings: SettingsState)
}

pub type Model {
  Login(model: LoginModel)
  Loading(session: SessionInfo)
  WeekOverview(state: State, stats: WeekStatistics)
  HolidayOverview(state: State)
  Err(String)
  Booking(state: State)
  Settings(model: SettingsModel)
}

pub type State {
  State(
    session: SessionInfo,
    today: Day,
    now: Time,
    history: List(DayState),
    current_state: DayState,
    stats: Statistics,
    selected_event_index: Option(Int),
    week_target: Duration,
    travel_distance: Float,
    input_state: InputState,
  )
}

pub type DayStatistics {
  DayStatistics(
    day: Day,
    eta: Duration,
    total: Duration,
    total_office: Duration,
    total_home: Duration,
    travel_distance: Float,
  )
}

pub type Statistics {
  Statistics(
    current_day: DayStatistics,
    week: Duration,
    week_eta: Duration,
    remaining_holiday: Duration,
  )
}

pub type WeekStatistics {
  WeekStatistics(
    monday: DayStatistics,
    tuesday: DayStatistics,
    wednesday: DayStatistics,
    thursday: DayStatistics,
    friday: DayStatistics,
    saturday: DayStatistics,
    sunday: DayStatistics,
  )
}

/// The different amounts that can be moved through the history.
pub type DateMoveAmount {
  MoveDay
  MoveWeek
  MoveMonth
  MoveYear
  ToToday
}

/// Moves the day by the specified amount, but keeping it between the provided min and max(today) day.
pub fn move_date(
  day: Day,
  amount: DateMoveAmount,
  direction: MoveDirection,
  min: Day,
  today: Day,
) -> Day {
  // If we are at the min edge, we will always move by one bakward. Otherwise, always cap it between min and max.
  use <- prim.check(day.prev(day), !{ direction == Backward && day == min })

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
  }
  |> day.clamp(min, today)
}

/// The differnt amounts that can be moved in floats.
pub type FloatMoveAmount {
  Ones
  Tens
  Tenths
}

/// The different amounts that can be moved through time/durations.
pub type TimeMoveAmount {
  MoveMinute
  MoveQuarter
  MoveStartQuarter
  MoveHour
  MoveStartHour
  ToNow
}

/// The directions in which can be moved through time.
pub type MoveDirection {
  Forward
  Backward
}

pub type Msg {
  NoOp
  UsernameChanged(new_username: String)
  PasswordChanged(new_password: String)
  Logout
  TryLogin
  LoginWithEnter(key: String)
  LoginResult(Result(SessionInfo, http.HttpError))
  ValidateSessionCheck(Result(Nil, http.HttpError))
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

  OpenSettings
  CancelSettings
  ApplySettings
  WeekTargetChanged(new_duration: String)
  WeekTargetKeyDown(amount: TimeMoveAmount, dir: MoveDirection)
  TravelDistanceChanged(new_distance: String)
  TravelDistanceKeyDown(amount: FloatMoveAmount, dir: MoveDirection)

  LoadWeekOverview
  CloseWeekOverview

  LoadHolidayOverview
}

pub fn recalculate_events(events: List(DayEvent)) -> List(DayEvent) {
  let calc_kind = fn(i) {
    case i % 2 {
      0 -> In
      _ -> Out
    }
  }

  let folder = fn(acc, event: DayEvent) {
    let #(gc, cc, acc) = acc
    case event {
      HolidayBooking(..) as h -> #(gc + 1, cc, [
        HolidayBooking(..h, index: gc),
        ..acc
      ])
      ClockEvent(..) as c -> #(gc + 1, cc + 1, [
        ClockEvent(..c, index: gc, kind: calc_kind(cc)),
        ..acc
      ])
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

/// Adds a new DayState at the specified day in the state history.
pub fn add_day_state(state: State, day: Day) -> State {
  let lunch = case day.weekday(day) {
    birl.Sat | birl.Sun -> False
    _ -> True
  }
  let target = case day.weekday(day) {
    birl.Sat | birl.Sun -> duration.zero()
    _ -> duration.hours(8, Pos)
  }
  let new_state = DayState(date: day, target:, lunch:, events: [])

  let folder = fn(acc: #(List(DayState), Option(DayState)), state: DayState) -> #(
    List(DayState),
    Option(DayState),
  ) {
    case acc.1, day.compare(day, state.date) {
      // We already added it.
      Some(_), _ -> #([state, ..acc.0], acc.1)
      // The day is equal, so it is already in the state. Nothing to do.
      None, Eq -> #([state, ..acc.0], Some(state))
      // The day is greater, so we need to look further to the right.
      None, Gt -> #([state, ..acc.0], acc.1)
      // The first time the day is smaller than the history entry, prepend it.
      None, Lt -> #([state, new_state, ..acc.0], Some(new_state))
    }
  }

  // Insert it at the right position. If it was not inserted, add it at the end.
  // Note that we add it at the front, since the list is reversed.
  let result = state.history |> list.fold(#([], None), folder)
  let new_history = case result.1 {
    Some(_) -> result.0 |> list.reverse
    None -> [new_state, ..result.0] |> list.reverse
  }

  State(
    ..state,
    current_state: result.1 |> option.unwrap(new_state),
    history: new_history,
  )
}

/// Calculates the new time based on a move amount and direction, and the current time input.
pub fn calculate_target_time(
  current: Option(Time),
  amount: TimeMoveAmount,
  dir: MoveDirection,
  now: Time,
) -> Option(Time) {
  use <- prim.check(Some(now), amount != ToNow)
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
    ToNow, _ -> now
    // This is already handled above, but we need to cover all cases anyway.
  }
  |> Some
}

/// Calculates the new duration based on a move amount and direction, and the current duration input.
pub fn calculate_target_duration(
  current: Option(Duration),
  amount: TimeMoveAmount,
  dir: MoveDirection,
  max: Int,
) -> Option(Duration) {
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
    ToNow, _ -> current
    // This should never happen, it doesn't do anything anyway.
  }
  |> Some
}

/// Serializes the state to a string that can be stored in the api.
pub fn serialize_state(st: State) -> String {
  let serialize_event = fn(event: DayEvent) -> String {
    case event {
      ClockEvent(..) as ce -> {
        time.to_int_string(ce.time)
        <> case ce.location {
          Home -> "H"
          Office -> "O"
        }
      }
      HolidayBooking(..) as hb -> {
        duration.to_int_string(hb.amount)
        <> case hb.kind {
          Gain -> "v"
          Use -> "V"
        }
      }
    }
  }

  let serialize_day = fn(st: DayState) -> string_tree.StringTree {
    let event_strings = st.events |> list.map(serialize_event)
    [
      day.to_int_string(st.date),
      duration.to_int_string(st.target),
      case st.lunch {
        True -> "L"
        False -> "N"
      },
    ]
    |> list.append(event_strings)
    |> string_tree.from_strings
  }

  let state_lines = st.history |> list.map(serialize_day)
  [
    "W" <> duration.to_int_string(st.week_target),
    "T" <> float.to_string(st.travel_distance),
  ]
  |> list.map(string_tree.from_string)
  |> list.append(state_lines)
  |> string_tree.join("\n")
  |> string_tree.to_string()
}
