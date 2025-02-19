import gleam/list
import gleam/option.{None, Some}
import gleam/string

import birl

import lustre
import lustre/effect

import util/effect as ef
import util/time.{Time, Duration, DecimalFormat, TimeFormat}
import model.{ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type State, Loading, Loaded,
  type Msg, LoadState, TimeInputChanged, HolidayInputChanged, TargetChanged, SelectListItem,
  Validated, validate, unvalidated}
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
  let today = birl.get_day(birl.now())

  case model, msg {
    Loading, LoadState -> {
        let events =
        [ ClockEvent(0, Time(1, 0), True, True)
        , HolidayBooking(1, Duration(12, 5, Some(DecimalFormat)))
        , HolidayBooking(2, Duration(1, 0, Some(TimeFormat)))
        ]
        let current_state = DayState(date: today, target: Duration(8, 0, Some(time.DecimalFormat)), events:)
        let input_state = InputState(
          clock_input: unvalidated(),
          holiday_input: unvalidated(),
          target_input: Validated(time.duration_to_decimal_string(current_state.target, 2), Some(current_state.target))
        )
        let selected_event = list.first(events) |> option.from_result
        ef.just(Loaded(today:, current_state:, selected_event:, week_target: 40.0, input_state:))
    }
    Loaded(input_state: is, ..) as st, TimeInputChanged(new_time) -> {
      let input_state = InputState(..is,
        clock_input: validate(string.slice(new_time, 0, 5), time.parse_time))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(input_state: is, ..) as st, HolidayInputChanged(new_duration) -> {
      let input_state = InputState(..is,
        holiday_input: validate(string.slice(new_duration, 0, 6), time.parse_duration))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(current_state: cs, input_state: is, ..) as st, TargetChanged(new_target) -> {
      let target_input = validate(string.slice(new_target, 0, 6), time.parse_duration)
      let input_state = InputState(..is, target_input:)
      let current_state = case target_input.parsed { None -> cs Some(target) -> DayState(..cs, target:) }
      ef.just(Loaded(..st, current_state:, input_state:))
    }
    Loaded(current_state: cs, input_state: is, ..) as st, SelectListItem(idx) -> {
      let selected_event = cs.events |> list.drop(idx) |> list.first |> option.from_result
      let input_state = case selected_event {
        Some(ClockEvent(..) as ce) -> InputState(..is, clock_input: validate(time.time_to_time_string(ce.time), time.parse_time))
        Some(HolidayBooking(..) as hb) -> InputState(..is, holiday_input: validate(time.duration_to_time_string(hb.amount), time.parse_duration))
        None -> is
      }
      ef.just(Loaded(..st, selected_event:, input_state:))
    }
    Loaded(current_state: cs, ..) as st, model.DeleteListItem(idx) -> {
      let #(before, after) = cs.events |> list.split(idx)
      case after {
        [ _, ..af ] -> {
          // Takes out the element at idx.
          let current_state = DayState(..cs, events: list.append(before, af) |> model.recalculate_events)
          #(Loaded(..st, current_state:), ef.dispatch(SelectListItem(idx - 1)))
        }
        _ -> ef.just(st)
      }
    }
    _, _ -> ef.just(model)
  }
}

// fn checkbox_input(name) -> e.Element(a) {
//   eh.div([],
//     [ eh.div([], [ eh.input([ a.type_("checkbox") ]) ])
//     , eh.div([], [ e.text(name) ])
//     ])
// }
