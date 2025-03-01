import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import birl.{type Day}
import lustre
import lustre/effect
import lustre_http as http

import util/day
import util/duration
import util/effect as ef
import util/time.{type Time}
import parsing
import model.{
  Office, In,
  ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type Model, Loading, Loaded, Err,
  type State, State,
  type Msg, LoadState, Tick, TimeInputChanged, HolidayInputChanged, TargetChanged, LunchChanged,
  SelectListItem, DeleteListItem, ToggleHome, AddClockEvent, AddHolidayBooking,
  PrevDay, NextDay,
  validate, unvalidated}
import view.{view}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_) {
  #(Loading, http.get("http://localhost:5500/state.txt", http.expect_text(LoadState)))
}

fn update(model: Model, msg: Msg) {
  case model {
    // Loading.
    Err(_) -> ef.just(model)
    Loading -> {
      case msg {
        LoadState(result) -> {
          case result {
            Error(_) -> ef.just(Err("Could not load state."))
            Ok(res) -> {
              let today = time.today()
              let now = time.now()

              let state = load_state(res, today, now)
              #(Loaded(state), effect.batch([ ef.dispatch(SelectListItem(0)), ef.every(1000, Tick) ]))
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
          use _ <- check(now != st.now)
          ef.just(Loaded(State(..st, today:, now:) |> model.update_history |> model.recalculate_statistics))
        }
        TimeInputChanged(new_time) -> {
          let input_state = InputState(..st.input_state,
            clock_input: validate(string.slice(new_time, 0, 5), time.parse))
          ef.just(Loaded(State(..st, input_state:)))
        }
        HolidayInputChanged(new_duration) -> {
          let input_state = InputState(..st.input_state,
            holiday_input: validate(string.slice(new_duration, 0, 6), duration.parse))
          ef.just(Loaded(State(..st, input_state:)))
        }
        TargetChanged(new_target) -> {
          let target_input = validate(string.slice(new_target, 0, 6), duration.parse)
          let input_state = InputState(..st.input_state, target_input:)
          let current_state = case target_input.parsed {
            None -> st.current_state
            Some(target) -> DayState(..st.current_state, target:)
          }
          ef.just(Loaded(State(..st, current_state:, input_state:) |> model.update_history |> model.recalculate_statistics))
        }
        LunchChanged(new_lunch) -> {
          let current_state = DayState(..st.current_state, lunch: new_lunch)
          ef.just(Loaded(State(..st, current_state:) |> model.update_history |> model.recalculate_statistics))
        }
        SelectListItem(idx) -> {
          let selected_event = st.current_state.events |> list.drop(idx) |> list.first |> option.from_result
          let selected_idx = selected_event |> option.map(fn(e) { e.index })
          let input_state = case selected_event {
            Some(ClockEvent(..) as ce) -> InputState(..st.input_state, clock_input: validate(time.to_string(ce.time), time.parse))
            Some(HolidayBooking(..) as hb) -> InputState(..st.input_state, holiday_input: validate(duration.to_time_string(hb.amount), duration.parse))
            None -> st.input_state
          }
          ef.just(Loaded(State(..st, selected_event_index: selected_idx, input_state:)))
        }
        DeleteListItem(idx) -> {
          let #(before, after) = st.current_state.events |> list.split(idx)
          case after {
            [ _, ..af ] -> {
              // Takes out the element at idx.
              let current_state = DayState(..st.current_state, events: list.append(before, af) |> model.recalculate_events)
              ef.just(Loaded(State(..st, current_state:) |> model.update_history |> model.recalculate_statistics))
            }
            _ -> ef.just(model)
          }
        }
        ToggleHome(idx) -> {
          let toggle_home = fn(e) {
            case e {
              ClockEvent(index: index, location:loc, ..) as ce if idx == index ->
                ClockEvent(..ce, location: model.switch_location(loc))
              _ -> e
            }
          }

          let new_events = st.current_state.events |> list.map(toggle_home)
          let current_state = DayState(..st.current_state, events: new_events |> model.recalculate_events)
          ef.just(Loaded(State(..st, current_state:) |> model.update_history |> model.recalculate_statistics))
        }
        AddClockEvent -> {
          use time <- then(st.input_state.clock_input.parsed)
          use _ <- check(!model.daystate_has_clock_event_at(st.current_state, time))

          let new_event = ClockEvent(list.length(st.current_state.events), time, Office, In)
          let events = [ new_event, ..st.current_state.events ] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:)
          ef.just(Loaded(State(..st, current_state:) |> model.update_history |> model.recalculate_statistics))
        }
        AddHolidayBooking(kind) -> {
          use duration <- then(st.input_state.holiday_input.parsed)

          let new_event = HolidayBooking(list.length(st.current_state.events), duration, kind)
          let events = [ new_event, ..st.current_state.events ] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:)
          ef.just(Loaded(State(..st, current_state:) |> model.update_history |> model.recalculate_statistics))
        }
        PrevDay(_modifiers) -> {
          let to_day = day.prev(st.current_state.date)
          // TODO: Modifiers step in bigger increments, but only so far as there is recorded history.

          // Find the day in the state history. If it is not in there, create a new one and prepend it.
          // This will prevent gaps in the list since we can only step by one day at a time, once we have reached the
          // start of the history.
          let state = case st.history {
            [ first, ..] if first.date == st.current_state.date -> {
              // We were at the first element, prepend one.
              let current_state = DayState(date: to_day, target: duration.hours(8), lunch: True, events: [])
              State(..st, current_state:, history: [current_state, ..st.history])
                |> model.recalculate_statistics
            }
            _ -> {
              let assert Ok(current_state) = list.find(st.history, fn(s: DayState) { s.date == to_day })
              State(..st, current_state:) |> model.recalculate_statistics
            }
          }

          let input_state = InputState(..state.input_state,
            target_input: validate(duration.to_decimal_string(state.current_state.target, 2), duration.parse)
          )
          ef.just(Loaded(State(..state, input_state:)))
        }
        NextDay(_modifiers) -> {
          // TODO: Modifiers step in bigger increments, but only so far as there is recorded history.

          let to_day = day.next(st.current_state.date)
          let state = case list.find(st.history, fn(s: DayState) { s.date == to_day }) {
            Ok(current_state) -> {
              // If the next day is in the list, simply switch to it.
              let state = State(..st, current_state:) |> model.recalculate_statistics
              state
            }
            Error(_) -> {
              // If it is not in the list we must be heading to the next day from the end of the list, since we only
              // allow stepping ahead of the last item in the history by one day.
              let current_state = DayState(date: to_day, target: duration.hours(8), lunch: True, events: [])
              let state = State(..st, current_state:, history: list.append(st.history, [ current_state ]))
                |> model.recalculate_statistics
              state
            }
          }

          let input_state = InputState(..state.input_state,
            target_input: validate(duration.to_decimal_string(state.current_state.target, 2), duration.parse)
          )
          ef.just(Loaded(State(..state, input_state:)))
        }
        _ -> ef.just(model)
      }
    }
  }
}

fn load_state(input: String, today: Day, now: Time) -> State {
  // TODO: Proper handling of failing to parse.
  let assert Some(state_input) = parsing.parse_state_input(input)

  // Fixed values:
  let input_state = InputState(unvalidated(), unvalidated(), unvalidated())
  let selected_event_index = None
  let stats = model.stats_zero()

  let current_state = DayState(date: today, target: duration.hours(8), lunch: True, events: [])
  State(
    today:, now:, current_state:, stats:, selected_event_index:, input_state:,
    history: state_input.history |> list.map(fn(d) { DayState(..d, events: d.events |> model.recalculate_events) }),
    week_target: state_input.week_target,
    travel_distance: state_input.travel_distance) |> model.recalculate_statistics
}
