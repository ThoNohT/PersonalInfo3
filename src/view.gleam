import gleam/list
import gleam/option.{type Option, Some, None}

import birl
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre/attribute as a

import util/event as uev
import util/time
import util/day
import util/duration
import model.{
  In, Out, Home, Office,
  type DayEvent, ClockEvent, HolidayBooking,
  type DayStatistics,
  type InputState, InputState,
  type Model, Loading, Err, Loaded, type State, State,
  Gain, Use,
  type Msg,
  TimeInputChanged, HolidayInputChanged, TargetChanged, LunchChanged,
  TimeInputKeyDown,
  SelectListItem, DeleteListItem, ToggleHome, AddClockEvent, AddHolidayBooking,
  PrevDay, NextDay,
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

fn day_item_list(st: State) {
  let eta_text = case duration.is_positive(st.stats.eta) {
    True -> duration.to_string(st.stats.eta)
    False -> "Complete"
  }

  let end_text =
    case duration.is_positive(st.stats.eta),
         duration.later(st.now, st.stats.eta) {
    True, Some(done_at) -> [ eh.br([]) , e.text(time.to_string(done_at)) ]
    _, _ -> []
  }

  let header =
    eh.div([ a.class("row") ],
    [ eh.button(
      [ a.class("col-1 btn btn-primary"), uev.on_click_mod(PrevDay) ],
      [ e.text("<<") ])
    , eh.h3([ a.class("col-10 text-center") ],
      [ e.text(day.weekday(st.current_state.date) |> birl.weekday_to_short_string <> " ")
      , e.text(day.to_string(st.current_state.date))
      , case day.to_relative_string(st.current_state.date, st.today) {
          Some(str) -> eh.span([], [eh.br([]), e.text(" (" <> str <> ")") ])
          None -> e.none()
        }
      ])
    , eh.button(
      [ a.class("col-1 btn btn-primary"), uev.on_click_mod(NextDay), a.disabled(st.today == st.current_state.date) ],
      [ e.text(">>") ])
    ])

  eh.div([ a.class("col-6") ],
    [ header
    , eh.hr([])
    , eh.div([ a.class("row") ],
      [ text_input("target", "Target:", st.input_state.target_input, duration.to_unparsed_format_string(st.current_state.target), TargetChanged, None, duration.to_unparsed_format_string, False)
      , check_input("lunch", "Lunch", st.current_state.lunch, LunchChanged)
      , eh.div([ a.class("col-3 p-2") ], [ eh.b([], [ e.text("ETA: ") ]), e.text(eta_text) , ..end_text ])
      ])
    , eh.div([], st.current_state.events |> list.map(day_item_card(st.selected_event_index, _)))
    ])
}

fn text_input(name, label, value: Validated(a), invalid_message, input_message, keydown_message, parsed_to_string, autofocus) {
  eh.div([ a.class("col-6 row container justify-content-start") ],
  [ eh.label([ a.for(name <> "-input"), a.class("col-4 px-0 py-2") ], [ e.text(label) ])

  , eh.div([ a.class("col-8") ],
    [ eh.input(
      [ a.type_("text") , a.class("form-control time-form") , a.id(name <> "-input")
      , a.value(value.input)
      , a.autofocus(autofocus)
      , a.classes([ #("is-invalid", !is_valid(value)), #("is-valid", is_valid(value)) ] )
      , keydown_message |> option.map(fn(msg) { uev.on_keydown_mod(msg) }) |> option.unwrap(a.none())
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
    eh.button(
      [ a.class("col-2 btn btn-sm btn-outline-primary m-1 mb-4")
      , ev.on_click(msg)
      , a.disabled(!enabled)
      ],
      [ e.text(txt) ])
  }

  let eta_text = case duration.is_positive(ds.week_eta) {
    True -> duration.to_string(ds.week_eta)
    False -> "Complete"
  }

  let clock_keydown_handler = fn(tuple: #(uev.ModifierState, String)) -> #(Msg, Bool) {
    // let key = tuple.1
    #(TimeInputKeyDown(tuple.0), False)
  }

  eh.div([ a.class("col-6") ],
  [ eh.div([ a.class("") ],
    [ eh.h3([ a.class("text-center") ], [ e.text("Input") ] )
    , eh.hr([])
    , eh.div([ a.class("row") ],
      [ text_input("clock", "Clock:", is.clock_input, "Invalid time.", TimeInputChanged, Some(clock_keydown_handler), time.to_string, True)
      , btn(AddClockEvent, "Add", is_valid(is.clock_input))
      ])
    , eh.div([ a.class("row") ],
      [ text_input("holiday", "Holiday:", is.holiday_input, "Invalid duration.", HolidayInputChanged, None, duration.to_unparsed_format_string, False)
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
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Week: ") ]), e.text(duration.to_string(ds.week)) ])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("ETA: ") ]), e.text(eta_text) ])
    , eh.hr([])
    , eh.div([ a.class("row p-2") ], [ eh.b([ a.class("col-3") ], [ e.text("Holiday left: ") ]), e.text(duration.to_string(ds.remaining_holiday)) ])
    ])
  ])
}

pub fn view(model: Model) {
  case model {
    Loading -> eh.div([], [ e.text("Loading...") ])
    Err(e) -> eh.div([], [ e.text("Error: " <> e) ])
    Loaded(state) -> {
      eh.div([ a.class("container row mx-auto") ],
        [ day_item_list(state)
        , input_area(state.input_state, state.stats)
        ])
    }
  }
}

