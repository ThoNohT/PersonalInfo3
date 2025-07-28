import gleam/float
import gleam/option.{type Option, None, Some}

import birl.{type Day}
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev

import model.{
  type DayStatistics, type Model, type Msg, type State, type WeekStatistics,
  Booking, DayStatistics, ReturnToBooking, State, WeekOverview,
}

import util/day
import util/duration.{type DurationOrFloat, DofDuration, DofFloat}
import util/effect as ef

fn get_model(model: Model) -> Option(#(State, WeekStatistics)) {
  case model {
    WeekOverview(st, stats) -> Some(#(st, stats))
    _ -> None
  }
}

/// Update logic for the WeekOverview view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use #(st, _) <- option.then(get_model(model))

  case msg {
    ReturnToBooking -> ef.just(Booking(st))
    _ -> ef.just(model)
  }
  |> Some
}

/// Formats a statistic that is either a duration, or a float.
/// A duration is printed in time and decimal format, a float is simply displayed.
fn format_stat(value: DurationOrFloat) -> String {
  case value {
    DofDuration(d) ->
      case duration.is_zero(d) {
        True -> ""
        False -> duration.to_string(d)
      }
    DofFloat(f) if f >. 0.0 -> float.to_string(f)
    _ -> ""
  }
}

/// Prints a single table row for a single statistic for all days of the week.
fn table_row(
  stat: String,
  stats: WeekStatistics,
  stat_selector: fn(DayStatistics) -> DurationOrFloat,
) {
  eh.tr([], [
    eh.th([], [e.text(stat <> ":")]),
    eh.td([], [e.text(format_stat(stat_selector(stats.monday)))]),
    eh.td([], [e.text(format_stat(stat_selector(stats.tuesday)))]),
    eh.td([], [e.text(format_stat(stat_selector(stats.wednesday)))]),
    eh.td([], [e.text(format_stat(stat_selector(stats.thursday)))]),
    eh.td([], [e.text(format_stat(stat_selector(stats.friday)))]),
    eh.td([], [e.text(format_stat(stat_selector(stats.saturday)))]),
    eh.td([], [e.text(format_stat(stat_selector(stats.sunday)))]),
  ])
}

/// View logic for the WeekOverview view.
pub fn view(model: Model) {
  use #(state, stats) <- option.then(get_model(model))

  let day_string = fn(day) {
    day.to_relative_string(day, state.today)
    |> option.unwrap(day.to_string(day))
  }

  let day_header = fn(day: Day) {
    eh.th([], [
      eh.div([], [e.text(birl.weekday_to_string(day.weekday(day)))]),
      eh.div([], [e.text(day_string(day))]),
    ])
  }

  eh.div([a.class("container row mx-auto")], [
    eh.h1([], [e.text("Week overview")]),
    eh.table([a.class("table table-bordered table-striped")], [
      eh.thead([], [
        eh.tr([], [
          eh.th([], [e.text("Day:")]),
          day_header(stats.monday.day),
          day_header(stats.tuesday.day),
          day_header(stats.wednesday.day),
          day_header(stats.thursday.day),
          day_header(stats.friday.day),
          day_header(stats.saturday.day),
          day_header(stats.sunday.day),
        ]),
      ]),
      eh.tbody([], [
        table_row("Office", stats, fn(s) { DofDuration(s.total_office) }),
        table_row("Home", stats, fn(s) { DofDuration(s.total_home) }),
        table_row("Total", stats, fn(s) { DofDuration(s.total) }),
        table_row("Travel", stats, fn(s) { DofFloat(s.travel_distance) }),
      ]),
    ]),
    eh.button(
      [a.class("btn btn-sm btn-outline-dark"), ev.on_click(ReturnToBooking)],
      [e.text("Close")],
    ),
  ])
  |> Some
}
