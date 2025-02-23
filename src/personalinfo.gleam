import gleam/list
import gleam/option.{None, Some}
import gleam/string

import lustre
import lustre/effect

import util/effect as ef
import util/time
import util/duration.{Duration, DecimalFormat}
import model.{
  Office, In,
  ClockEvent, HolidayBooking,
  type DayState, DayState, DayStatistics,
  type InputState, InputState,
  type State, Loading, Loaded,
  type Msg, LoadState, TimeInputChanged, HolidayInputChanged, TargetChanged, LunchChanged,
  SelectListItem, DeleteListItem, ToggleHome, AddClockEvent, AddHolidayBooking,
  validate, unvalidated}
import view.{view}

fn dispatch_message(message message) -> effect.Effect(message) {
  effect.from(fn(dispatch) { dispatch(message) })
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_) {
  #(Loading, dispatch_message(LoadState))
}

fn update(model: State, msg: Msg) {
  let today = time.today()

  case model, msg {
    Loading, LoadState -> {
        let events = []
        let stats = DayStatistics(eta: duration.zero(), total: duration.zero(), total_office: duration.zero(), total_home: duration.zero(), remaining_holiday: duration.zero())
        let current_state = DayState(date: today, target: Duration(8, 0, Some(DecimalFormat)), lunch: True, events:, stats:) |> model.recalculate_statistics
        let input_state = InputState(
          clock_input: unvalidated(),
          holiday_input: unvalidated(),
          target_input: validate(duration.to_decimal_string(current_state.target, 2), duration.parse)
        )
        #(Loaded(today:, current_state:, selected_event: None, week_target: Duration(40, 0, Some(DecimalFormat)), input_state:)
        , ef.dispatch(SelectListItem(0)))
    }
    Loaded(input_state: is, ..) as st, TimeInputChanged(new_time) -> {
      let input_state = InputState(..is,
        clock_input: validate(string.slice(new_time, 0, 5), time.parse))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(input_state: is, ..) as st, HolidayInputChanged(new_duration) -> {
      let input_state = InputState(..is,
        holiday_input: validate(string.slice(new_duration, 0, 6), duration.parse))
      ef.just(Loaded(..st, input_state:))
    }
    Loaded(current_state: cs, input_state: is, ..) as st, TargetChanged(new_target) -> {
      let target_input = validate(string.slice(new_target, 0, 6), duration.parse)
      let input_state = InputState(..is, target_input:)
      let current_state = case target_input.parsed { None -> cs Some(target) -> DayState(..cs, target:) } |> model.recalculate_statistics
      ef.just(Loaded(..st, current_state:, input_state:))
    }
    Loaded(current_state: cs, ..) as st, LunchChanged(new_lunch) -> {
      let current_state = DayState(..cs, lunch: new_lunch) |> model.recalculate_statistics
      ef.just(Loaded(..st, current_state:))
    }
    Loaded(current_state: cs, input_state: is, ..) as st, SelectListItem(idx) -> {
      let selected_event = cs.events |> list.drop(idx) |> list.first |> option.from_result
      let input_state = case selected_event {
        Some(ClockEvent(..) as ce) -> InputState(..is, clock_input: validate(time.to_string(ce.time), time.parse))
        Some(HolidayBooking(..) as hb) -> InputState(..is, holiday_input: validate(duration.to_time_string(hb.amount), duration.parse))
        None -> is
      }
      ef.just(Loaded(..st, selected_event:, input_state:))
    }
    Loaded(current_state: cs, ..) as st, DeleteListItem(idx) -> {
      let #(before, after) = cs.events |> list.split(idx)
      case after {
        [ _, ..af ] -> {
          // Takes out the element at idx.
          let current_state = DayState(..cs, events: list.append(before, af) |> model.recalculate_events) |> model.recalculate_statistics
          ef.just(Loaded(..st, current_state:))
        }
        _ -> ef.just(st)
      }
    }
    Loaded(current_state: cs, ..) as st, ToggleHome(idx) -> {
      let toggle_home = fn(e) {
        case e {
          ClockEvent(index: index, location:loc, ..) as ce if idx == index ->
            ClockEvent(..ce, location: model.switch_location(loc))
          _ -> e
        }
      }

      let new_events = cs.events |> list.map(toggle_home)
      let current_state = DayState(..cs, events: new_events |> model.recalculate_events) |> model.recalculate_statistics
      ef.just(Loaded(..st, current_state:))
    }
    Loaded(current_state: cs, input_state: is, ..) as st, AddClockEvent -> {
      use time <- ef.then(st, is.clock_input.parsed)
      use _ <- ef.check(st, !model.daystate_has_clock_event_at(cs, time))

      let new_event = ClockEvent(list.length(cs.events), time, Office, In)
      let events = [ new_event, ..cs.events ] |> model.recalculate_events
      let current_state = DayState(..cs, events:) |> model.recalculate_statistics
      ef.just(Loaded(..st, current_state:))
    }
    Loaded(current_state: cs, input_state: is, ..) as st, AddHolidayBooking(kind) -> {
      use duration <- ef.then(st, is.holiday_input.parsed)

      let new_event = HolidayBooking(list.length(cs.events), duration, kind)
      let events = [ new_event, ..cs.events ] |> model.recalculate_events
      let current_state = DayState(..cs, events:) |> model.recalculate_statistics
      ef.just(Loaded(..st, current_state:))
    }
    _, _ -> ef.just(model)
  }
}

// fn checkbox_input(name) -> e.Element(a) {
//   eh.div([],
//     [ eh.div([], [ eh.input([ a.type_("checkbox") ]) ])
//     , eh.div([], [ e.text(name) ])
//     ])
// }
