import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/option
import gleam/order.{Gt}
import gleam/result
import gleam/string

import util/day
import util/duration.{type Duration}
import util/list as ulist
import util/prim
import util/result as ur
import util/time.{type Time}

import birl.{type Day, Day}

pub type Setting {
  WeekTarget(duration: Duration)
  TravelDistance(distance: Float)
}

/// Checks whether two settings are equal
fn settings_equal(a: Setting, b: Setting) -> Bool {
  case a, b {
    WeekTarget(_), WeekTarget(_) -> True
    TravelDistance(_), TravelDistance(_) -> True
    _, _ -> False
  }
}

/// A decoder for a setting.
pub fn setting_decoder() -> Decoder(Setting) {
  use setting_type <- decode.field("type", decode.string)
  case setting_type {
    "WeekTarget" -> {
      use duration <- decode.field("duration", duration.decoder())
      decode.success(WeekTarget(duration))
    }
    "TravelDistance" -> {
      use distance <- decode.field("distance", decode.float)
      decode.success(TravelDistance(distance))
    }
    _ -> decode.failure(WeekTarget(duration.zero()), "setting_type")
  }
}

pub type ClockLocation {
  Office
  Home
}

fn clock_location_decoder() -> Decoder(ClockLocation) {
  decode.then(decode.string, fn(str) {
    case string.lowercase(str) {
      "office" -> decode.success(Office)
      "home" -> decode.success(Home)
      _ -> decode.failure(Office, "ClockLocation")
    }
  })
}

pub type Snapshot {
  Snapshot(
    // The snapshot excludes all events in this day. So it represents the state at the start of this day.
    date: Day,
    leave_kinds: List(LeaveKind),
    leave_amounts: List(Duration),
    settings: List(Setting),
  )
}

/// Creates a snapshot that starts with initial settings, at 1-1-1.
pub fn snapshot_empty() -> Snapshot {
  Snapshot(Day(1, 1, 1), [], [], [
    WeekTarget(duration.zero()),
    TravelDistance(0.0),
  ])
}

pub type EventId =
  Int

pub type LeaveKind =
  String

pub type EventBase {
  EventBase(id: EventId, date: Day)
}

pub type Event {
  // Nothing happened.
  Nop(base: EventBase)
  SetSetting(base: EventBase, setting: Setting)
  DefineLeave(base: EventBase, kind: LeaveKind)
  UndefineLeave(base: EventBase, kind: LeaveKind)
  GainLeave(base: EventBase, kind: LeaveKind, duration: Duration)
  UseLeave(base: EventBase, kind: LeaveKind, duration: Duration)
  Clock(base: EventBase, time: Time, location: ClockLocation)
}

pub type WeekState {
  WeekState(
    // The settings and leave information for this day. Excluding events this day.
    snapshot: Snapshot,
    // The total booked hours for this week, including events for this day.
    week_total: Duration,
    // Test.
    week_events: List(Event),
  )
}

pub type EventType =
  Int

pub fn event_to_type(event: Event) -> EventType {
  case event {
    Nop(..) -> 0
    SetSetting(..) -> 1
    DefineLeave(..) -> 2
    UndefineLeave(..) -> 3
    GainLeave(..) -> 4
    UseLeave(..) -> 5
    Clock(..) -> 6
  }
}

/// A decoder for an event.
pub fn event_decoder(base: EventBase, event_type: EventType) -> Decoder(Event) {
  case event_type {
    1 -> {
      use setting <- decode.field("setting", setting_decoder())
      decode.success(SetSetting(base, setting))
    }
    2 -> {
      use kind <- decode.field("kind", decode.string)
      decode.success(DefineLeave(base, kind))
    }
    3 -> {
      use kind <- decode.field("kind", decode.string)
      decode.success(UndefineLeave(base, kind))
    }
    4 -> {
      use kind <- decode.field("kind", decode.string)
      use amount <- decode.field("amount", duration.decoder())
      decode.success(GainLeave(base, kind, amount))
    }
    5 -> {
      use kind <- decode.field("kind", decode.string)
      use amount <- decode.field("amount", duration.decoder())
      decode.success(UseLeave(base, kind, amount))
    }
    6 -> {
      use time <- decode.field("time", time.decoder())
      use location <- decode.field("in", clock_location_decoder())
      decode.success(Clock(base, time, location))
    }
    _ -> decode.failure(Nop(base), "EventType")
  }
}

pub type EventEntity {
  EventEntity(event_type: EventType, event_data: String)
}

/// Applies an event to a snapshot, resulting in a new snapshot with the event applied.
/// Note that events need to be applied in chronological order.
/// Attempting to apply an event with an earlier date than the date of the snapshot will return an Error.
pub fn apply_event(snapshot: Snapshot, event: Event) -> Result(Snapshot, String) {
  use <- prim.check(
    Error("Cannot apply an event older than the snapshot it is applied to"),
    day.compare(snapshot.date, event.base.date) != Gt,
  )

  let result = Snapshot(..snapshot, date: event.base.date)

  case event {
    Nop(..) ->
      // No event doesn't change anything.
      Ok(result)

    SetSetting(_, setting) ->
      // Adds or updates the specified setting.
      Snapshot(
        ..result,
        settings: result.settings
          |> ulist.add_or_update(fn(e) { settings_equal(e, setting) }, setting),
      )
      |> Ok

    DefineLeave(_, kind) -> {
      // Check if it doesn't already exist.
      use <- prim.res(
        list.find(result.leave_kinds, fn(k) { k == kind })
        |> ur.flip(fn(_) { "This leave kind is already defined" }, fn(_) { Nil }),
      )

      Snapshot(
        ..result,
        leave_kinds: [kind, ..result.leave_kinds],
        leave_amounts: [duration.zero(), ..result.leave_amounts],
      )
      |> Ok
    }

    UndefineLeave(_, kind) -> {
      use existing_idx <- result.try(
        ulist.find_index(result.leave_kinds, fn(k) { k == kind })
        |> option.to_result("This leave kind is not defined"),
      )

      Snapshot(
        ..result,
        leave_kinds: result.leave_kinds |> ulist.splice(existing_idx, 1),
        leave_amounts: result.leave_amounts |> ulist.splice(existing_idx, 1),
      )
      |> Ok
    }

    GainLeave(_, kind, duration) -> {
      use existing_idx <- result.try(
        ulist.find_index(result.leave_kinds, fn(k) { k == kind })
        |> option.to_result("This leave kind is not defined"),
      )

      Snapshot(
        ..result,
        leave_amounts: result.leave_amounts
          |> ulist.update_index(existing_idx, fn(dur) {
            duration.add(dur, duration)
          }),
      )
      |> Ok
    }
    UseLeave(_, kind, duration) -> {
      use existing_idx <- result.try(
        ulist.find_index(result.leave_kinds, fn(k) { k == kind })
        |> option.to_result("This leave kind is not defined"),
      )

      Snapshot(
        ..result,
        leave_amounts: result.leave_amounts
          |> ulist.update_index(existing_idx, fn(dur) {
            duration.subtract(dur, duration)
          }),
      )
      |> Ok
    }
    // Clocked times are not stored in a snapshot. They are typically only relevant within a week,
    // and then it is easy enough to load all events for this week.
    Clock(..) -> Ok(result)
  }
}
