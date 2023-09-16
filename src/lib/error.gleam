import sqlight

pub type AppError {
  NotFound
  SqlightError(sqlight.Error)
}
