//import gleam/dynamic/decode
//import gleam/option.{type Option}

//import birl
//import sqlight.{type Connection}

//import shared_model_events.{type WeekState, type Event}

//import util/decode as dec
//import util/option as opt
//import util/server_result.{sql_try}

// pub fn add_event(_conn: Connection, _user_id: Int, _event: Event) {
//   // If the date is before the last snapshot, recalculate all snapshots after.
//   todo
// }

// pub fn load_user_state(_conn: Connection, _user_id: Int, _date: Int) -> WeekState {
//   // Find the last snapshot before or on the date.
//   // Load all events starting on snapshot date, until and including specified date. Apply them to the snapshot.
//   // Include the bookings in the date for which we are loading the state.
//   todo
// }
