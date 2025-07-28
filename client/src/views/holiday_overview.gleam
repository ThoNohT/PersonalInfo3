import gleam/option.{type Option, None, Some}

import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev

import model.{
  type HolidayStatistics, type Model, type Msg, type State, Booking,
  HolidayOverview, ReturnToBooking, State,
}

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

/// View logic for the HolidayOverview view.
pub fn view(model: Model) {
  use #(_state, _stats) <- option.then(get_model(model))

  eh.div([a.class("container row mx-auto")], [
    eh.h1([], [e.text("Holiday overview")]),
    eh.table([a.class("table table-bordered table-striped")], []),
    eh.button(
      [a.class("btn btn-sm btn-outline-dark"), ev.on_click(ReturnToBooking)],
      [e.text("Close")],
    ),
  ])
  |> Some
}
