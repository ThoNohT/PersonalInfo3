//// A module dedicated to calculating statistics.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Gt, Lt}

import birl.{type Day}

import model.{
  type ClockLocation, type DayEvent, type DayState, type DayStatistics,
  type State, type Statistics, ClockEvent, DayState, DayStatistics, Gain,
  HolidayBooking, Home, In, Office, Out, State, Statistics, Use,
}
import util/day
import util/duration.{type Duration}
import util/numbers.{Neg}
import util/prim
import util/time.{type Time}

/// Creates empty day statistics.
fn day_zero() -> DayStatistics {
  let z = duration.zero()
  DayStatistics(z, z, z, z)
}

/// Creates empty statistics.
pub fn zero() -> Statistics {
  Statistics(day_zero(), duration.zero(), duration.zero(), duration.zero())
}

type InState =
  #(ClockLocation, Time)

/// Calculates the statistics for a single day.
pub fn calculate_day(ds: DayState, today: Day, now: Time) -> DayStatistics {
  // Helper to add hours to the correct location in statistics.
  let add_hours = fn(
    stats: DayStatistics,
    duration: Duration,
    loc: ClockLocation,
  ) -> DayStatistics {
    let total = duration.add(stats.total, duration)
    let total_office = {
      use <- prim.check(stats.total_office, loc == Office)
      duration.add(stats.total_office, duration)
    }
    let total_home = {
      use <- prim.check(stats.total_home, loc == Home)
      duration.add(stats.total_home, duration)
    }

    DayStatistics(..stats, total:, total_office:, total_home:)
  }

  let folder = fn(acc: #(DayStatistics, Option(InState)), event: DayEvent) {
    let stats = acc.0
    case event {
      // Holiday is not maintained in day statistics.
      HolidayBooking(..) -> acc
      // When clocking in, save the current state.
      ClockEvent(_, time, loc, In) -> #(stats, Some(#(loc, time)))

      // When clocking out, calculate the new totals from the saved in state.
      ClockEvent(_, time, _, Out) -> {
        let assert Some(in_state) = acc.1
        let duration = duration.between(in_state.1, time)
        #(add_hours(stats, duration, in_state.0), None)
      }
    }
  }

  // First loop over all clock events during this day to gather 
  // the completed clock in duration.
  let after_fold = ds.events |> list.fold(#(day_zero(), None), folder)

  // If there is an in state left, and the day is today,
  // calculate the extra time from the in state to now.
  let stats = case after_fold.1, today == ds.date {
    Some(in_state), True ->
      add_hours(after_fold.0, duration.between(in_state.1, now), in_state.0)
    _, _ -> after_fold.0
  }

  // If lunch is included, assume half an hour of clocked time doesn't exist. Take it from the longest period
  // of office or home, but prefer office if this cannot be determined. If no clock events, then don't
  // take any lunch away, since we didn't work at all.
  let stats = case ds.lunch, model.daystate_has_clock_events(ds) {
    True, True -> {
      let half_hour = duration.minutes(30, Neg)
      case duration.compare(stats.total_office, stats.total_home) {
        Lt -> add_hours(stats, half_hour, Home)
        _ -> add_hours(stats, half_hour, Office)
      }
    }
    _, _ -> stats
  }

  // Fill in the remaining.
  DayStatistics(..stats, eta: duration.subtract(ds.target, stats.total))
}

/// Recalculates the statistics in the provided state.
pub fn recalculate(state: State) -> State {
  let st = state.current_state

  let folder = fn(acc: Statistics, day: DayStatistics) {
    Statistics(
      ..acc,
      week: duration.add(acc.week, day.total),
      week_eta: duration.subtract(acc.week_eta, day.total),
    )
  }

  // Calculate week statistics.
  let stats =
    state.history
    |> list.filter(fn(ds) {
      day.week_number(ds.date) == day.week_number(st.date)
      && day.compare(ds.date, st.date) != Gt
    })
    |> list.map(calculate_day(_, state.today, state.now))
    |> list.fold(Statistics(..zero(), week_eta: state.week_target), folder)

  // Calculate holiday.
  let holiday_folder = fn(acc: Statistics, ds: DayState) {
    let sum_added =
      ds.events
      |> list.fold(duration.zero(), fn(acc: Duration, e: DayEvent) {
        let to_add = case e {
          HolidayBooking(_, duration, Gain) -> duration
          HolidayBooking(_, duration, Use) -> duration.negate(duration)
          _ -> duration.zero()
        }
        duration.add(acc, to_add)
      })

    Statistics(
      ..acc,
      remaining_holiday: duration.add(acc.remaining_holiday, sum_added),
    )
  }

  let stats =
    state.history
    |> list.filter(fn(ds) { day.compare(ds.date, st.date) != Gt })
    |> list.fold(stats, holiday_folder)

  let stats =
    Statistics(..stats, current_day: calculate_day(st, state.today, state.now))
  State(..state, stats:)
}
