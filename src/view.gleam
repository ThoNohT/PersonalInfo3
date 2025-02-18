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
  TimeInputChanged, HolidayInputChanged, TargetChanged}

fn day_item_card(event: DayEvent) {
  let body = case event {
    ClockEvent(time, _, in) ->  {
      let prefix = case in { True -> "In:" False -> "Out:" }
      [ eh.b([ a.class("px-1") ], [ e.text(prefix) ]) 
      , eh.span([ a.class("px-1") ], [ e.text(time.time_to_time_string(time)) ])
      ]
    }
    HolidayBooking(amount) -> {
      [ eh.b([ a.class("px-1")  ], [ e.text("Holiday: ") ]) 
      , eh.span([ a.class("px-1")  ], [ e.text(float.to_string(amount)) ])
      ]
    }
  }
  eh.div(
    [ a.class("list-item border border-2 rounded-3 m-1 p-1 d-flex flex-row") ], 
    body)
}

fn day_item_list(day_state: DayState, is: InputState) {
  eh.div([ a.class("col-6") ], 
    [ eh.h5([], [e.text("Day")] )
    , text_input("target", "Day target:", is.target_input, is.parsed_target |> is_some, "Invalid format.", TargetChanged, day_state.target |> time.duration_to_unparsed_format_string |> Some)
    , eh.div([], day_state.events |> list.map(day_item_card))
  ])
}

fn text_input(name, label, value, is_valid, invalid_message, input_message, parsed_result) {
  eh.div([ a.class("row container justify-content-start") ], 
  [ eh.label([ a.for(name <> "-input"), a.class("col-2 px-0 py-2")], [ e.text(label) ])

  , eh.div([ a.class("col-10") ],
    [ eh.input(
      [ a.type_("text") , a.class("form-control time-form") , a.id(name <> "-input")
      , a.value(value)
      , a.classes([ #("is-invalid", !is_valid), #("is-valid", is_valid) ] )
      , ev.on_input(input_message)
      ])
    , eh.div([ a.class("invalid-feedback") ], [ e.text(invalid_message) ])
    , eh.div([ a.class("valid-feedback") ], [ e.text(parsed_result |> option.unwrap("-")) ])
    ])
  ])
}

fn input_area(is: InputState) {
  eh.div([ a.class("col-6") ], 
  [ eh.div([ a.class("card-body") ],
    [ eh.h5([], [e.text("Input")] )
    , text_input("time", "Clock:", is.time_input, is.parsed_time |> is_some, "Invalid time.", TimeInputChanged, option.map(is.parsed_time, time.time_to_time_string))
    , eh.div([ a.class("row") ],
      [ eh.button([ a.class("col-5 btn btn-sm btn-outline-primary m-2") ], [ e.text("Add clock event") ])
      , eh.button([ a.class("col-5 btn btn-sm btn-outline-primary m-2") ], [ e.text("Toggle Home") ])
      ])
    , text_input("holiday", "Holiday:", is.holiday_input, is.parsed_holiday |> is_some, "Invalid duration.", HolidayInputChanged, option.map(is.parsed_holiday, time.duration_to_unparsed_format_string))
    , eh.div([ a.class("row") ],
      [ eh.button([ a.class("col-5 btn btn-sm btn-outline-primary m-2") ], [ e.text("Gain Holiday") ])
      , eh.button([ a.class("col-5 btn btn-sm btn-outline-primary m-2") ], [ e.text("Use Holiday") ])
      ])
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

