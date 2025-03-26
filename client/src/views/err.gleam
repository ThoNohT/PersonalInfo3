import gleam/option.{type Option, None, Some}

import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh

import model.{type Model, type Msg, Err}
import util/effect as ef

fn get_model(model: Model) -> Option(String) {
  case model {
    Err(err) -> Some(err)
    _ -> None
  }
}

/// Update logic for the err view.
pub fn update(model: Model, _: Msg) -> Option(#(Model, Effect(Msg))) {
  use _ <- option.then(get_model(model))
  ef.just(model) |> Some
}

/// View logic for the err view.
pub fn view(model: Model) {
  use e <- option.then(get_model(model))
  eh.div([], [e.text("Error: " <> e)]) |> Some
}
