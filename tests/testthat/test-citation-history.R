context("citation history parsing")

test_that("align_citation_history fills missing citation years", {
  years <- 2018:2020
  vals <- c(2, 5)
  style <- c("left:1px;z-index:1", "left:2px;z-index:3")

  out <- scholar:::align_citation_history(years, vals, style)

  expect_equal(out$year, years)
  expect_equal(out$cites, c(5, 0, 2))
})

test_that("align_citation_history tolerates mismatched chart vectors", {
  more_vals <- scholar:::align_citation_history(2019:2020, c(1, 2, 3), character(0))
  bad_style <- scholar:::align_citation_history(2018:2020, c(4, 5), c("left:1px", "left:2px"))

  expect_equal(nrow(more_vals), 2)
  expect_equal(more_vals$cites, c(1, 2))
  expect_equal(nrow(bad_style), 2)
  expect_equal(bad_style$cites, c(4, 5))
})
