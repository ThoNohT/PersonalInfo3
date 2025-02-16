import gleam/float
import gleam/int
import gleam/list
import gleam/option.{is_some}

import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre/attribute as a

import util/time
import model.{type DayEvent, ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type State, Loading, Loaded,
  TimeChanged, TargetChanged}

fn day_item_card(event: DayEvent) {
  let body = case event {
    ClockEvent(time, _, in) ->  {
      let prefix = case in { True -> "In:" False -> "Out:" }
      [ eh.b([ a.class("card-title") ], [ e.text(prefix) ]) 
      , eh.p([], [ e.text(int.to_string(time.hours) <> ":" <> int.to_string(time.minutes)) ])
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

fn day_item_list(day_state: DayState) {
  eh.div([ a.class("col-6") ], 
    [ eh.h5([], [e.text("Events this day")] )
    , eh.div([], day_state.events |> list.map(day_item_card))
  ])
}

fn text_input(name, label, value, is_valid, invalid_message, input_message, parsed_result) {
  eh.div([ a.class("row container justify-content-start") ], 
  [ eh.label([ a.for(name <> "-input"), a.class("col-1 form-label")], [ e.text(label) ])
  ,  eh.div([ a.class("col-4") ],
    [ eh.input(
      [ a.type_("text") , a.class("form-control time-form") , a.id(name <> "-input")
      , a.value(value)
      , a.classes([ #("is-invalid", !is_valid), #("is-valid", is_valid) ] )
      , ev.on_input(input_message)
      ])

    , eh.div([ a.class("invalid-feedback") ], [ e.text(invalid_message) ])
    ])
  , eh.div([ a.class("col-7") ], [ e.text(parsed_result |> option.unwrap("-")) ])
  ])
}

fn input_area(is: InputState) {
  eh.div([ a.class("col-6") ], 
  [ eh.div([ a.class("card-body") ],
    [ eh.h5([], [e.text("Input")] )
    , text_input("time", "Time:", is.time_input, is.parsed_time |> is_some, "Invalid time format.", TimeChanged, option.map(is.parsed_time, time.time_to_time_string))
    , text_input("target", "Target:", is.target_input, is.parsed_target |> is_some, "Invalid hours format.", TargetChanged, option.map(is.parsed_target, time.duration_to_unparsed_format_string))
    ])
  ])
}

pub fn view(model: State) {
  case model {
    Loading -> eh.div([], [ e.text("Loading...") ])
    Loaded(_, st, _, is) -> eh.div([ a.class("container row mx-auto") ],
      [ day_item_list(st)
      , input_area(is),
      ])
  }
}

