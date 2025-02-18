import gleam/option.{type Option}

import birl.{type Day}
import util/time.{type Time, Time, type Duration, Duration}

pub type DayEvent {
  ClockEvent(time: Time, home: Bool, in: Bool)
  HolidayBooking(amount: Float)
}

pub type DayState {
  DayState(date: Day, target: Duration, events: List(DayEvent))
}

pub type InputState {
  InputState(
    time_input: String,
    parsed_time: Option(Time),
    holiday_input: String,
    parsed_holiday: Option(Duration),
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
  TimeInputChanged(new_time: String)
  HolidayInputChanged(new_duration: String)
  TargetChanged(new_target: String)
}
