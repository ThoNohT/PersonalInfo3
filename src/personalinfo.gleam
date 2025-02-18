import gleam/option.{None, Some}
import gleam/string

import birl

import lustre
import lustre/effect

import util/effect as ef
import util/time.{Time, Duration}
import model.{ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type State, Loading, Loaded,
  type Msg, LoadState, TimeInputChanged, HolidayInputChanged, TargetChanged,
  Validated, validate}
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
        [ ClockEvent(Time(1, 0), True, True)
        , HolidayBooking(12.5)
        ]
        let current_state = DayState(date: today, target: Duration(8, 0, Some(time.DecimalFormat)), events:)
        let input_state = InputState(
          clock_input: Validated("", None),
          holiday_input: Validated("", None),
          target_input: Validated(time.duration_to_decimal_string(current_state.target, 2), Some(current_state.target))
        )
        ef.just(Loaded(today:, current_state:, week_target: 40.0, input_state:))
    }
    Loaded(..) as st, TimeInputChanged(new_time) -> {
      let new_time = string.slice(new_time, 0, 5)
      let input_state = InputState(..st.input_state, clock_input: validate(new_time, time.parse_time))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(..) as st, HolidayInputChanged(new_duration) -> {
      let new_duration = string.slice(new_duration, 0, 6)
      let input_state = InputState(..st.input_state, holiday_input: validate(new_duration, time.parse_duration))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(..) as st, TargetChanged(new_target) -> {
      let new_target = string.slice(new_target, 0, 6)
      let target_input = validate(new_target, time.parse_duration)
      let input_state = InputState(..st.input_state, target_input:)
      let current_state = case target_input.parsed {
        None -> st.current_state
        Some(target) -> DayState(..st.current_state, target:)
      }
      ef.just(Loaded(..st, current_state:, input_state:))
    }
    _, _ -> ef.just(model)
  }
}

// fn checkbox_input(name) -> e.Element(a) {
//   eh.div([],
//     [ eh.div([], [ eh.input([a.type_("checkbox")]) ])
//     , eh.div([], [ e.text(name) ])
//     ])
// }
