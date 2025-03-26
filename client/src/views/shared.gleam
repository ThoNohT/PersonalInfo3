import gleam/option.{type Option}

import lustre/attribute as a
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev

import model.{type Msg, type Validated, NoOp, is_valid}
import util/event as uev
import util/prim

pub fn text_input(
  name,
  label,
  value: Validated(a),
  invalid_message,
  input_message,
  keydown_message,
  parsed_to_string,
  autofocus,
) {
  eh.div([a.class("col-6 row container justify-content-start")], [
    eh.label([a.for(name <> "-input"), a.class("col-4 px-0 py-2")], [
      e.text(label),
    ]),
    eh.div([a.class("col-8")], [
      eh.input([
        a.type_("text"),
        a.class("form-control time-form"),
        a.id(name <> "-input"),
        a.value(value.input),
        a.autofocus(autofocus),
        a.classes([
          #("is-invalid", !is_valid(value)),
          #("is-valid", is_valid(value)),
        ]),
        keydown_message
          |> option.map(fn(msg) { uev.on_keydown_mod(msg) })
          |> option.unwrap(a.none()),
        ev.on_input(input_message),
      ]),
      eh.div([a.class("invalid-feedback")], [e.text(invalid_message)]),
      eh.div([a.class("valid-feedback")], [
        e.text(
          value.parsed |> option.map(parsed_to_string) |> option.unwrap("-"),
        ),
      ]),
    ]),
  ])
}

pub fn check_input(name, label, value, input_message) {
  eh.div([a.class("col-3 row container justify-content-start")], [
    eh.div([a.class("col-8")], [
      eh.input([
        a.type_("checkbox"),
        a.id(name <> "-input"),
        a.checked(value),
        ev.on_check(input_message),
      ]),
      eh.label([a.for(name <> "-input"), a.class("col-4 p-2")], [e.text(label)]),
    ]),
  ])
}

pub fn input_keydown_handler(
  tuple: #(uev.ModifierState, String),
  to_move_msg: fn(model.TimeMoveAmount, model.MoveDirection) -> Msg,
  add_msg_1: Option(Msg),
  add_msg_2: Option(Msg),
) -> #(Msg, Bool) {
  use <- prim.check(#(NoOp, False), !{ tuple.0 }.alt)
  case tuple.1, { tuple.0 }.ctrl, { tuple.0 }.shift {
    "ArrowRight", True, False -> #(
      to_move_msg(model.MoveMinute, model.Forward),
      True,
    )
    "ArrowLeft", True, False -> #(
      to_move_msg(model.MoveMinute, model.Backward),
      True,
    )

    // Up = 15 minutes, Up + Ctrl = 1 hour. + Shift = to start.
    "ArrowUp", False, False -> #(
      to_move_msg(model.MoveQuarter, model.Forward),
      True,
    )
    "ArrowDown", False, False -> #(
      to_move_msg(model.MoveQuarter, model.Backward),
      True,
    )
    "ArrowUp", True, False -> #(
      to_move_msg(model.MoveStartQuarter, model.Forward),
      True,
    )
    "ArrowDown", True, False -> #(
      to_move_msg(model.MoveStartQuarter, model.Backward),
      True,
    )

    "ArrowUp", False, True -> #(
      to_move_msg(model.MoveHour, model.Forward),
      True,
    )
    "ArrowDown", False, True -> #(
      to_move_msg(model.MoveHour, model.Backward),
      True,
    )
    "ArrowUp", True, True -> #(
      to_move_msg(model.MoveStartHour, model.Forward),
      True,
    )
    "ArrowDown", True, True -> #(
      to_move_msg(model.MoveStartHour, model.Backward),
      True,
    )

    "n", False, False -> #(to_move_msg(model.ToNow, model.Backward), True)

    // Direction is not used here.
    "Enter", False, False ->
      add_msg_1
      |> option.map(fn(m) { #(m, True) })
      |> option.unwrap(#(NoOp, False))
    "Enter", True, False ->
      add_msg_2
      |> option.map(fn(m) { #(m, True) })
      |> option.unwrap(#(NoOp, False))

    _, _, _ -> #(NoOp, False)
  }
}

pub fn input_keydown_handler_float(
  tuple: #(uev.ModifierState, String),
  to_move_msg: fn(model.FloatMoveAmount, model.MoveDirection) -> Msg,
  add_msg: Option(Msg),
) -> #(Msg, Bool) {
  use <- prim.check(#(NoOp, False), !{ tuple.0 }.alt)
  case tuple.1, { tuple.0 }.ctrl, { tuple.0 }.shift {
    "ArrowUp", False, False -> #(to_move_msg(model.Ones, model.Forward), True)
    "ArrowDown", False, False -> #(
      to_move_msg(model.Ones, model.Backward),
      True,
    )
    "ArrowUp", True, False -> #(to_move_msg(model.Tens, model.Forward), True)
    "ArrowDown", True, False -> #(to_move_msg(model.Tens, model.Backward), True)

    "ArrowUp", _, True -> #(to_move_msg(model.Tenths, model.Forward), True)
    "ArrowDown", _, True -> #(to_move_msg(model.Tenths, model.Backward), True)

    "Enter", _, False ->
      add_msg
      |> option.map(fn(m) { #(m, True) })
      |> option.unwrap(#(NoOp, False))

    _, _, _ -> #(NoOp, False)
  }
}
