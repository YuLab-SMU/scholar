context("author position")

test_that("author_position returns NA normalized position for missing authors", {
  out <- author_position(
    authorlist = c("A Smith, B Jones", "A Smith, C Brown"),
    author = "Missing"
  )

  expect_true(all(is.na(out$Position)))
  expect_true(all(is.na(out$Position_Normalized)))
})

test_that("author_position returns NA normalized position for truncated authors", {
  out <- author_position(
    authorlist = c("A Smith, ..."),
    author = "Smith"
  )

  expect_equal(out$Position, 1)
  expect_true(is.na(out$Position_Normalized))
})
