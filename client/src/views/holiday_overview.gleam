import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import util/month
import util/prim

import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre/internals/vdom

import model.{
  type HolidayMonthStatistics, type HolidayStatistics, type Model, type Msg,
  type State, Booking, HolidayMonthStatistics, HolidayOverview, ReturnToBooking,
  State,
}
import util/duration.{type Duration}
import util/list as lst

import util/effect as ef

fn get_model(model: Model) -> Option(#(State, HolidayStatistics)) {
  case model {
    HolidayOverview(st, stats) -> Some(#(st, stats))
    _ -> None
  }
}

/// Update logic for the HolidayOverview view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use #(st, _) <- option.then(get_model(model))

  case msg {
    ReturnToBooking -> ef.just(Booking(st))
    _ -> ef.just(model)
  }
  |> Some
}

fn card(title: String, contents: List(vdom.Element(a))) {
  eh.div([a.class("card m-2")], [
    eh.div([a.class("card-body")], [
      eh.h3([a.class("card-title")], [e.text(title)]),
      ..contents
    ]),
  ])
}

fn remaining_card(remaining: Duration) {
  use <- prim.check(None, !{ duration.is_zero(remaining) })
  card("Previous years", [
    eh.table([a.class("table table-bordered table-striped p-4")], [
      eh.tbody([], [
        eh.tr([], [
          eh.th([a.class("col-2 text-end")], [eh.text("Remaining")]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_time_string(remaining)),
          ]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_decimal_string(remaining, 2)),
          ]),
        ]),
      ]),
    ]),
  ])
  |> Some
}

fn month_card(stats: HolidayMonthStatistics) {
  card(month.month_to_string(stats.month), [
    eh.table([a.class("table table-bordered table-striped p-4")], [
      eh.thead([], [
        eh.tr([], [
          eh.th([a.class("col-1")], [e.text("Day")]),
          eh.th([a.class("col-5")], [e.text("Amount")]),
          eh.th([a.class("col-6")], []),
        ]),
      ]),
      eh.tbody(
        [],
        stats.holiday_per_day
          |> list.map(fn(tuple) {
            let #(day, duration) = tuple

            eh.tr([], [
              eh.td([a.class("col-2 text-end")], [eh.text(int.to_string(day))]),
              eh.td([a.class("col-5")], [
                eh.text(duration.to_time_string(duration)),
              ]),
              eh.td([a.class("col-5")], [
                eh.text(duration.to_decimal_string(duration, 2)),
              ]),
            ])
          }),
      ),
    ]),
    eh.hr([]),
    eh.table([a.class("table table-bordered table-striped p-4")], [
      eh.tbody([], [
        eh.tr([], [
          eh.th([a.class("col-2 text-end")], [eh.text("Running total")]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_time_string(stats.running_total)),
          ]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_decimal_string(stats.running_total, 2)),
          ]),
        ]),
        eh.tr([], [
          eh.th([a.class("col-2 text-end")], [eh.text("Used this month")]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_time_string(stats.used_this_month)),
          ]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_decimal_string(stats.used_this_month, 2)),
          ]),
        ]),
        eh.tr([], [
          eh.th([a.class("col-2 text-end")], [eh.text("Gained this month")]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_time_string(stats.gained_this_month)),
          ]),
          eh.td([a.class("col-5")], [
            eh.text(duration.to_decimal_string(stats.gained_this_month, 2)),
          ]),
        ]),
      ]),
    ]),
  ])
  |> Some
}

/// View logic for the HolidayOverview view.
pub fn view(model: Model) {
  use #(_, stats) <- option.then(get_model(model))

  let close_button =
    eh.button(
      [a.class("btn btn-sm btn-outline-dark m-4"), ev.on_click(ReturnToBooking)],
      [e.text("Close")],
    )

  eh.div(
    [a.class("container row mx-auto")],
    lst.somes([
      Some(eh.h1([], [e.text("Holiday overview")])),
      remaining_card(stats.remaining_from_last_year),
      ..{ stats.months |> list.map(month_card) }
    ])
      |> list.append([close_button]),
  )
  |> Some
}
