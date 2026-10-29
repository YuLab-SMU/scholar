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
    withr::local_options(list(scholar_warned = NULL))
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

scholar_response <- function(status, url = "", headers = NULL) {
    structure(list(status_code = status, url = url, headers = headers),
              class = "response")
}

test_that("requests look like a browser rather than a library", {
    withr::local_options(list(scholar_user_agent = NULL, scholar_accept_language = NULL))
    withr::local_envvar(list(SCHOLAR_USER_AGENT = NA, SCHOLAR_ACCEPT_LANGUAGE = NA))

    cfg <- scholar:::scholar_headers()
    expect_match(cfg[[1]]$options$useragent, "Mozilla")
    expect_equal(unname(cfg[[2]]$headers[["Accept-Language"]]), "en-US,en;q=0.9")

    withr::local_options(list(scholar_user_agent = "curl/8.0.1"))
    expect_equal(scholar:::scholar_headers()[[1]]$options$useragent, "curl/8.0.1")
})

test_that("a Scholar ID option falls back to its environment variable", {
    withr::local_options(list(scholar_user_agent = NULL))
    withr::local_envvar(list(SCHOLAR_USER_AGENT = "agent/from/env"))
    expect_equal(scholar:::scholar_user_agent(), "agent/from/env")

    withr::local_envvar(list(SCHOLAR_USER_AGENT = ""))
    expect_match(scholar:::scholar_user_agent(), "Mozilla")
})

test_that("sign-in and captcha interstitials are recognised", {
    expect_true(scholar:::is_scholar_interstitial(
        scholar_response(200, "https://accounts.google.com/v3/signin/identifier?continue=x")))
    expect_true(scholar:::is_scholar_interstitial(
        scholar_response(200, "https://www.google.com/sorry/index?continue=x")))
    expect_false(scholar:::is_scholar_interstitial(
        scholar_response(200, "https://scholar.google.com/citations?user=abc")))
    expect_false(scholar:::is_scholar_interstitial(scholar_response(200)))
})

test_that("get_scholar_resp does not retry a request Scholar sent to sign-in", {
    withr::local_options(list(scholar_warned = NULL))
    calls <- 0
    fake_get <- function(url, handle) {
        calls <<- calls + 1
        scholar_response(200, "https://accounts.google.com/Login?continue=x&service=citations")
    }

    with_mocked_bindings(
        scholar_get = fake_get,
        scholar_handle = function() NULL,
        scholar_sleep = function(time) NULL,
        {
            expect_warning(
                resp <- get_scholar_resp("https://scholar.google.com/citations",
                                         attempts_left = 5),
                "sign-in")
        },
        .package = "scholar"
    )

    expect_null(resp)
    expect_equal(calls, 1)
})

test_that("a 403 is reported as blocked instead of a wrong ID", {
    withr::local_options(list(scholar_warned = NULL))
    with_mocked_bindings(
        scholar_get = function(url, handle) scholar_response(403, "https://scholar.google.com/scholar"),
        scholar_handle = function() NULL,
        scholar_sleep = function(time) NULL,
        {
            expect_warning(
                expect_null(get_scholar_resp("https://scholar.google.com/scholar",
                                             attempts_left = 2)),
                "refused the request")
        },
        .package = "scholar"
    )
})

test_that("rate limited requests are retried with a growing delay", {
    calls <- 0
    delays <- numeric(0)
    fake_get <- function(url, handle) {
        calls <<- calls + 1
        scholar_response(if (calls < 3) 429L else 200L, "https://scholar.google.com/citations")
    }

    with_mocked_bindings(
        scholar_get = fake_get,
        scholar_handle = function() NULL,
        scholar_sleep = function(time) delays <<- c(delays, time),
        {
            resp <- get_scholar_resp("https://scholar.google.com/citations", attempts_left = 4)
        },
        .package = "scholar"
    )

    expect_equal(httr::status_code(resp), 200L)
    expect_equal(calls, 3)
    expect_equal(length(delays), 2)
    expect_true(diff(delays) > 0)
})

test_that("a Retry-After longer than the budget abandons the request", {
    withr::local_options(list(scholar_warned = NULL))
    calls <- 0
    with_mocked_bindings(
        scholar_get = function(url, handle) {
            calls <<- calls + 1
            scholar_response(429L, "https://scholar.google.com/citations",
                             headers = structure(list(`retry-after` = "3600"),
                                                 class = "insensitive"))
        },
        scholar_handle = function() NULL,
        scholar_sleep = function(time) NULL,
        {
            expect_warning(
                expect_null(get_scholar_resp("https://scholar.google.com/citations",
                                             attempts_left = 5)),
                "rate limiting")
        },
        .package = "scholar"
    )
    expect_equal(calls, 1)
})

test_that("backoff grows, is capped, and obeys Retry-After", {
    withr::local_options(list(scholar_retry_delay = 1, scholar_retry_max_delay = 30))
    delays <- vapply(1:8, function(i) scholar:::scholar_backoff_delay(i), numeric(1))
    expect_true(all(diff(delays) >= 0))
    expect_lt(delays[[1]], 2)
    expect_equal(delays[[8]], 30)
    expect_equal(scholar:::scholar_backoff_delay(1, retry_after = 5), 5)
    # absent Retry-After: plain geometric backoff, so attempt 1 stays under 2 s
    expect_lt(scholar:::scholar_backoff_delay(1, retry_after = NA_real_), 2)
    # a wait Google asks for beyond the budget means retrying is pointless
    expect_identical(scholar:::scholar_backoff_delay(1, retry_after = 3600), Inf)
})

test_that("the request settings reach httr as separate arguments", {
    captured <- NULL
    fake_get <- function(url = NULL, config = list(), ..., handle = NULL) {
        captured <<- list(dots = list(...), config = config)
        structure(list(status_code = 200L), class = "response")
    }

    withr::local_options(list(scholar_cookie = NULL, scholar_cookie_file = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA))
    with_mocked_bindings(
        GET = fake_get,
        .package = "httr",
        scholar:::scholar_get("https://scholar.google.com/citations?user=abc",
                              handle = NULL)
    )
    ## httr drops a list of settings passed as a single argument, which sends
    ## the default libcurl User-Agent that Scholar answers with HTTP 403.
    settings <- captured$dots
    expect_equal(length(settings), 3)
    expect_true(all(vapply(settings, function(x) inherits(x, "request"), logical(1))))
    agents <- unlist(lapply(settings, function(x) x$options$useragent))
    expect_match(agents, "Mozilla")
    expect_false(any(grepl("libcurl", agents)))
    header_names <- names(settings[[2]]$headers)
    expect_equal(header_names, c("Accept", "Accept-Encoding", "Accept-Language"))
})
