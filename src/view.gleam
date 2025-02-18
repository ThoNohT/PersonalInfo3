import gleam/float
import gleam/list
import gleam/option.{Some, is_some}

import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre/attribute as a

import util/time
import model.{
  type DayEvent, ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type State, Loading, Loaded,
  TimeChanged, TargetChanged}

fn day_item_card(event: DayEvent) {
  let body = case event {
    ClockEvent(time, _, in) ->  {
      let prefix = case in { True -> "In:" False -> "Out:" }
      [ eh.b([ a.class("card-title") ], [ e.text(prefix) ]) 
      , eh.p([], [ e.text(time.time_to_time_string(time)) ])
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

fn day_item_list(day_state: DayState, is: InputState) {
  eh.div([ a.class("col-6") ], 
    [ eh.h5([], [e.text("Day")] )
    , text_input("target", "Day target:", is.target_input, is.parsed_target |> is_some, "Invalid hours format.", TargetChanged, day_state.target |> time.duration_to_unparsed_format_string |> Some)
    , eh.div([], day_state.events |> list.map(day_item_card))
  ])
}

fn text_input(name, label, value, is_valid, invalid_message, input_message, parsed_result) {
  eh.div([ a.class("row container justify-content-start") ], 
  [ eh.label([ a.for(name <> "-input"), a.class("col-2 form-label")], [ e.text(label) ])
  ,  eh.div([ a.class("col-4") ],
    [ eh.input(
      [ a.type_("text") , a.class("form-control time-form") , a.id(name <> "-input")
      , a.value(value)
      , a.classes([ #("is-invalid", !is_valid), #("is-valid", is_valid) ] )
      , ev.on_input(input_message)
      ])

    , eh.div([ a.class("invalid-feedback") ], [ e.text(invalid_message) ])
    ])
  , eh.div([ a.class("col-6") ], [ e.text(parsed_result |> option.unwrap("-")) ])
  ])
}

fn input_area(is: InputState) {
  eh.div([ a.class("col-6") ], 
  [ eh.div([ a.class("card-body") ],
    [ eh.h5([], [e.text("Input")] )
    , text_input("time", "Time:", is.time_input, is.parsed_time |> is_some, "Invalid time format.", TimeChanged, option.map(is.parsed_time, time.time_to_time_string))
    ])
  ])
}

pub fn view(model: State) {
  case model {
    Loading -> eh.div([], [ e.text("Loading...") ])
    Loaded(_, st, _, is) -> eh.div([ a.class("container row mx-auto") ],
      [ day_item_list(st, is)
      , input_area(is),
      ])
  }
}

