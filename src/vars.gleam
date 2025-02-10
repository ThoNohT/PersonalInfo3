import birl.{type TimeOfDay, type Day}

import lustre
import lustre/effect
import lustre/element.{text}
import lustre/element/html.{div}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) {
  #(Loading, effect.none())
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
  State(today: Day, current_state: DayState, week_target: Float)
}

type Msg {
  Incr
  Decr
}

fn update(model, msg) {
  case msg {
    Incr -> #(model, effect.none())
    Decr -> #(model, effect.none())
  }
}

fn view(model) {
  case model {
    Loading -> div([], [ text("Loading...")])
    State(_, _, _) -> div([], [ text("Loaded..")])
  }
}
