import gleam/option.{None}

import gleeunit
import gleeunit/should

import util/numbers.{Pos, Neg}
import util/duration.{Duration}

pub fn main() {
  gleeunit.main()
}

pub fn from_minutes_test() {
    duration.from_minutes(0)
        |> should.equal(Duration(0, 0, Pos, None))
    duration.from_minutes(60)
        |> should.equal(Duration(1, 0, Pos, None))
    duration.from_minutes(-60)
        |> should.equal(Duration(1, 0, Neg, None))
    duration.from_minutes(-75)
        |> should.equal(Duration(1, 15, Neg, None))
    duration.from_minutes(-15)
        |> should.equal(Duration(0, 15, Neg, None))
}
