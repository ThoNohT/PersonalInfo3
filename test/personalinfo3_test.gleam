import gleam/option.{None}

import gleeunit
import gleeunit/should

import birl.{Day}

import util/numbers.{Pos, Neg}
import util/day
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

pub fn week_number_test() {
  Day(2017, 1, 2) |> day.week_number |> should.equal(1)
  Day(2005, 1, 1) |> day.week_number |> should.equal(53)
  Day(2005, 1, 2) |> day.week_number |> should.equal(53)
  Day(2006, 1, 1) |> day.week_number |> should.equal(52)
}
