context("citation metrics")

test_that("get_publication_metrics calculates common citation indices", {
  pubs <- data.frame(cites = c(10, 8, 5, 4, 3, 0, NA))

  metrics <- get_publication_metrics(pubs)

  expect_equal(metrics$total_cites, 30)
  expect_equal(metrics$h_index, 4)
  expect_equal(metrics$g_index, 5)
  expect_equal(metrics$i10_index, 1)
  expect_equal(metrics$i50_index, 0)
  expect_equal(metrics$i100_index, 0)
  expect_equal(metrics$num_publications, 7)
})

test_that("get_publication_metrics returns NA metrics for unavailable data", {
  metrics <- get_publication_metrics(NA)

  expect_true(all(is.na(metrics)))
  expect_equal(names(metrics), c(
    "total_cites", "h_index", "g_index", "i10_index",
    "i50_index", "i100_index", "num_publications"
  ))
})
