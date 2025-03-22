import gleam/option.{None, Some}

import gleeunit
import gleeunit/should

import birl.{Day}

import util/day
import util/duration
import util/parser as p
import util/time.{Time}

pub fn main() {
  gleeunit.main()
}

pub fn from_minutes_test() {
  duration.from_minutes(0)
  |> duration.to_time_string
  |> should.equal("0:00")
  duration.from_minutes(60)
  |> duration.to_time_string
  |> should.equal("1:00")
  duration.from_minutes(-60)
  |> duration.to_time_string
  |> should.equal("-1:00")
  duration.from_minutes(-75)
  |> duration.to_time_string
  |> should.equal("-1:15")
  duration.from_minutes(-15)
  |> duration.to_time_string
  |> should.equal("-0:15")
}

pub fn add_minutes_test() {
  Time(7, 15) |> time.add_minutes(15) |> should.equal(Time(7, 30))
  Time(7, 45) |> time.add_minutes(20) |> should.equal(Time(8, 5))
  Time(23, 45) |> time.add_minutes(20) |> should.equal(Time(0, 5))
  Time(23, 45) |> time.add_minutes(80) |> should.equal(Time(1, 5))
  Time(0, 8) |> time.add_minutes(-9) |> should.equal(Time(23, 59))
  Time(0, 8) |> time.add_minutes(-79) |> should.equal(Time(22, 49))
}

pub fn add_minutes_to_test() {
  Time(7, 15) |> time.add_minutes_to(15) |> should.equal(Time(7, 30))
  Time(7, 14) |> time.add_minutes_to(-15) |> should.equal(Time(7, 0))
  Time(7, 15) |> time.add_minutes_to(-15) |> should.equal(Time(7, 0))

  Time(7, 18) |> time.add_minutes_to(15) |> should.equal(Time(7, 30))
  Time(7, 10) |> time.add_minutes_to(-15) |> should.equal(Time(7, 0))

  Time(7, 18) |> time.add_minutes_to(60) |> should.equal(Time(8, 0))
  Time(7, 18) |> time.add_minutes_to(-60) |> should.equal(Time(7, 0))

  Time(8, 0) |> time.add_minutes_to(60) |> should.equal(Time(9, 0))
  Time(8, 0) |> time.add_minutes_to(-60) |> should.equal(Time(7, 0))
}

pub fn week_number_test() {
  Day(2017, 1, 2) |> day.week_number |> should.equal(1)
  Day(2005, 1, 1) |> day.week_number |> should.equal(53)
  Day(2005, 1, 2) |> day.week_number |> should.equal(53)
  Day(2006, 1, 1) |> day.week_number |> should.equal(52)
}

pub fn parser_test() {
  // pchar.
  p.pchar() |> p.run("x") |> should.equal(Some("x"))

  // end.
  p.end() |> p.run("a") |> should.equal(None)
  p.end() |> p.run("") |> should.equal(Some(Nil))

  // Combining with then.
  let combined_parser = {
    use ch1 <- p.then(p.pchar())
    use ch2 <- p.then(p.pchar())

    use <- p.do(p.end())

    p.success(ch1 <> ch2)
  }
  combined_parser |> p.run("01") |> should.equal(Some("01"))
  combined_parser |> p.run("0") |> should.equal(None)
  combined_parser |> p.run("012") |> should.equal(None)

  // char, and by extension, check.
  p.char("x") |> p.run("a") |> should.equal(None)
  p.char("x") |> p.run("x") |> should.equal(Some("x"))

  // one_of, an by extension, alt.
  let one_of_parser = p.one_of([p.char("a"), p.char("b"), p.char("c")])
  one_of_parser |> p.run("a") |> should.equal(Some("a"))
  one_of_parser |> p.run("b") |> should.equal(Some("b"))
  one_of_parser |> p.run("c") |> should.equal(Some("c"))

  // star.
  p.star(one_of_parser) |> p.run("abcd") |> should.equal(Some(["a", "b", "c"]))
  p.star(one_of_parser) |> p.run("eabcd") |> should.equal(Some([]))

  // plus.
  p.plus(one_of_parser)
  |> p.run("abcad")
  |> should.equal(Some(["a", "b", "c", "a"]))
  p.plus(one_of_parser) |> p.run("eabcd") |> should.equal(None)

  // repeat.
  p.repeat(one_of_parser, 3)
  |> p.run("abcad")
  |> should.equal(Some(["a", "b", "c"]))
  p.repeat(one_of_parser, 3) |> p.run("abdc") |> should.equal(None)
}
