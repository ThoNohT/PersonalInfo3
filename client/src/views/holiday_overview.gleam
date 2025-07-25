import gleam/option.{type Option, None, Some}

import lustre/effect.{type Effect}
import lustre/element as e

import model.{type Model, type Msg, type State, HolidayOverview, State}

import util/effect as ef
import util/time

fn get_model(model: Model) -> Option(State) {
  case model {
    HolidayOverview(st) -> Some(st)
    _ -> None
  }
}

/// Update logic for the HolidayOverview view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use _st <- option.then(get_model(model))

  let _today = time.today()
  let _now = time.now()

  case msg {
    _ -> ef.just(model)
  }
  |> Some
}

/// View logic for the HolidayOverview view.
pub fn view(model: Model) {
  use _st <- option.then(get_model(model))
  e.text("Holiday overview") |> Some
}
