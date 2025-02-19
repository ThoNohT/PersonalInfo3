import gleam/list
import gleam/option.{type Option, Some}

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
  TimeInputChanged, HolidayInputChanged, TargetChanged, SelectListItem,
  type Validated, is_valid}

fn day_item_card(selected_item: Option(Int), event: DayEvent) {
  case event {
    ClockEvent(idx, time, _, in) -> {
      let prefix = case in { True -> "In:" False -> "Out:" }
      eh.div(
        [ a.class("list-item border border-2 rounded-3 m-1 p-1 d-flex flex-row")
        , a.classes([ #("selected", Some(event.index) == selected_item) ])
        , ev.on_click(SelectListItem(idx)) 
        ],
        [ eh.b([ a.class("px-1") ], [ e.text(prefix) ])
        , eh.span([ a.class("px-1") ], [ e.text(time.time_to_time_string(time)) ])
        ])
    }
    HolidayBooking(idx, amount) -> {
      eh.div(
        [ a.class("list-item border border-2 rounded-3 m-1 p-1 d-flex flex-row")
        , a.classes([ #("selected", Some(event.index) == selected_item) ])
        , ev.on_click(SelectListItem(idx))
        ],
        [ eh.b([ a.class("px-1") ], [ e.text("Holiday: ") ])
        , eh.span([ a.class("px-1") ], [ e.text(time.duration_to_unparsed_format_string(amount)) ])
        ])
    }
  }
}

fn day_item_list(day_state: DayState, is: InputState, selected_index: Option(Int)) {
  eh.div([ a.class("col-6") ],
    [ eh.h5([], [ e.text("Day") ] )
    , text_input("target", "Day target:", is.target_input, "Invalid format.", TargetChanged, time.duration_to_unparsed_format_string)
    , eh.div([], day_state.events |> list.map(day_item_card(selected_index, _)))
    ])
}

fn text_input(name, label, value: Validated(a), invalid_message, input_message, parsed_to_string) {
  eh.div([ a.class("row container justify-content-start") ],
  [ eh.label([ a.for(name <> "-input"), a.class("col-2 px-0 py-2") ], [ e.text(label) ])

  , eh.div([ a.class("col-10") ],
    [ eh.input(
      [ a.type_("text") , a.class("form-control time-form") , a.id(name <> "-input")
      , a.value(value.input)
      , a.classes([ #("is-invalid", !is_valid(value)), #("is-valid", is_valid(value)) ] )
      , ev.on_input(input_message)
      ])
    , eh.div([ a.class("invalid-feedback") ], [ e.text(invalid_message) ])
    , eh.div([ a.class("valid-feedback") ], [ e.text(value.parsed |> option.map(parsed_to_string) |> option.unwrap("-")) ])
    ])
  ])
}

fn input_area(is: InputState) {
  eh.div([ a.class("col-6") ],
  [ eh.div([ a.class("card-body") ],
    [ eh.h5([], [ e.text("Input") ] )
    , text_input("clock", "Clock:", is.clock_input, "Invalid time.", TimeInputChanged,  time.time_to_time_string)
    , eh.div([ a.class("row") ],
      [ eh.button([ a.class("col-5 btn btn-sm btn-outline-primary m-2") ], [ e.text("Add clock event") ])
      , eh.button([ a.class("col-5 btn btn-sm btn-outline-primary m-2") ], [ e.text("Toggle Home") ])
      ])
    , text_input("holiday", "Holiday:", is.holiday_input, "Invalid duration.", HolidayInputChanged, time.duration_to_unparsed_format_string)
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
    Loaded(_, st, se, _, is) -> {
      let selected_index = se |> option.map(fn(e: DayEvent) { e.index })
      eh.div([ a.class("container row mx-auto") ],
        [ day_item_list(st, is, selected_index)
        , input_area(is),
        ])
    }
  }
}

