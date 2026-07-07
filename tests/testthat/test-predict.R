context("h-index prediction")

test_that("predict_h_index returns NA when profile is unavailable", {
  testthat::with_mocked_bindings(
    {
      expect_true(is.na(predict_h_index("missing-profile")))
    },
    get_num_articles = function(id) 1,
    get_profile = function(id) NA
  )
})

test_that("predict_h_index returns NA when publication metrics are unavailable", {
  testthat::with_mocked_bindings(
    {
      expect_true(is.na(predict_h_index("missing-publications")))
    },
    get_num_articles = function(id) NA_integer_,
    get_profile = function(id) list(h_index = 10),
    get_oldest_article = function(id) Inf,
    get_num_distinct_journals = function(id) NA_integer_,
    get_num_top_journals = function(id, journals) NA_integer_
  )
})
