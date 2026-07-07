context("scholar response handling")

test_that("get_scholar_resp retries transient 404 responses", {
  calls <- 0
  fake_get <- function(url, handle) {
    calls <<- calls + 1
    status <- if (calls == 1) 404L else 200L
    structure(list(status_code = status), class = "response")
  }

  with_mocked_bindings(
    scholar_get = fake_get,
    scholar_handle = function() NULL,
    scholar_sleep = function(time) NULL,
    {
      resp <- get_scholar_resp("https://scholar.google.com/citations", attempts_left = 2)
    },
    .package = "scholar"
  )

  expect_equal(httr::status_code(resp), 200L)
  expect_equal(calls, 2)
})

test_that("get_scholar_resp warns after final 404 attempt", {
  fake_get <- function(url, handle) {
    structure(list(status_code = 404L), class = "response")
  }

  with_mocked_bindings(
    scholar_get = fake_get,
    scholar_handle = function() NULL,
    {
      expect_warning(
        resp <- get_scholar_resp("https://scholar.google.com/citations", attempts_left = 1),
        "Page 404"
      )
    },
    .package = "scholar"
  )

  expect_null(resp)
})
