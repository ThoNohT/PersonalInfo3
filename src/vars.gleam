import gleam/list
import gleam/float

import birl.{type TimeOfDay, type Day}

import lustre
//import lustre/attribute
import lustre/effect
import lustre/element as e
import lustre/element/html as eh
import lustre/attribute as a

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
  ClockEvent(time: TimeOfDay, home: Bool, in: Bool)
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
        let events = 
        [ ClockEvent(birl.get_time_of_day(birl.now()), True, True)
        , HolidayBooking(12.5)
        ]
        let state = DayState(date: today, target: 8.0, events:)
        #(Loaded(today: today, current_state: state, week_target: 40.0), effect.none())
    }
    _, _ -> #(model, effect.none())
  }
}

// fn text_input(name) -> e.Element(a) {
//   eh.div([],
//     [ eh.div([], [ e.text(name <> ":") ])
//     , eh.div([], [ eh.input([]) ]) 
//     ])
// }
// 
// fn checkbox_input(name) -> e.Element(a) {
//   eh.div([],
//     [ eh.div([], [ eh.input([a.type_("checkbox")]) ])
//     , eh.div([], [ e.text(name) ])
//     ])
// }

fn day_item_card(event: DayEvent) -> e.Element(a) {
  let body = case event {
    ClockEvent(time, _, in) ->  {
      let prefix = case in { True -> "In:" False -> "Out:" }
      [ eh.b([ a.class("card-title") ], [ e.text(prefix) ]) 
      , eh.p([], [ e.text(birl.time_of_day_to_short_string(time)) ])
      ]
    }
    HolidayBooking(amount) -> {
      [ eh.b([ a.class("card-title") ], [ e.text("Holiday") ]) 
      , eh.p([], [ e.text(float.to_string(amount)) ])
      ]
    }
  }
  eh.div(
    [ a.class("card") ], 
    [ eh.div( [ a.class("card-body") ], body)
    ])
}

fn day_item_list(day_state: DayState) -> e.Element(a) {
  eh.div([ a.class("card") ], 
  [ eh.div([ a.class("card-body") ],
    [ eh.h5([], [e.text("Events this day")] )
    , eh.div([], day_state.events |> list.map(day_item_card))
    ])
  ])
}

fn view(model) {
  case model {
    Loading -> eh.div([], [ e.text("Loading...") ])
    Loaded(_, st, _) -> eh.div([ a.class("container") ],
      [ day_item_list(st)
      ])
  }
}
