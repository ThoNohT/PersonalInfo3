import gleam/list
import gleam/option.{type Option, Some}

import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre/attribute as a

import util/time
import model.{
  In, Out, Home, Office,
  type DayEvent, ClockEvent, HolidayBooking,
  type DayState, DayState,
  type InputState, InputState,
  type State, Loading, Loaded,
  Gain, Use,
  TimeInputChanged, HolidayInputChanged, TargetChanged,
  SelectListItem, DeleteListItem, ToggleHome, AddClockEvent, AddHolidayBooking,
  type Validated, is_valid}

fn day_item_card(selected_index: Option(Int), event: DayEvent) {
  let body = case event {
    ClockEvent(_, time, _, kind) -> {
      let prefix = case kind { In -> "In:" Out -> "Out:" }
      [ eh.b([ a.class("px-1") ], [ e.text(prefix) ])
      , eh.span([ a.class("px-1") ], [ e.text(time.time_to_time_string(time)) ])
      ]
    }
    HolidayBooking(_, amount, kind) -> {
      let suffix = case kind { Gain -> " gained" Use -> " used" }
      [ eh.b([ a.class("px-1") ], [ e.text("Holiday: ") ])
      , eh.span([ a.class("px-1") ], [ e.text(time.duration_to_time_string(amount) <> suffix) ])
      ]
    }
  }

  let home_toggle = case event {
    ClockEvent(..) as ce if ce.kind == In -> {
      let txt = case ce.location { Home -> "Home" Office -> "Office" }
      eh.button([ a.class("btn btn-outline-secondary btn-sm me-1"), ev.on_click(ToggleHome(event.index)) ], [ e.text(txt) ])
    }
    _ -> e.none()
  }

  eh.div(
    [ a.class("list-item border border-2 rounded-3 m-1 p-1 d-flex flex-row justify-content-between")
    , a.classes([ #("selected", Some(event.index) == selected_index) ])
    ],
    [ eh.div([ a.class("d-flex flex-row flex-grow-1"), ev.on_click(SelectListItem(event.index)) ], body)
    , home_toggle
    , eh.button([ a.class("btn btn-outline-danger btn-sm"), ev.on_click(DeleteListItem(event.index)) ], [ e.text("X") ])
    ])
}

fn day_item_list(day_state: DayState, is: InputState, selected_index: Option(Int)) {
  eh.div([ a.class("col-6") ],
    [ eh.h5([], [ e.text("Day") ] )
    , text_input("target", "Target:", is.target_input, time.duration_to_unparsed_format_string(day_state.target), TargetChanged, time.duration_to_unparsed_format_string)
    , eh.div([], day_state.events |> list.map(day_item_card(selected_index, _)))
    ])
}

fn text_input(name, label, value: Validated(a), invalid_message, input_message, parsed_to_string) {
  eh.div([ a.class("col-6 row container justify-content-start") ],
  [ eh.label([ a.for(name <> "-input"), a.class("col-4 px-0 py-2") ], [ e.text(label) ])

  , eh.div([ a.class("col-8") ],
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
  let btn = fn(msg, txt, enabled) {
    eh.button([ a.class("col-2 btn btn-sm btn-outline-primary m-1 mb-4"), ev.on_click(msg), a.disabled(!enabled) ], [ e.text(txt) ])
  }
  eh.div([ a.class("col-6") ],
  [ eh.div([ a.class("card-body") ],
    [ eh.h5([], [ e.text("Input") ] )
    , eh.div([ a.class("row") ],
      [ text_input("clock", "Clock:", is.clock_input, "Invalid time.", TimeInputChanged,  time.time_to_time_string)
      , btn(AddClockEvent, "Add", is_valid(is.clock_input))
      ])
    , eh.div([ a.class("row") ],
      [ text_input("holiday", "Holiday:", is.holiday_input, "Invalid duration.", HolidayInputChanged, time.duration_to_unparsed_format_string)
      , btn(AddHolidayBooking(Gain), "Gain", is_valid(is.holiday_input))
      , btn(AddHolidayBooking(Use), "Use", is_valid(is.holiday_input))
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

