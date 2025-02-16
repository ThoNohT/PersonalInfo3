import gleam/option.{type Option}

import birl.{type Day}
import util/time.{type Time, Time, type Duration, Duration}

pub type DayEvent {
  ClockEvent(time: Time, home: Bool, in: Bool)
  HolidayBooking(amount: Float)
}

pub type DayState {
  DayState(date: Day, target: Float, events: List(DayEvent))
}

pub type InputState {
  InputState(
    time_input: String,
    parsed_time: Option(Time),
    target_input: String,
    parsed_target: Option(Duration),
  )
}

pub type State {
  Loading
  Loaded(today: Day, current_state: DayState, week_target: Float, input_state: InputState)
}

pub type Msg {
  LoadState
  TimeChanged(new_time: String)
  TargetChanged(new_target: String)
}
