import gleam/option.{type Option, None, Some}

import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh

import model.{
  type Model, type Msg, type State, type WeekStatistics, State, WeekOverview,
}

import util/effect as ef
import util/time

fn get_model(model: Model) -> Option(#(State, WeekStatistics)) {
  case model {
    WeekOverview(st, stats) -> Some(#(st, stats))
    _ -> None
  }
}

/// Update logic for the WeekOverview view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use _st <- option.then(get_model(model))

  let _today = time.today()
  let _now = time.now()

  case msg {
    _ -> ef.just(model)
  }
  |> Some
}

/// View logic for the WeekOverview view.
pub fn view(model: Model) {
  use #(_state, _stats) <- option.then(get_model(model))

  eh.div([a.class("col")], [
    eh.div([a.class("col-1")], [e.text("Day:")]),
    eh.div([a.class("col-1")], [e.text("Office:")]),
    eh.div([a.class("col-1")], [e.text("Home:")]),
    eh.div([a.class("col-1")], [e.text("Total:")]),
    eh.div([a.class("col-1")], [e.text("Travel:")]),
  ])
  |> Some
}
