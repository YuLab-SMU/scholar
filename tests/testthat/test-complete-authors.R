context("complete author parsing")

test_that("tidy_id removes URL query parameters and extracts user ids", {
  expect_equal(scholar::tidy_id("g5LA4-oAAAAJ&hl=en"), "g5LA4-oAAAAJ")
  expect_equal(
    scholar::tidy_id("https://scholar.google.com/citations?user=g5LA4-oAAAAJ&hl=en"),
    "g5LA4-oAAAAJ"
  )
})

test_that("complete_authors_url includes user and citation_for_view parameters", {
  url <- scholar:::complete_authors_url(
    "g5LA4-oAAAAJ&hl=en",
    "abc123",
    site = "https://scholar.google.com"
  )

  expect_equal(
    url,
    "https://scholar.google.com/citations?view_op=view_citation&hl=en&user=g5LA4-oAAAAJ&citation_for_view=g5LA4-oAAAAJ:abc123"
  )
})

test_that("format_authors keeps NA complete-author responses as NA", {
  expect_true(is.na(scholar:::format_authors(NA_character_)))
})
