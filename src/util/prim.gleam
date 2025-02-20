import gleam/option.{type Option}

/// A very generic version of option.then and result.try.
pub fn then(default: b, option: Option(a), apply fun: fn(a) -> b) -> b {
    case option {
        option.None -> default
        option.Some(val) -> fun(val)
    }
}

/// Like then, but checks a boolean. The resulting value is also a boolean, but this can be ignored since it will always be true when passed.
pub fn check(default: a, value: Bool, apply fun: fn(Bool) -> a) -> a {
    case value {
        False -> default
        True -> fun(True)
    }
}