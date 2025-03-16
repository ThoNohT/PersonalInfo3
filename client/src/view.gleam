import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import birl
import lustre/attribute as a
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev

import model.{
  type DayEvent, type DayStatistics, type InputState, type Model, type Msg,
  type SettingsState, type State, type Validated, AddClockEvent,
  AddHolidayBooking, ApplySettings, CancelSettings, ChangeDay, ClockEvent,
  DeleteListItem, Err, Gain, HolidayBooking, HolidayInputChanged,
  HolidayInputKeyDown, Home, In, InputState, Loaded, Loading, Login, Logout,
  LunchChanged, NoOp, Office, OpenSettings, Out, SelectListItem, Settings,
  SettingsState, State, TargetChanged, TargetKeyDown, TimeInputChanged,
  TimeInputKeyDown, ToggleHome, TravelDistanceChanged, TravelDistanceKeyDown,
  Use, WeekTargetChanged, WeekTargetKeyDown, is_valid,
}
import util/day
import util/duration
import util/event as uev
import util/prim
import util/time

fn day_item_card(selected_index: Option(Int), event: DayEvent) {
  let body = case event {
    ClockEvent(_, time, _, kind) -> {
      let prefix = case kind {
        In -> "In:"
        Out -> "Out:"
      }
      [
        eh.b([a.class("px-1")], [e.text(prefix)]),
        eh.span([a.class("px-1")], [e.text(time.to_string(time))]),
      ]
    }
    HolidayBooking(_, amount, kind) -> {
      let suffix = case kind {
        Gain -> " gained"
        Use -> " used"
      }
      [
        eh.b([a.class("px-1")], [e.text("Holiday: ")]),
        eh.span([a.class("px-1")], [
          e.text(duration.to_time_string(amount) <> suffix),
        ]),
      ]
    }
  }

  let home_toggle = case event {
    ClockEvent(..) as ce if ce.kind == In -> {
      let txt = case ce.location {
        Home -> "Home"
        Office -> "Office"
      }
      eh.button(
        [
          a.class("btn btn-outline-secondary btn-sm me-1"),
          ev.on_click(ToggleHome(event.index)),
        ],
        [e.text(txt)],
      )
    }
    _ -> e.none()
  }

  eh.div(
    [
      a.class(
        "list-item border border-2 rounded-3 m-1 p-1 d-flex flex-row justify-content-between",
      ),
      a.classes([#("selected", Some(event.index) == selected_index)]),
    ],
    [
      eh.div(
        [
          a.class("d-flex flex-row flex-grow-1"),
          ev.on_click(SelectListItem(event.index)),
        ],
        body,
      ),
      home_toggle,
      eh.button(
        [
          a.class("btn btn-outline-secondary btn-sm"),
          ev.on_click(DeleteListItem(event.index)),
        ],
        [e.text("X")],
      ),
    ],
  )
}

fn day_item_list(st: State) {
  let eta_text = case duration.is_positive(st.stats.eta) {
    True -> duration.to_string(st.stats.eta)
    False -> "Complete"
  }

  let end_text = case
    duration.is_positive(st.stats.eta),
    duration.later(st.now, st.stats.eta)
  {
    True, Some(done_at) -> [eh.br([]), e.text(time.to_string(done_at))]
    _, _ -> []
  }

  let on_click_handler = fn(
    modifiers: uev.ModifierState,
    dir: model.MoveDirection,
  ) -> Msg {
    let dist = case modifiers.shift, modifiers.ctrl {
      False, False -> model.MoveDay
      False, True -> model.MoveWeek
      True, False -> model.MoveMonth
      True, True -> model.MoveYear
    }

    ChangeDay(dist, dir)
  }

  let header =
    eh.div([a.class("row")], [
      eh.button(
        [
          a.class("col-1 btn btn-primary"),
          uev.on_click_mod(on_click_handler(_, model.Backward)),
        ],
        [e.text("<<")],
      ),
      eh.h3([a.class("col-10 text-center")], [
        e.text(
          day.weekday(st.current_state.date)
          |> birl.weekday_to_short_string
          |> string.slice(0, 2)
          <> " ",
        ),
        e.text(day.to_string(st.current_state.date)),
        case day.to_relative_string(st.current_state.date, st.today) {
          Some(str) -> eh.span([], [eh.br([]), e.text(" (" <> str <> ")")])
          None -> e.none()
        },
      ]),
      eh.button(
        [
          a.class("col-1 btn btn-primary"),
          uev.on_click_mod(on_click_handler(_, model.Forward)),
          a.disabled(st.today == st.current_state.date),
        ],
        [e.text(">>")],
      ),
    ])

  eh.div([a.class("col-6")], [
    header,
    eh.hr([]),
    eh.div([a.class("row")], [
      text_input(
        "target",
        "Target:",
        st.input_state.target_input,
        duration.to_unparsed_format_string(st.current_state.target),
        TargetChanged,
        Some(input_keydown_handler(_, TargetKeyDown, None, None)),
        duration.to_unparsed_format_string,
        False,
      ),
      check_input("lunch", "Lunch", st.current_state.lunch, LunchChanged),
      eh.div([a.class("col-3 p-2")], [
        eh.b([], [e.text("ETA: ")]),
        e.text(eta_text),
        ..end_text
      ]),
    ]),
    eh.div(
      [],
      st.current_state.events
        |> list.map(day_item_card(st.selected_event_index, _)),
    ),
  ])
}

fn text_input(
  name,
  label,
  value: Validated(a),
  invalid_message,
  input_message,
  keydown_message,
  parsed_to_string,
  autofocus,
) {
  eh.div([a.class("col-6 row container justify-content-start")], [
    eh.label([a.for(name <> "-input"), a.class("col-4 px-0 py-2")], [
      e.text(label),
    ]),
    eh.div([a.class("col-8")], [
      eh.input([
        a.type_("text"),
        a.class("form-control time-form"),
        a.id(name <> "-input"),
        a.value(value.input),
        a.autofocus(autofocus),
        a.classes([
          #("is-invalid", !is_valid(value)),
          #("is-valid", is_valid(value)),
        ]),
        keydown_message
          |> option.map(fn(msg) { uev.on_keydown_mod(msg) })
          |> option.unwrap(a.none()),
        ev.on_input(input_message),
      ]),
      eh.div([a.class("invalid-feedback")], [e.text(invalid_message)]),
      eh.div([a.class("valid-feedback")], [
        e.text(
          value.parsed |> option.map(parsed_to_string) |> option.unwrap("-"),
        ),
      ]),
    ]),
  ])
}

fn check_input(name, label, value, input_message) {
  eh.div([a.class("col-3 row container justify-content-start")], [
    eh.div([a.class("col-8")], [
      eh.input([
        a.type_("checkbox"),
        a.id(name <> "-input"),
        a.checked(value),
        ev.on_check(input_message),
      ]),
      eh.label([a.for(name <> "-input"), a.class("col-4 p-2")], [e.text(label)]),
    ]),
  ])
}

fn input_keydown_handler(
  tuple: #(uev.ModifierState, String),
  to_move_msg: fn(model.TimeMoveAmount, model.MoveDirection) -> Msg,
  add_msg_1: Option(Msg),
  add_msg_2: Option(Msg),
) -> #(Msg, Bool) {
  use <- prim.check(#(NoOp, False), !{ tuple.0 }.alt)
  case tuple.1, { tuple.0 }.ctrl, { tuple.0 }.shift {
    "ArrowRight", True, False -> #(
      to_move_msg(model.MoveMinute, model.Forward),
      True,
    )
    "ArrowLeft", True, False -> #(
      to_move_msg(model.MoveMinute, model.Backward),
      True,
    )

    // Up = 15 minutes, Up + Ctrl = 1 hour. + Shift = to start.
    "ArrowUp", False, False -> #(
      to_move_msg(model.MoveQuarter, model.Forward),
      True,
    )
    "ArrowDown", False, False -> #(
      to_move_msg(model.MoveQuarter, model.Backward),
      True,
    )
    "ArrowUp", True, False -> #(
      to_move_msg(model.MoveStartQuarter, model.Forward),
      True,
    )
    "ArrowDown", True, False -> #(
      to_move_msg(model.MoveStartQuarter, model.Backward),
      True,
    )

    "ArrowUp", False, True -> #(
      to_move_msg(model.MoveHour, model.Forward),
      True,
    )
    "ArrowDown", False, True -> #(
      to_move_msg(model.MoveHour, model.Backward),
      True,
    )
    "ArrowUp", True, True -> #(
      to_move_msg(model.MoveStartHour, model.Forward),
      True,
    )
    "ArrowDown", True, True -> #(
      to_move_msg(model.MoveStartHour, model.Backward),
      True,
    )

    "n", False, False -> #(to_move_msg(model.ToNow, model.Backward), True)

    // Direction is not used here.
    "Enter", False, False ->
      add_msg_1
      |> option.map(fn(m) { #(m, True) })
      |> option.unwrap(#(NoOp, False))
    "Enter", True, False ->
      add_msg_2
      |> option.map(fn(m) { #(m, True) })
      |> option.unwrap(#(NoOp, False))

    _, _, _ -> #(NoOp, False)
  }
}

fn input_keydown_handler_float(
  tuple: #(uev.ModifierState, String),
  to_move_msg: fn(model.FloatMoveAmount, model.MoveDirection) -> Msg,
  add_msg: Option(Msg),
) -> #(Msg, Bool) {
  use <- prim.check(#(NoOp, False), !{ tuple.0 }.alt)
  case tuple.1, { tuple.0 }.ctrl, { tuple.0 }.shift {
    "ArrowUp", False, False -> #(to_move_msg(model.Ones, model.Forward), True)
    "ArrowDown", False, False -> #(
      to_move_msg(model.Ones, model.Backward),
      True,
    )
    "ArrowUp", True, False -> #(to_move_msg(model.Tens, model.Forward), True)
    "ArrowDown", True, False -> #(to_move_msg(model.Tens, model.Backward), True)

    "ArrowUp", _, True -> #(to_move_msg(model.Tenths, model.Forward), True)
    "ArrowDown", _, True -> #(to_move_msg(model.Tenths, model.Backward), True)

    "Enter", _, False ->
      add_msg
      |> option.map(fn(m) { #(m, True) })
      |> option.unwrap(#(NoOp, False))

    _, _, _ -> #(NoOp, False)
  }
}

fn input_area(is: InputState, ds: DayStatistics) {
  let btn = fn(msg, txt, enabled) {
    eh.button(
      [
        a.class("col-2 btn btn-sm btn-outline-primary m-1 mb-4"),
        ev.on_click(msg),
        a.disabled(!enabled),
      ],
      [e.text(txt)],
    )
  }

  let eta_text = case duration.is_positive(ds.week_eta) {
    True -> duration.to_string(ds.week_eta)
    False -> "Complete"
  }

  let header =
    eh.div([a.class("row")], [
      eh.button(
        [a.class("col-2 btn btn-primary m-1"), ev.on_click(OpenSettings)],
        [e.text("Settings")],
      ),
      eh.h3([a.class("col-7 text-center")], [e.text("Input")]),
      eh.button([a.class("col-2 btn btn-primary m-1"), ev.on_click(Logout)], [
        e.text("Logout"),
      ]),
    ])

  eh.div([a.class("col-6")], [
    eh.div([a.class("")], [
      header,
      eh.hr([]),
      eh.div([a.class("row")], [
        text_input(
          "clock",
          "Clock:",
          is.clock_input,
          "Invalid time.",
          TimeInputChanged,
          Some(input_keydown_handler(
            _,
            TimeInputKeyDown,
            Some(AddClockEvent),
            None,
          )),
          time.to_string,
          True,
        ),
        btn(AddClockEvent, "Add", is_valid(is.clock_input)),
      ]),
      eh.div([a.class("row")], [
        text_input(
          "holiday",
          "Holiday:",
          is.holiday_input,
          "Invalid duration.",
          HolidayInputChanged,
          Some(input_keydown_handler(
            _,
            HolidayInputKeyDown,
            Some(AddHolidayBooking(model.Use)),
            Some(AddHolidayBooking(model.Gain)),
          )),
          duration.to_unparsed_format_string,
          False,
        ),
        btn(AddHolidayBooking(Use), "Use", is_valid(is.holiday_input)),
        btn(AddHolidayBooking(Gain), "Gain", is_valid(is.holiday_input)),
      ]),
      // Statistics
      eh.h3([a.class("text-center")], [e.text("Statistics")]),
      eh.hr([]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Total: ")]),
        e.text(duration.to_string(ds.total)),
      ]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Total (office): ")]),
        e.text(duration.to_string(ds.total_office)),
      ]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Total (home): ")]),
        e.text(duration.to_string(ds.total_home)),
      ]),
      eh.hr([]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Week: ")]),
        e.text(duration.to_string(ds.week)),
      ]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("ETA: ")]),
        e.text(eta_text),
      ]),
      eh.hr([]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Holiday left: ")]),
        e.text(duration.to_string(ds.remaining_holiday)),
      ]),
    ]),
  ])
}

fn settings_area(st: State, ss: SettingsState) {
  [
    eh.h3([a.class("col-9 text-center")], [e.text("Settings")]),
    text_input(
      "weektarget",
      "Week target:",
      ss.week_target_input,
      duration.to_unparsed_format_string(st.week_target),
      WeekTargetChanged,
      Some(input_keydown_handler(
        _,
        WeekTargetKeyDown,
        Some(ApplySettings),
        None,
      )),
      duration.to_unparsed_format_string,
      True,
    ),
    text_input(
      "traveldistance",
      "Travel distance:",
      ss.travel_distance_input,
      float.to_string(st.travel_distance),
      TravelDistanceChanged,
      Some(input_keydown_handler_float(
        _,
        TravelDistanceKeyDown,
        Some(ApplySettings),
      )),
      float.to_string,
      False,
    ),
    eh.button(
      [
        a.class("btn btn-outline-secondary btn-sm me-1"),
        ev.on_click(CancelSettings),
      ],
      [e.text("Cancel")],
    ),
    eh.button(
      [
        a.class("btn btn-outline-primary btn-sm me-1"),
        ev.on_click(ApplySettings),
      ],
      [e.text("Apply")],
    ),
  ]
}

pub fn view(model: Model) {
  case model {
    Login(..) ->
      eh.div([], [
        eh.p([], [e.text("Username:")]),
        eh.input([a.autofocus(True), ev.on_input(model.UsernameChanged)]),
        eh.p([], [e.text("Password:")]),
        eh.input([a.type_("password"), ev.on_input(model.PasswordChanged)]),
        eh.button([ev.on_click(model.TryLogin)], [e.text("Login")]),
      ])
    Loading(..) -> eh.div([], [e.text("Loading...")])
    Err(e) -> eh.div([], [e.text("Error: " <> e)])
    Loaded(state) -> {
      eh.div([a.class("container row mx-auto")], [
        day_item_list(state),
        input_area(state.input_state, state.stats),
      ])
    }
    Settings(st, ss) -> {
      eh.div([a.class("container col mx-auto")], settings_area(st, ss))
    }
  }
}
