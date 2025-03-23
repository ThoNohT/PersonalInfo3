import gleam/float
import gleam/http as ghttp
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import gleam/order.{Lt}
import gleam/string
import util/local_storage

import birl.{type Day}
import lustre
import lustre/effect
import lustre_http as http

import model.{
  type DayState, type InputState, type Model, type Msg, type State,
  AddClockEvent, AddHolidayBooking, ApplySettings, CancelSettings, ChangeDay,
  ClockEvent, DayState, DeleteListItem, Err, HolidayBooking, HolidayInputChanged,
  HolidayInputKeyDown, In, InputState, LoadState, Loaded, Loading, Login,
  LoginResult, LoginWithEnter, Logout, LunchChanged, NoOp, Office, OpenSettings,
  PasswordChanged, SelectListItem, Settings, SettingsState, State, TargetChanged,
  TargetKeyDown, Tick, TimeInputChanged, TimeInputKeyDown, ToggleHome,
  TravelDistanceChanged, TravelDistanceKeyDown, TryLogin, UsernameChanged,
  ValidateSessionCheck, WeekTargetChanged, WeekTargetKeyDown, unvalidated,
  validate,
}
import model/statistics
import parsing
import shared_model.{type Credentials, type SessionInfo, Credentials}
import util/duration
import util/effect as ef
import util/parser as p
import util/parsers
import util/site
import util/time.{type Time}
import view.{view}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_) {
  let now = birl.now()
  let login_state = Login(Credentials("", ""), False)

  // Load session from local storage.
  use session <- ef.then(
    login_state,
    local_storage.get("session", shared_model.session_info_decoder()),
  )
  // Check session validity.
  use <- ef.check(login_state, birl.compare(now, session.expires_at) == Lt)

  // Try to see if session is still valid.
  let request =
    site.request_with_authorization(
      site.base_url() <> "/api/user/check_session",
      ghttp.Get,
      session.session_id,
    )
  #(
    Loading(session),
    http.send(request, http.expect_anything(ValidateSessionCheck)),
  )
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

/// Sends a request to store the current state to the api.
/// Will only send a request if the state is loaded.
fn store_state(model: Model) -> effect.Effect(Msg) {
  case model {
    Loaded(st) -> {
      let request =
        site.request_with_authorization(
          site.base_url() <> "/api/simplestate/pi_history",
          ghttp.Put,
          st.session.session_id,
        )
        |> request.set_body(model.serialize_state(st))
      http.send(request, http.expect_anything(fn(_) { NoOp }))
    }
    _ -> effect.none()
  }
}

fn update(model: Model, msg: Msg) {
  // When returning the model, this function can be called on it,
  // to also send the new serialized state to the api.
  let and_store = fn(m: Model) { #(m, store_state(m)) }

  case model {
    // Err.
    Err(_) -> ef.just(model)

    // Login.
    Login(creds, failed) -> {
      case msg {
        UsernameChanged(username) ->
          ef.just(Login(Credentials(..creds, username:), failed))
        PasswordChanged(password) ->
          ef.just(Login(Credentials(..creds, password:), failed))
        LoginWithEnter(key) -> {
          case key {
            "Enter" -> #(model, ef.dispatch(TryLogin))
            _ -> ef.just(model)
          }
        }
        TryLogin -> {
          use <- ef.check(
            model,
            model.credentials.username != "" && model.credentials.password != "",
          )
          let base_url = site.base_url()
          #(
            Login(..model, failed: False),
            http.post(
              base_url <> "/api/user/login",
              shared_model.encode_credentials(creds),
              http.expect_json(shared_model.session_info_decoder(), LoginResult),
            ),
          )
        }
        LoginResult(result) -> {
          case result {
            Error(_) -> #(Login(creds, True), ef.focus("username-input", NoOp))
            Ok(session) -> {
              local_storage.set(
                "session",
                session,
                shared_model.encode_session_info,
              )
              let request =
                site.request_with_authorization(
                  site.base_url() <> "/api/simplestate/pi_history",
                  ghttp.Get,
                  session.session_id,
                )
              #(
                Loading(session),
                http.send(request, http.expect_text(LoadState)),
              )
            }
          }
        }
        _ -> ef.just(model)
      }
    }

    // Loading.
    Loading(session) -> {
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
              #(
                Loading(session),
                http.send(request, http.expect_text(LoadState)),
              )
            }
            Error(_) -> {
              local_storage.remove("session")
              ef.just(Login(Credentials("", ""), False))
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
                effect.batch([
                  ef.dispatch(SelectListItem(0)),
                  ef.every(1000, Tick),
                ]),
              )
            }
          }
        }
        _ -> ef.just(model)
      }
    }

    // Loaded.
    Loaded(st) -> {
      case msg {
        Tick -> {
          let today = time.today()
          let now = time.now()

          // Only update if the time changed to the precision we observe it (minutes).
          use <- ef.check(model, now != st.now)
          ef.just(Loaded(
            State(..st, today:, now:)
            |> model.update_history
            |> statistics.recalculate,
          ))
        }
        Logout -> {
          let request =
            site.request_with_authorization(
              site.base_url() <> "/api/user/logout",
              ghttp.Post,
              st.session.session_id,
            )
          local_storage.remove("session")
          #(
            Login(Credentials("", ""), False),
            http.send(request, http.expect_anything(fn(_) { NoOp })),
          )
        }
        TimeInputChanged(new_time) -> {
          let input_state =
            InputState(
              ..st.input_state,
              clock_input: validate(string.slice(new_time, 0, 5), p.run(
                time.parser(),
                _,
              )),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        HolidayInputChanged(new_duration) -> {
          let input_state =
            InputState(
              ..st.input_state,
              holiday_input: validate(string.slice(new_duration, 0, 6), p.run(
                duration.parser(),
                _,
              )),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        TargetChanged(nt) -> {
          let target_input =
            validate(string.slice(nt, 0, 6), duration.parser() |> p.conv)
          let input_state = InputState(..st.input_state, target_input:)
          let current_state_and_update = case target_input.parsed {
            None -> #(st.current_state, False)
            Some(target) -> #(DayState(..st.current_state, target:), True)
          }
          let current_state = current_state_and_update.0
          let new_model =
            Loaded(
              State(..st, current_state:, input_state:)
              |> model.update_history
              |> statistics.recalculate,
            )
          case current_state_and_update.1 {
            False -> ef.just(new_model)
            True -> new_model |> and_store
          }
        }
        LunchChanged(new_lunch) -> {
          let current_state = DayState(..st.current_state, lunch: new_lunch)
          Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> statistics.recalculate,
          )
          |> and_store
        }
        SelectListItem(idx) -> {
          let selected_event =
            st.current_state.events
            |> list.drop(idx)
            |> list.first
            |> option.from_result
          let selected_idx = selected_event |> option.map(fn(e) { e.index })
          let input_state = case selected_event {
            Some(ClockEvent(..) as ce) ->
              InputState(
                ..st.input_state,
                clock_input: validate(time.to_string(ce.time), p.run(
                  time.parser(),
                  _,
                )),
              )
            Some(HolidayBooking(..) as hb) ->
              InputState(
                ..st.input_state,
                holiday_input: validate(
                  duration.to_time_string(hb.amount),
                  duration.parser() |> p.conv,
                ),
              )
            None -> st.input_state
          }
          ef.just(Loaded(
            State(..st, selected_event_index: selected_idx, input_state:),
          ))
        }
        DeleteListItem(idx) -> {
          let #(before, after) = st.current_state.events |> list.split(idx)
          case after {
            [_, ..af] -> {
              // Takes out the element at idx.
              let current_state =
                DayState(
                  ..st.current_state,
                  events: list.append(before, af) |> model.recalculate_events,
                )
              Loaded(
                State(..st, current_state:)
                |> model.update_history
                |> statistics.recalculate,
              )
              |> and_store
            }
            _ -> ef.just(model)
          }
        }
        ToggleHome(idx) -> {
          let toggle_home = fn(e) {
            case e {
              ClockEvent(index: index, location: loc, ..) as ce if idx == index ->
                ClockEvent(..ce, location: model.switch_location(loc))
              _ -> e
            }
          }

          let new_events = st.current_state.events |> list.map(toggle_home)
          let current_state =
            DayState(
              ..st.current_state,
              events: new_events |> model.recalculate_events,
            )
          Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> statistics.recalculate,
          )
          |> and_store
        }
        AddClockEvent -> {
          use time <- ef.then(model, st.input_state.clock_input.parsed)
          use <- ef.check(
            model,
            !model.daystate_has_clock_event_at(st.current_state, time),
          )

          let new_event =
            ClockEvent(list.length(st.current_state.events), time, Office, In)
          let events =
            [new_event, ..st.current_state.events] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:)
          Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> statistics.recalculate,
          )
          |> and_store
        }
        AddHolidayBooking(kind) -> {
          use duration <- ef.then(model, st.input_state.holiday_input.parsed)

          let new_event =
            HolidayBooking(list.length(st.current_state.events), duration, kind)
          let events =
            [new_event, ..st.current_state.events] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:)
          Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> statistics.recalculate,
          )
          |> and_store
        }
        ChangeDay(amount, dir) -> {
          let first_day =
            st.history
            |> list.first
            |> option.from_result
            |> option.map(fn(x) { x.date })
            |> option.unwrap(st.today)
          let to_day =
            model.move_date(
              st.current_state.date,
              amount,
              dir,
              first_day,
              st.today,
            )

          let state = case
            list.find(st.history, fn(s: DayState) { s.date == to_day })
          {
            Ok(current_state) ->
              State(..st, current_state:) |> statistics.recalculate
            Error(_) ->
              model.add_day_state(st, to_day) |> statistics.recalculate
          }

          let input_state =
            InputState(
              ..state.input_state,
              target_input: validate(
                duration.to_decimal_string(state.current_state.target, 2),
                duration.parser() |> p.conv,
              ),
            )
          ef.just(Loaded(State(..state, input_state:)))
        }
        TimeInputKeyDown(amount, dir) -> {
          use to_time <- ef.then(
            model,
            model.calculate_target_time(
              st.input_state.clock_input.parsed,
              amount,
              dir,
              st.now,
            ),
          )
          let input_state =
            InputState(
              ..st.input_state,
              clock_input: validate(time.to_string(to_time), p.run(
                time.parser(),
                _,
              )),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        HolidayInputKeyDown(amount, dir) -> {
          use to_duration <- ef.then(
            model,
            model.calculate_target_duration(
              st.input_state.holiday_input.parsed,
              amount,
              dir,
              1000,
            ),
          )
          let input_state =
            InputState(
              ..st.input_state,
              holiday_input: validate(
                duration.to_time_string(to_duration),
                duration.parser() |> p.conv,
              ),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        TargetKeyDown(amount, dir) -> {
          use to_duration <- ef.then(
            model,
            model.calculate_target_duration(
              st.input_state.target_input.parsed,
              amount,
              dir,
              24,
            ),
          )
          let input_state =
            InputState(
              ..st.input_state,
              target_input: validate(
                duration.to_time_string(to_duration),
                duration.parser() |> p.conv,
              ),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        OpenSettings -> {
          let week_target_input =
            model.validate(
              duration.to_time_string(st.week_target),
              duration.parser() |> p.conv,
            )
          let travel_distance_input =
            model.validate(float.to_string(st.travel_distance), fn(f) {
              float.parse(f) |> option.from_result
            })
          ef.just(Settings(
            state: st,
            settings: SettingsState(week_target_input:, travel_distance_input:),
          ))
        }
        _ -> ef.just(model)
      }
    }
    Settings(st, ss) -> {
      case msg {
        CancelSettings -> ef.just(Loaded(st))
        ApplySettings -> {
          let week_target =
            ss.week_target_input.parsed |> option.unwrap(st.week_target)
          let travel_distance =
            ss.travel_distance_input.parsed |> option.unwrap(st.travel_distance)
          Loaded(
            State(..st, week_target:, travel_distance:)
            |> statistics.recalculate,
          )
          |> and_store
        }
        WeekTargetChanged(nt) -> {
          let week_target_input =
            validate(string.slice(nt, 0, 6), duration.parser() |> p.conv)
          ef.just(Settings(
            st,
            settings: SettingsState(..ss, week_target_input:),
          ))
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
          ef.just(Settings(st, settings:))
        }
        TravelDistanceChanged(new_distance) -> {
          let travel_distance_input =
            validate(
              string.slice(new_distance, 0, 4),
              parsers.pos_float() |> p.conv,
            )
          ef.just(Settings(
            st,
            settings: SettingsState(..ss, travel_distance_input:),
          ))
        }
        TravelDistanceKeyDown(amount, dir) -> {
          use current_distance <- ef.then(
            model,
            ss.travel_distance_input.parsed,
          )

          let new_distance = case amount, dir {
            model.Ones, model.Forward -> current_distance +. 1.0
            model.Ones, model.Backward -> current_distance -. 1.0
            model.Tens, model.Forward -> current_distance +. 10.0
            model.Tens, model.Backward -> current_distance -. 10.0
            model.Tenths, model.Forward -> current_distance +. 0.1
            model.Tenths, model.Backward -> current_distance -. 0.1
          }
          ef.just(Settings(
            st,
            settings: SettingsState(
              ..ss,
              travel_distance_input: validate(
                float.to_string(new_distance),
                parsers.pos_float() |> p.conv,
              ),
            ),
          ))
        }
        _ -> ef.just(model)
      }
    }
  }
}
