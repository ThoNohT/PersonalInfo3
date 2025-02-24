import gleam/list
import gleam/option.{None, Some}
import gleam/string

import lustre
import lustre/effect

import util/effect as ef
import util/time
import util/numbers.{Pos}
import util/duration.{Duration, DecimalFormat}
import model.{
  Office, In,
  ClockEvent, HolidayBooking,
  type DayState, DayState, DayStatistics,
  type InputState, InputState,
  type State, Loading, Loaded,
  type Msg, LoadState, Tick, TimeInputChanged, HolidayInputChanged, TargetChanged, LunchChanged,
  SelectListItem, DeleteListItem, ToggleHome, AddClockEvent, AddHolidayBooking,
  validate, unvalidated}
import view.{view}

fn dispatch_message(message message) -> effect.Effect(message) {
  effect.from(fn(dispatch) { dispatch(message) })
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_) {
  #(Loading, dispatch_message(LoadState))
}

fn update(model: State, msg: Msg) {
  case model {
    // Loading.
    Loading -> {
      case msg {
        LoadState -> {
          let today = time.today()
          let now = time.now()
  
          let events = []
          let stats = DayStatistics(eta: duration.zero(), total: duration.zero(), total_office: duration.zero(), total_home: duration.zero(), remaining_holiday: duration.zero())
          let current_state = DayState(date: today, target: Duration(8, 0, Pos, Some(DecimalFormat)), lunch: True, events:, stats:) |> model.recalculate_statistics(now, today)
          let input_state = InputState(
            clock_input: unvalidated(),
            holiday_input: unvalidated(),
            target_input: validate(duration.to_decimal_string(current_state.target, 2), duration.parse)
          )
          #(Loaded(today:, now:, current_state:, selected_event: None, week_target: Duration(40, 0, Pos, Some(DecimalFormat)), input_state:)
          , effect.batch([ ef.dispatch(SelectListItem(0)), ef.every(1000, Tick) ]))
        }
        _ -> ef.just(model)
      }
    }

    // Loaded.
    Loaded(now:, today:, ..) as st -> {
      let recalc_stats = fn(stats) { model.recalculate_statistics(stats, now, today) }
      
      case msg {
        Tick -> {
          let today = time.today()
          let now = time.now()

          // Only update if the time changed to the precision we observe it (minutes).
          use _ <- ef.check(st, now != st.now)
          ef.just(Loaded(..st, today:, now:, current_state: st.current_state |> model.recalculate_statistics(now, today)))
        }
        TimeInputChanged(new_time) -> {
          let input_state = InputState(..st.input_state,
            clock_input: validate(string.slice(new_time, 0, 5), time.parse))
          ef.just(Loaded(..st, input_state:))
        }
        HolidayInputChanged(new_duration) -> {
          let input_state = InputState(..st.input_state,
            holiday_input: validate(string.slice(new_duration, 0, 6), duration.parse))
          ef.just(Loaded(..st, input_state:))
        }
        TargetChanged(new_target) -> {
          let target_input = validate(string.slice(new_target, 0, 6), duration.parse)
          let input_state = InputState(..st.input_state, target_input:)
          let current_state = case target_input.parsed {
            None -> st.current_state
            Some(target) -> DayState(..st.current_state, target:)
          } |> recalc_stats
          ef.just(Loaded(..st, current_state:, input_state:))
        }
        LunchChanged(new_lunch) -> {
          let current_state = DayState(..st.current_state, lunch: new_lunch) |> recalc_stats
          ef.just(Loaded(..st, current_state:))
        }
        SelectListItem(idx) -> {
          let selected_event = st.current_state.events |> list.drop(idx) |> list.first |> option.from_result
          let input_state = case selected_event {
            Some(ClockEvent(..) as ce) -> InputState(..st.input_state, clock_input: validate(time.to_string(ce.time), time.parse))
            Some(HolidayBooking(..) as hb) -> InputState(..st.input_state, holiday_input: validate(duration.to_time_string(hb.amount), duration.parse))
            None -> st.input_state
          }
          ef.just(Loaded(..st, selected_event:, input_state:))
        }
        DeleteListItem(idx) -> {
          let #(before, after) = st.current_state.events |> list.split(idx)
          case after {
            [ _, ..af ] -> {
              // Takes out the element at idx.
              let current_state = DayState(..st.current_state, events: list.append(before, af) |> model.recalculate_events) |> recalc_stats
              ef.just(Loaded(..st, current_state:))
            }
            _ -> ef.just(st)
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
          let current_state = DayState(..st.current_state, events: new_events |> model.recalculate_events) |> recalc_stats
          ef.just(Loaded(..st, current_state:))
        }
        AddClockEvent -> {
          use time <- ef.then(st, st.input_state.clock_input.parsed)
          use _ <- ef.check(st, !model.daystate_has_clock_event_at(st.current_state, time))

          let new_event = ClockEvent(list.length(st.current_state.events), time, Office, In)
          let events = [ new_event, ..st.current_state.events ] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:) |> recalc_stats
          ef.just(Loaded(..st, current_state:))
        }
        AddHolidayBooking(kind) -> {
          use duration <- ef.then(st, st.input_state.holiday_input.parsed)

          let new_event = HolidayBooking(list.length(st.current_state.events), duration, kind)
          let events = [ new_event, ..st.current_state.events ] |> model.recalculate_events
          let current_state = DayState(..st.current_state, events:) |> recalc_stats
          ef.just(Loaded(..st, current_state:))
        }
        _ -> ef.just(model)
      }
    }
  }
}
