import gleam/float
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev

import model.{
  type Model, type Msg, type SettingsModel, type SettingsState, type State,
  ApplySettings, Booking, CancelSettings, Settings, SettingsModel, SettingsState,
  State, TravelDistanceChanged, TravelDistanceKeyDown, WeekTargetChanged,
  WeekTargetKeyDown, validate,
}
import model/statistics
import util/duration
import util/effect as ef
import util/parser as p
import util/parsers
import views/booking.{store_state}
import views/shared

fn get_model(model: Model) -> Option(SettingsModel) {
  case model {
    Settings(sm) -> Some(sm)
    _ -> None
  }
}

/// Update logic for the Settings view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use SettingsModel(st, ss) <- option.then(get_model(model))

  let and_store = fn(m: Model) { #(m, store_state(m)) }

  case msg {
    CancelSettings -> ef.just(Booking(st))
    ApplySettings -> {
      let week_target =
        ss.week_target_input.parsed |> option.unwrap(st.week_target)
      let travel_distance =
        ss.travel_distance_input.parsed |> option.unwrap(st.travel_distance)
      Booking(
        State(..st, week_target:, travel_distance:)
        |> statistics.recalculate,
      )
      |> and_store
    }
    WeekTargetChanged(nt) -> {
      let week_target_input =
        validate(string.slice(nt, 0, 6), duration.parser() |> p.conv)
      ef.just(
        Settings(SettingsModel(
          st,
          settings: SettingsState(..ss, week_target_input:),
        )),
      )
    }
    WeekTargetKeyDown(amount, dir) -> {
      use to_duration <- ef.then(
        model,
        model.calculate_target_duration(
          ss.week_target_input.parsed,
          amount,
          dir,
          24 * 7,
        ),
      )
      let settings =
        SettingsState(
          ..ss,
          week_target_input: validate(
            duration.to_time_string(to_duration),
            duration.parser() |> p.conv,
          ),
        )
      ef.just(Settings(SettingsModel(st, settings:)))
    }
    TravelDistanceChanged(new_distance) -> {
      let travel_distance_input =
        validate(
          string.slice(new_distance, 0, 4),
          parsers.pos_float() |> p.conv,
        )
      ef.just(
        Settings(SettingsModel(
          st,
          settings: SettingsState(..ss, travel_distance_input:),
        )),
      )
    }
    TravelDistanceKeyDown(amount, dir) -> {
      use current_distance <- ef.then(model, ss.travel_distance_input.parsed)

      let new_distance = case amount, dir {
        model.Ones, model.Forward -> current_distance +. 1.0
        model.Ones, model.Backward -> current_distance -. 1.0
        model.Tens, model.Forward -> current_distance +. 10.0
        model.Tens, model.Backward -> current_distance -. 10.0
        model.Tenths, model.Forward -> current_distance +. 0.1
        model.Tenths, model.Backward -> current_distance -. 0.1
      }
      ef.just(
        Settings(SettingsModel(
          st,
          settings: SettingsState(
            ..ss,
            travel_distance_input: validate(
              float.to_string(new_distance),
              parsers.pos_float() |> p.conv,
            ),
          ),
        )),
      )
    }
    _ -> ef.just(model)
  }
  |> Some
}

fn settings_area(st: State, ss: SettingsState) {
  [
    eh.h3([a.class("col-9 text-center")], [e.text("Settings")]),
    shared.text_input(
      "weektarget",
      "Week target:",
      ss.week_target_input,
      duration.to_unparsed_format_string(st.week_target),
      WeekTargetChanged,
      Some(shared.input_keydown_handler(
        _,
        WeekTargetKeyDown,
        Some(ApplySettings),
        None,
      )),
      duration.to_unparsed_format_string,
      True,
    ),
    shared.text_input(
      "traveldistance",
      "Travel distance:",
      ss.travel_distance_input,
      float.to_string(st.travel_distance),
      TravelDistanceChanged,
      Some(shared.input_keydown_handler_float(
        _,
        TravelDistanceKeyDown,
        Some(ApplySettings),
      )),
      float.to_string,
      False,
    ),
    eh.button(
      [
        a.class("btn btn-outline-secondary btn-sm me-1"),
        ev.on_click(CancelSettings),
      ],
      [e.text("Cancel")],
    ),
    eh.button(
      [
        a.class("btn btn-outline-primary btn-sm me-1"),
        ev.on_click(ApplySettings),
      ],
      [e.text("Apply")],
    ),
  ]
}

/// View logic for the Settings view.
pub fn view(model: Model) {
  use SettingsModel(st, ss) <- option.then(get_model(model))
  eh.div([a.class("container col mx-auto")], settings_area(st, ss)) |> Some
}
