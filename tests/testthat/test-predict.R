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
