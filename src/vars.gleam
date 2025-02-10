import birl.{type TimeOfDay, type Day}

import lustre
import lustre/effect
import lustre/element.{text}
import lustre/element/html.{div}

fn dispatch_message(message message) -> effect.Effect(message) {
  effect.from(fn(dispatch) { dispatch(message) })
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) {
  #(Loading, dispatch_message(LoadState))
}

type DayEvent {
  ClockEvent(time: TimeOfDay, home: Bool)
  HolidayBooking(amount: Float)
}

type DayState {
  DayState(date: Day, target: Float, events: List(DayEvent))
}

type State {
  Loading
  Loaded(today: Day, current_state: DayState, week_target: Float)
}

type Msg {
  LoadState
}

fn update(model, msg) {
  let today = birl.get_day(birl.now())

  case model, msg {
    Loading, LoadState -> {
        let state = DayState(date: today, target: 8.0, events: [])
        #(Loaded(today: today, current_state: state, week_target: 40.0), effect.none())
    }
    _, _ -> #(model, effect.none())
  }
}

fn view(model) {
  case model {
    Loading -> div([], [ text("Loading...")])
    Loaded(_, _, _) -> div([], [ text("Loaded")])
  }
}
