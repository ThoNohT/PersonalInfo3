import gleam/option.{None}
import gleam/string

import birl

import lustre
import lustre/effect

import util/effect as ef
import util/time.{Time}
import model.{ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type State, Loading, Loaded,
  type Msg, LoadState, TimeChanged, TargetChanged}
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
        let current_state = DayState(date: today, target: 8.0, events:)
        let input_state = InputState(time_input: "", parsed_time: None, target_input: "", parsed_target: None)
        ef.just(Loaded(today:, current_state:, week_target: 40.0, input_state:))
    }
    Loaded(..) as st, TimeChanged(new_time) -> {
      let new_time = string.slice(new_time, 0, 5)
      let input_state = InputState(..st.input_state, time_input: new_time, parsed_time: time.parse_time(new_time))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(..) as st, TargetChanged(new_target) -> {
      let new_target = string.slice(new_target, 0, 6)
      let input_state = InputState(..st.input_state, target_input: new_target, parsed_target: time.parse_duration(new_target))
      ef.just(Loaded(..st, input_state:))
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
