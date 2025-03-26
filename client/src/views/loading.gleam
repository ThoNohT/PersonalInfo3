import gleam/http as ghttp
import gleam/list
import gleam/option.{type Option, None, Some}

import birl.{type Day}
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre_http as http

import model.{
  type Model, type Msg, type State, DayState, Err, InputState, LoadState, Loaded,
  Loading, Login, LoginModel, SelectListItem, State, Tick, ValidateSessionCheck,
  unvalidated, validate,
}
import model/statistics
import parsing
import shared_model.{type SessionInfo, Credentials}
import util/duration
import util/effect as ef
import util/local_storage
import util/parser as p
import util/site
import util/time.{type Time}

fn get_model(model: Model) -> Option(SessionInfo) {
  case model {
    Loading(sess) -> Some(sess)
    _ -> None
  }
}

/// Update logic for the err view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use session <- option.then(get_model(model))

  case msg {
    ValidateSessionCheck(result) -> {
      case result {
        Ok(_) -> {
          let request =
            site.request_with_authorization(
              site.base_url() <> "/api/simplestate/pi_history",
              ghttp.Get,
              session.session_id,
            )
          #(Loading(session), http.send(request, http.expect_text(LoadState)))
        }
        Error(_) -> {
          local_storage.remove("session")
          ef.just(Login(LoginModel(Credentials("", ""), False)))
        }
      }
    }
    LoadState(result) -> {
      case result {
        Error(_) -> ef.just(Err("Could not load state."))
        Ok(res) -> {
          let today = time.today()
          let now = time.now()

          let state = load_state(session, res, today, now)
          #(
            Loaded(state),
            effect.batch([ef.dispatch(SelectListItem(0)), ef.every(1000, Tick)]),
          )
        }
      }
    }
    _ -> ef.just(model)
  }
  |> Some
}

/// View logic for the err view.
pub fn view(model: Model) {
  use _ <- option.then(get_model(model))
  eh.div([a.class("row mx-auto container justify-content-center p-4")], [
    eh.div([a.class("spinner-border"), a.role("status")], [
      eh.span([a.class("visually-hidden")], [e.text("Loading...")]),
    ]),
  ])
  |> Some
}

fn load_state(
  session: SessionInfo,
  input: String,
  today: Day,
  now: Time,
) -> State {
  // TODO: Proper handling of failing to parse.
  let assert Some(state_input) = parsing.parse_state_input(input)

  // Fixed values:
  let input_state = InputState(unvalidated(), unvalidated(), unvalidated())
  let selected_event_index = None
  let stats = statistics.zero()

  // Make some current state, it will be replaced by add_day_state.
  let current_state =
    DayState(date: today, target: duration.zero(), lunch: False, events: [])
  let state =
    State(
      session:,
      today:,
      now:,
      current_state:,
      stats:,
      selected_event_index:,
      input_state:,
      history: state_input.history
        |> list.map(fn(d) {
          DayState(..d, events: d.events |> model.recalculate_events)
        })
        |> list.reverse,
      week_target: state_input.week_target,
      travel_distance: state_input.travel_distance,
    )
    |> model.add_day_state(today)
    |> statistics.recalculate

  let input_state =
    InputState(
      ..input_state,
      target_input: validate(
        duration.to_decimal_string(state.current_state.target, 2),
        duration.parser() |> p.conv,
      ),
    )
  State(..state, input_state:)
}
