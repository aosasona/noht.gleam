import gleam/int
import gleam/regex
import gleam/list
import gleam/string

// This is all primarily for string fields, but we could extend it to other types later
pub type Rule {
  Required
  MinLength(Int)
  MaxLength(Int)
  Email
}

pub type Field {
  Field(name: String, value: String, rules: List(Rule))
}

pub type MatchResult {
  Failed(reason: String)
  Passed
}

pub type FieldError {
  FieldError(name: String, errors: List(String))
  NoFieldError
}

/// Validate a list of fields
pub fn validate_multiple(fields: List(Field)) -> List(FieldError) {
  fields
  |> list.map(fn(field) {
    validate_field(field.name, field.rules)
    |> fn(result) {
      case result {
        #(True, errors) -> FieldError(name: field.name, errors: errors)
        #(False, _) -> NoFieldError
      }
    }
  })
  |> list.filter(fn(result) { result != NoFieldError })
}

/// Validate a list of rules on a field
pub fn validate_field(
  field field: String,
  rules rules: List(Rule),
) -> #(Bool, List(String)) {
  rules
  |> list.map(fn(rule) { match(field: field, rule: rule) })
  |> list.filter(fn(error) { error != Passed })
  |> list.map(fn(error) {
    case error {
      Failed(reason) -> reason
      Passed -> ""
    }
  })
  |> fn(errors) {
    case list.length(errors) > 0 {
      True -> #(True, errors)
      False -> #(False, [])
    }
  }
}

// Validate a single rule on a field
fn match(field field: String, rule rule: Rule) -> MatchResult {
  case rule {
    Required -> required(field)
    MinLength(min) -> min_length(field, min)
    MaxLength(max) -> max_length(field, max)
    Email -> email(field)
  }
}

fn required(field: _) -> MatchResult {
  case field {
    field if field == "" -> Failed("required")
    _ -> Passed
  }
}

fn min_length(field: String, min: Int) -> MatchResult {
  case string.length(field) < min {
    True -> Failed("must be at least " <> int.to_string(min) <> " characters")
    _ -> Passed
  }
}

fn max_length(field: _, max: Int) -> MatchResult {
  case string.length(field) > max {
    True -> Failed("must be at most " <> int.to_string(max) <> " characters")
    _ -> Passed
  }
}

fn email(field: _) -> MatchResult {
  let valid = case
    regex.from_string(
      "/^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*$/",
    )
  {
    Ok(re) -> regex.check(with: re, content: field)
    Error(_) -> False
  }

  case valid {
    True -> Passed
    False -> Failed("must be a valid email address")
  }
}
