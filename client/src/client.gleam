import gleam/float
import gleam/http as ghttp
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import util/site

import birl.{type Day}
import lustre
import lustre/effect
import lustre_http as http

import model.{
  type DayState, type InputState, type Model, type Msg, type State,
  AddClockEvent, AddHolidayBooking, ApplySettings, CancelSettings, ChangeDay,
  ClockEvent, DayState, DeleteListItem, Err, HolidayBooking, HolidayInputChanged,
  HolidayInputKeyDown, In, InputState, LoadState, Loaded, Loading, Login,
  LoginResult, LunchChanged, Office, OpenSettings, PasswordChanged,
  SelectListItem, Settings, SettingsState, State, TargetChanged, TargetKeyDown,
  Tick, TimeInputChanged, TimeInputKeyDown, ToggleHome, TravelDistanceChanged,
  TravelDistanceKeyDown, TryLogin, UsernameChanged, WeekTargetChanged,
  WeekTargetKeyDown, unvalidated, validate,
}
import parsing
import shared_model.{type Credentials, type SessionInfo, Credentials}
import util/duration
import util/effect as ef
import util/time.{type Time}
import view.{view}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_) {
  #(Login(Credentials("", ""), False), effect.none())
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
  let stats = model.stats_zero()

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
    |> model.recalculate_statistics

  let input_state =
    InputState(
      ..input_state,
      target_input: validate(
        duration.to_decimal_string(state.current_state.target, 2),
        duration.parse,
      ),
    )
  State(..state, input_state:)
}

fn update(model: Model, msg: Msg) {
  case model {
    // Loading.
    Err(_) -> ef.just(model)
    Login(creds, _failed) -> {
      case msg {
        UsernameChanged(username) ->
          ef.just(Login(Credentials(..creds, username:), False))
        PasswordChanged(password) ->
          ef.just(Login(Credentials(..creds, password:), False))
        TryLogin -> {
          let base_url = site.base_url()
          #(
            model,
            http.post(
              base_url <> "/api/user/login",
              shared_model.encode_credentials(creds),
              http.expect_json(shared_model.session_info_decoder(), LoginResult),
            ),
          )
        }
        LoginResult(result) -> {
          use session <- ef.try(Login(creds, True), result)
          let request =
            site.request_with_authorization(
              site.base_url() <> "/api/simplestate/pi_history",
              ghttp.Get,
              session.session_id,
            )
          #(Loading(session), http.send(request, http.expect_text(LoadState)))
        }
        _ -> ef.just(model)
      }
    }

    // Loading.
    Loading(session) -> {
      case msg {
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
      let then = fn(opt: Option(a), cont) { ef.then(model, opt, cont) }
      let check = fn(cond, cont) { ef.check(model, cond, cont) }

      case msg {
        Tick -> {
          let today = time.today()
          let now = time.now()

          // Only update if the time changed to the precision we observe it (minutes).
          use <- check(now != st.now)
          ef.just(Loaded(
            State(..st, today:, now:)
            |> model.update_history
            |> model.recalculate_statistics,
          ))
        }
        TimeInputChanged(new_time) -> {
          let input_state =
            InputState(
              ..st.input_state,
              clock_input: validate(string.slice(new_time, 0, 5), time.parse),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        HolidayInputChanged(new_duration) -> {
          let input_state =
            InputState(
              ..st.input_state,
              holiday_input: validate(
                string.slice(new_duration, 0, 6),
                duration.parse,
              ),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        TargetChanged(new_target) -> {
          let target_input =
            validate(string.slice(new_target, 0, 6), duration.parse)
          let input_state = InputState(..st.input_state, target_input:)
          let current_state = case target_input.parsed {
            None -> st.current_state
            Some(target) -> DayState(..st.current_state, target:)
          }
          ef.just(Loaded(
            State(..st, current_state:, input_state:)
            |> model.update_history
            |> model.recalculate_statistics,
          ))
        }
        LunchChanged(new_lunch) -> {
          let current_state = DayState(..st.current_state, lunch: new_lunch)
          ef.just(Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> model.recalculate_statistics,
          ))
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
                clock_input: validate(time.to_string(ce.time), time.parse),
              )
            Some(HolidayBooking(..) as hb) ->
              InputState(
                ..st.input_state,
                holiday_input: validate(
                  duration.to_time_string(hb.amount),
                  duration.parse,
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
              ef.just(Loaded(
                State(..st, current_state:)
                |> model.update_history
                |> model.recalculate_statistics,
              ))
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
          ef.just(Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> model.recalculate_statistics,
          ))
        }
        AddClockEvent -> {
          use time <- then(st.input_state.clock_input.parsed)
          use <- check(
            !model.daystate_has_clock_event_at(st.current_state, time),
          )

          let new_event =
            ClockEvent(list.length(st.current_state.events), time, Office, In)
          let events =
            [new_event, ..st.current_state.events] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:)
          ef.just(Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> model.recalculate_statistics,
          ))
        }
        AddHolidayBooking(kind) -> {
          use duration <- then(st.input_state.holiday_input.parsed)

          let new_event =
            HolidayBooking(list.length(st.current_state.events), duration, kind)
          let events =
            [new_event, ..st.current_state.events] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:)
          ef.just(Loaded(
            State(..st, current_state:)
            |> model.update_history
            |> model.recalculate_statistics,
          ))
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
              State(..st, current_state:) |> model.recalculate_statistics
            Error(_) ->
              model.add_day_state(st, to_day) |> model.recalculate_statistics
          }

          let input_state =
            InputState(
              ..state.input_state,
              target_input: validate(
                duration.to_decimal_string(state.current_state.target, 2),
                duration.parse,
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
              clock_input: validate(time.to_string(to_time), time.parse),
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
                duration.parse,
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
                duration.parse,
              ),
            )
          ef.just(Loaded(State(..st, input_state:)))
        }
        OpenSettings -> {
          let week_target_input =
            model.validate(
              duration.to_time_string(st.week_target),
              duration.parse,
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
          ef.just(Loaded(
            State(..st, week_target:, travel_distance:)
            |> model.recalculate_statistics,
          ))
        }
        WeekTargetChanged(new_target) -> {
          let week_target_input =
            validate(string.slice(new_target, 0, 6), duration.parse)
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
                duration.parse,
              ),
            )
          ef.just(Settings(st, settings:))
        }
        TravelDistanceChanged(new_distance) -> {
          // TODO: Better parsing for floats.
          let travel_distance_input =
            validate(string.slice(new_distance, 0, 4), fn(x) {
              float.parse(x) |> option.from_result
            })
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
          // TODO: Better parsing for floats.
          ef.just(Settings(
            st,
            settings: SettingsState(
              ..ss,
              travel_distance_input: validate(
                float.to_string(new_distance),
                fn(x) { float.parse(x) |> option.from_result },
              ),
            ),
          ))
        }
        _ -> ef.just(model)
      }
    }
  }
}
