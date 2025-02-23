import gleam/list
import gleam/option.{type Option, Some}

import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre/attribute as a

import util/time
import util/duration
import model.{
  In, Out, Home, Office,
  type DayEvent, ClockEvent, HolidayBooking,
  type DayState, DayState, type DayStatistics,
  type InputState, InputState,
  type State, Loading, Loaded,
  Gain, Use,
  TimeInputChanged, HolidayInputChanged, TargetChanged, LunchChanged,
  SelectListItem, DeleteListItem, ToggleHome, AddClockEvent, AddHolidayBooking,
  type Validated, is_valid}

fn day_item_card(selected_index: Option(Int), event: DayEvent) {
  let body = case event {
    ClockEvent(_, time, _, kind) -> {
      let prefix = case kind { In -> "In:" Out -> "Out:" }
      [ eh.b([ a.class("px-1") ], [ e.text(prefix) ])
      , eh.span([ a.class("px-1") ], [ e.text(time.to_string(time)) ])
      ]
    }
    HolidayBooking(_, amount, kind) -> {
      let suffix = case kind { Gain -> " gained" Use -> " used" }
      [ eh.b([ a.class("px-1") ], [ e.text("Holiday: ") ])
      , eh.span([ a.class("px-1") ], [ e.text(duration.to_time_string(amount) <> suffix) ])
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
    , eh.button([ a.class("btn btn-outline-secondary btn-sm"), ev.on_click(DeleteListItem(event.index)) ], [ e.text("X") ])
    ])
}

fn day_item_list(day_state: DayState, is: InputState, selected_index: Option(Int)) {
  let eta_text = case duration.is_positive(day_state.stats.eta) {
    True -> duration.to_string(day_state.stats.eta)
    False -> "Complete"
  }

  let end_text =
    case duration.is_positive(day_state.stats.eta),
         duration.later(time.now(), day_state.stats.eta) {
    True, Some(done_at) -> [ eh.br([]) , e.text(time.to_string(done_at)) ]
    _, _ -> []

  }

  eh.div([ a.class("col-6") ],
    [ eh.h3([ a.class("text-center") ], [ e.text("Day") ] )
    , eh.hr([])
    , eh.div([ a.class("row") ],
      [ text_input("target", "Target:", is.target_input, duration.to_unparsed_format_string(day_state.target), TargetChanged, duration.to_unparsed_format_string)
      , check_input("lunch", "Lunch", day_state.lunch, LunchChanged)
      , eh.div([ a.class("col-3 p-2") ], [ eh.b([], [ e.text("ETA: ") ]), e.text(eta_text) , ..end_text ])
      ])
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

fn check_input(name, label, value, input_message) {
  eh.div([ a.class("col-3 row container justify-content-start") ],
  [ eh.div([ a.class("col-8") ],
    [ eh.input(
      [ a.type_("checkbox") , a.id(name <> "-input")
      , a.checked(value)
      , ev.on_check(input_message)
    ])
  , eh.label([ a.for(name <> "-input"), a.class("col-4 p-2") ], [ e.text(label) ])  ])
  ])
}

fn input_area(is: InputState, ds: DayStatistics) {
  let btn = fn(msg, txt, enabled) {
    eh.button([ a.class("col-2 btn btn-sm btn-outline-primary m-1 mb-4"), ev.on_click(msg), a.disabled(!enabled) ], [ e.text(txt) ])
  }
  eh.div([ a.class("col-6") ],
  [ eh.div([ a.class("") ],
    [ eh.h3([ a.class("text-center") ], [ e.text("Input") ] )
    , eh.hr([])
    , eh.div([ a.class("row") ],
      [ text_input("clock", "Clock:", is.clock_input, "Invalid time.", TimeInputChanged, time.to_string)
      , btn(AddClockEvent, "Add", is_valid(is.clock_input))
      ])
    , eh.div([ a.class("row") ],
      [ text_input("holiday", "Holiday:", is.holiday_input, "Invalid duration.", HolidayInputChanged, duration.to_unparsed_format_string)
      , btn(AddHolidayBooking(Gain), "Gain", is_valid(is.holiday_input))
      , btn(AddHolidayBooking(Use), "Use", is_valid(is.holiday_input))
      ])

    // Statistics
    , eh.h3([ a.class("text-center") ], [ e.text("Statistics") ] )
    , eh.hr([])

    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Total: ") ]), e.text(duration.to_string(ds.total)) ])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Total (office): ") ]), e.text(duration.to_string(ds.total_office)) ])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Total (home): ") ]), e.text(duration.to_string(ds.total_home)) ])
    , eh.hr([])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Week: ") ]), e.text("TODO") ])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("ETA: ") ]), e.text("TODO") ])
    , eh.hr([])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Holiday left: ") ]), e.text(duration.to_string(ds.remaining_holiday)) ])
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
        , input_area(is, st.stats)
        ])
    }
  }
}

