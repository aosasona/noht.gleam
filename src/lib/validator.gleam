pub type Rule {
  Required
  MinLength(Int)
  MaxLength(Int)
  Email
}

pub type ValidationError {
  ValidationError(name: String, errors: List(String))
  Nil
}

pub fn validate_multiple(
  fields: List(#(string, _, List(Rule))),
) -> List(#(string, _, List(String))) {
  todo
}

/// validate a list of rules on a field
pub fn validate_field(field: _, rules: List(Rule)) -> List(String) {
  todo
}

/// validate a single rule on a field
fn validate(field: _, rule: Rule) -> String {
  todo
}
