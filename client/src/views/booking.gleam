import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import birl
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre_http as http

import gleam/float
import gleam/http as ghttp
import gleam/http/request
import model.{
  type DayEvent, type DayState, type InputState, type Model, type Msg,
  type State, type Statistics, AddClockEvent, AddHolidayBooking, Booking,
  ChangeDay, ClockEvent, DayState, DeleteListItem, Gain, HolidayBooking,
  HolidayInputChanged, HolidayInputKeyDown, Home, In, InputState, Login,
  LoginModel, Logout, LunchChanged, NoOp, Office, OpenSettings, Out,
  SelectListItem, Settings, SettingsModel, SettingsState, State, TargetChanged,
  TargetKeyDown, Tick, TimeInputChanged, TimeInputKeyDown, ToggleHome, Use,
  is_valid, validate,
}
import model/statistics
import shared_model.{Credentials}
import util/day
import util/duration
import util/effect as ef
import util/event as uev
import util/local_storage
import util/parser as p
import util/parsers
import util/site
import util/time
import views/shared

fn get_model(model: Model) -> Option(State) {
  case model {
    Booking(st) -> Some(st)
    _ -> None
  }
}

/// Sends a request to store the current state to the api.
/// Will only send a request if the state is loaded.
pub fn store_state(model: Model) -> effect.Effect(Msg) {
  case model {
    Booking(st) -> {
      let request =
        site.request_with_authorization(
          site.base_url() <> "/api/simplestate/pi_history",
          ghttp.Put,
          st.session.session_id,
        )
        |> request.set_body(model.serialize_state(st))
      http.send(request, http.expect_anything(fn(_) { NoOp }))
    }
    _ -> effect.none()
  }
}

/// Update logic for the Booking view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use st <- option.then(get_model(model))

  let today = time.today()
  let now = time.now()

  // When returning the model, this function can be called on it,
  // to also send the new serialized state to the api.
  let and_store = fn(m: Model) { #(m, store_state(m)) }

  case msg {
    Tick -> {
      // Only update if the time changed to the precision we observe it (minutes).
      use <- ef.check(model, now != st.now)
      ef.just(Booking(
        State(..st, today:, now:)
        |> model.update_history
        |> statistics.recalculate,
      ))
    }
    Logout -> {
      let request =
        site.request_with_authorization(
          site.base_url() <> "/api/user/logout",
          ghttp.Post,
          st.session.session_id,
        )
      local_storage.remove("session")
      #(
        Login(LoginModel(Credentials("", ""), False)),
        http.send(request, http.expect_anything(fn(_) { NoOp })),
      )
    }
    TimeInputChanged(new_time) -> {
      let input_state =
        InputState(
          ..st.input_state,
          clock_input: validate(
            string.slice(new_time, 0, 5),
            time.parser() |> p.conv,
          ),
        )
      ef.just(Booking(State(..st, input_state:)))
    }
    HolidayInputChanged(new_duration) -> {
      let input_state =
        InputState(
          ..st.input_state,
          holiday_input: validate(
            string.slice(new_duration, 0, 6),
            duration.parser() |> p.conv,
          ),
        )
      ef.just(Booking(State(..st, input_state:)))
    }
    TargetChanged(nt) -> {
      let target_input =
        validate(string.slice(nt, 0, 6), duration.parser() |> p.conv)
      let input_state = InputState(..st.input_state, target_input:)
      let current_state_and_update = case target_input.parsed {
        None -> #(st.current_state, False)
        Some(target) -> #(DayState(..st.current_state, target:), True)
      }
      let current_state = current_state_and_update.0
      let new_model =
        Booking(
          State(..st, current_state:, input_state:)
          |> model.update_history
          |> statistics.recalculate,
        )
      case current_state_and_update.1 {
        False -> ef.just(new_model)
        True -> new_model |> and_store
      }
    }
    LunchChanged(new_lunch) -> {
      let current_state = DayState(..st.current_state, lunch: new_lunch)
      Booking(
        State(..st, current_state:)
        |> model.update_history
        |> statistics.recalculate,
      )
      |> and_store
    }
    SelectListItem(idx) -> {
      let selected_event =
        st.current_state.events
        |> list.drop(idx)
        |> list.first
        |> option.from_result
      let selected_idx = selected_event |> option.map(fn(e) { e.index })
      let input_state = case selected_event {
        Some(ClockEvent(..) as ce) ->
          InputState(
            ..st.input_state,
            clock_input: validate(time.to_string(ce.time), p.run(
              time.parser(),
              _,
            )),
          )
        Some(HolidayBooking(..) as hb) ->
          InputState(
            ..st.input_state,
            holiday_input: validate(
              duration.to_time_string(hb.amount),
              duration.parser() |> p.conv,
            ),
          )
        None -> st.input_state
      }
      ef.just(Booking(
        State(..st, selected_event_index: selected_idx, input_state:),
      ))
    }
    DeleteListItem(idx) -> {
      let #(before, after) = st.current_state.events |> list.split(idx)
      case after {
        [_, ..af] -> {
          // Takes out the element at idx.
          let current_state =
            DayState(
              ..st.current_state,
              events: list.append(before, af) |> model.recalculate_events,
            )
          Booking(
            State(..st, current_state:)
            |> model.update_history
            |> statistics.recalculate,
          )
          |> and_store
        }
        _ -> ef.just(model)
      }
    }
    ToggleHome(idx) -> {
      let toggle_home = fn(e) {
        case e {
          ClockEvent(index: index, location: loc, ..) as ce if idx == index ->
            ClockEvent(..ce, location: model.switch_location(loc))
          _ -> e
        }
      }

      let new_events = st.current_state.events |> list.map(toggle_home)
      let current_state =
        DayState(
          ..st.current_state,
          events: new_events |> model.recalculate_events,
        )
      Booking(
        State(..st, current_state:)
        |> model.update_history
        |> statistics.recalculate,
      )
      |> and_store
    }
    AddClockEvent -> {
      use time <- ef.then(model, st.input_state.clock_input.parsed)
      use <- ef.check(
        model,
        !model.daystate_has_clock_event_at(st.current_state, time),
      )

      let new_event =
        ClockEvent(list.length(st.current_state.events), time, Office, In)
      let events =
        [new_event, ..st.current_state.events] |> model.recalculate_events
      let current_state = DayState(..st.current_state, events:)
      Booking(
        State(..st, current_state:)
        |> model.update_history
        |> statistics.recalculate,
      )
      |> and_store
    }
    AddHolidayBooking(kind) -> {
      use duration <- ef.then(model, st.input_state.holiday_input.parsed)

      let new_event =
        HolidayBooking(list.length(st.current_state.events), duration, kind)
      let events =
        [new_event, ..st.current_state.events] |> model.recalculate_events
      let current_state = DayState(..st.current_state, events:)
      Booking(
        State(..st, current_state:)
        |> model.update_history
        |> statistics.recalculate,
      )
      |> and_store
    }
    ChangeDay(amount, dir) -> {
      let first_day =
        st.history
        |> list.first
        |> option.from_result
        |> option.map(fn(x) { x.date })
        |> option.unwrap(st.today)
      let to_day =
        model.move_date(st.current_state.date, amount, dir, first_day, st.today)

      let state = case
        list.find(st.history, fn(s: DayState) { s.date == to_day })
      {
        Ok(current_state) ->
          State(..st, current_state:) |> statistics.recalculate
        Error(_) -> model.add_day_state(st, to_day) |> statistics.recalculate
      }

      let input_state =
        InputState(
          ..state.input_state,
          target_input: validate(
            duration.to_decimal_string(state.current_state.target, 2),
            duration.parser() |> p.conv,
          ),
        )
      ef.just(Booking(State(..state, input_state:)))
    }
    TimeInputKeyDown(amount, dir) -> {
      use to_time <- ef.then(
        model,
        model.calculate_target_time(
          st.input_state.clock_input.parsed,
          amount,
          dir,
          st.now,
        ),
      )
      let input_state =
        InputState(
          ..st.input_state,
          clock_input: validate(time.to_string(to_time), p.run(time.parser(), _)),
        )
      ef.just(Booking(State(..st, input_state:)))
    }
    HolidayInputKeyDown(amount, dir) -> {
      use to_duration <- ef.then(
        model,
        model.calculate_target_duration(
          st.input_state.holiday_input.parsed,
          amount,
          dir,
          1000,
        ),
      )
      let input_state =
        InputState(
          ..st.input_state,
          holiday_input: validate(
            duration.to_time_string(to_duration),
            duration.parser() |> p.conv,
          ),
        )
      ef.just(Booking(State(..st, input_state:)))
    }
    TargetKeyDown(amount, dir) -> {
      use to_duration <- ef.then(
        model,
        model.calculate_target_duration(
          st.input_state.target_input.parsed,
          amount,
          dir,
          24,
        ),
      )
      let input_state =
        InputState(
          ..st.input_state,
          target_input: validate(
            duration.to_time_string(to_duration),
            duration.parser() |> p.conv,
          ),
        )
      ef.just(Booking(State(..st, input_state:)))
    }
    OpenSettings -> {
      let week_target_input =
        model.validate(
          duration.to_time_string(st.week_target),
          duration.parser() |> p.conv,
        )
      let travel_distance_input =
        model.validate(
          float.to_string(st.travel_distance),
          parsers.float() |> p.conv,
        )
      ef.just(
        Settings(SettingsModel(
          state: st,
          settings: SettingsState(week_target_input:, travel_distance_input:),
        )),
      )
    }
    _ -> ef.just(model)
  }
  |> Some
}

/// View logic for the Booking view.
pub fn view(model: Model) {
  use st <- option.then(get_model(model))

  eh.div([a.class("container row mx-auto")], [
    day_item_list(st),
    input_area(st.input_state, st.stats),
  ])
  |> Some
}

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
  let eta_text = case duration.is_positive(st.stats.current_day.eta) {
    True -> duration.to_string(st.stats.current_day.eta)
    False -> "Complete"
  }

  let end_text = case
    duration.is_positive(st.stats.current_day.eta),
    duration.later(st.now, st.stats.current_day.eta)
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
      shared.text_input(
        "target",
        "Target:",
        st.input_state.target_input,
        duration.to_unparsed_format_string(st.current_state.target),
        TargetChanged,
        Some(shared.input_keydown_handler(_, TargetKeyDown, None, None)),
        duration.to_unparsed_format_string,
        False,
      ),
      shared.check_input("lunch", "Lunch", st.current_state.lunch, LunchChanged),
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

fn input_area(is: InputState, ds: Statistics) {
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
        shared.text_input(
          "clock",
          "Clock:",
          is.clock_input,
          "Invalid time.",
          TimeInputChanged,
          Some(shared.input_keydown_handler(
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
        shared.text_input(
          "holiday",
          "Holiday:",
          is.holiday_input,
          "Invalid duration.",
          HolidayInputChanged,
          Some(shared.input_keydown_handler(
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
        e.text(duration.to_string(ds.current_day.total)),
      ]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Total (office): ")]),
        e.text(duration.to_string(ds.current_day.total_office)),
      ]),
      eh.div([a.class("row p-2")], [
        eh.b([a.class("col-3")], [e.text("Total (home): ")]),
        e.text(duration.to_string(ds.current_day.total_home)),
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
