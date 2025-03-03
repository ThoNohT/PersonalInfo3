import gleam/option.{Some, None}

import gleeunit
import gleeunit/should

import birl.{Day}

import util/numbers.{Pos, Neg}
import util/day
import util/duration.{Duration}
import util/parser2 as p

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

pub fn parser2_test() {
  // pchar.
  p.pchar() |> p.run("x") |> should.equal(Some("x"))

  // end.
  p.end() |> p.run("a")|> should.equal(None)
  p.end() |> p.run("")|> should.equal(Some(Nil))

  // Combining with then.
  let combined_parser = {
    use ch1 <- p.then(p.pchar())
    use ch2 <- p.then(p.pchar())

    use _ <- p.then(p.end())

    p.success(ch1 <> ch2)
  } 
  combined_parser |> p.run("01") |> should.equal(Some("01"))
  combined_parser |> p.run("0") |> should.equal(None)
  combined_parser |> p.run("012") |> should.equal(None)

  // char, and by extension, check.
  p.char("x") |> p.run("a") |> should.equal(None)
  p.char("x") |> p.run("x") |> should.equal(Some("x"))

  // one_of, an by extension, alt.
  let one_of_parser = p.one_of([ p.char("a"), p.char("b"), p.char("c") ])
  one_of_parser |> p.run("a") |> should.equal(Some("a"))
  one_of_parser |> p.run("b") |> should.equal(Some("b"))
  one_of_parser |> p.run("c") |> should.equal(Some("c"))

  // star.
  p.star(one_of_parser) |> p.run("abcd") |> should.equal(Some([ "a", "b", "c" ]))
  p.star(one_of_parser) |> p.run("eabcd") |> should.equal(Some([]))

  // plus.
  p.plus(one_of_parser) |> p.run("abcad") |> should.equal(Some([ "a", "b", "c", "a" ]))
  p.plus(one_of_parser) |> p.run("eabcd") |> should.equal(None)

  // repeat.
  p.repeat(one_of_parser, 3) |> p.run("abcad") |> should.equal(Some([ "a", "b", "c" ]))
  p.repeat(one_of_parser, 3) |> p.run("abdc") |> should.equal(None)
}
