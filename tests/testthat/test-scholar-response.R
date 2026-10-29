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

test_that("a captcha served from Scholar itself is not called a redirect", {
    ## The cited-by pages come back as HTTP 200 whose body is the challenge,
    ## with no redirect to google.com/sorry anywhere in it.
    html <- paste0("<html><body><p>Sorry, we can&#39;t verify that you&#39;re not ",
                   "a robot when JavaScript is turned off.</p></body></html>")
    resp <- structure(
        list(status_code = 200L, url = "https://scholar.google.com/scholar?cites=1",
             content = charToRaw(html),
             headers = structure(list(), class = "insensitive")),
        class = "response")

    expect_equal(scholar:::scholar_block_type(resp), "captcha-page")
    message <- scholar:::scholar_blocked_message(resp, 200L)
    expect_false(grepl("google.com/sorry", message, fixed = TRUE))
    expect_match(message, "not a robot")
})

test_that("the reason for a refusal is named correctly", {
    expect_equal(scholar:::scholar_block_type(
        scholar_response(200, "https://accounts.google.com/v3/signin/identifier?continue=x")),
        "sign-in")
    expect_equal(scholar:::scholar_block_type(
        scholar_response(200, "https://www.google.com/sorry/index?continue=x")), "captcha")
    ## a page that carries data, and a plain 403, are not captcha cases: the
    ## status code decides those
    expect_null(scholar:::scholar_block_type(
        scholar_response(200, "https://scholar.google.com/citations?user=abc")))
    expect_null(scholar:::scholar_block_type(
        scholar_response(403, "https://scholar.google.com/scholar")))
})

test_that("the advice matches the cause and carries no stray indentation", {
    ## a newline in the middle of a message would be followed by the source's
    ## own indentation, which reads as broken output
    no_indent <- function(txt) expect_false(grepl("\n    [^ ]", txt))

    sign_in <- scholar:::scholar_blocked_message(
        scholar_response(200, "https://accounts.google.com/Login"), 200, "sign-in")
    expect_match(sign_in, "sign-in page")
    no_indent(sign_in)

    js_captcha <- scholar:::scholar_blocked_message(
        scholar_response(200, "https://scholar.google.com/scholar?cites=1"),
        200, "captcha-page")
    expect_match(js_captcha, "not a robot")
    ## a page served from Scholar's own host must not be blamed on google.com/sorry
    expect_false(grepl("google.com/sorry", js_captcha, fixed = TRUE))
    expect_match(js_captcha, "set_scholar_cookie")
    no_indent(js_captcha)

    refused <- scholar:::scholar_blocked_message(
        scholar_response(403, "https://scholar.google.com/scholar"), 403, NULL)
    expect_match(refused, "HTTP 403")
    no_indent(refused)
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

test_that("a spent waiting budget stops retrying a rate-limited server", {
    withr::local_options(list(scholar_warned = NULL, scholar_retry_budget = 3,
                              scholar_wait_used = 0, scholar_retry_delay = 1,
                              scholar_retry_max_delay = 30))
    calls <- 0
    fake_get <- function(url, handle) {
        calls <<- calls + 1
        scholar_response(429L, "https://scholar.google.com/citations")
    }

    with_mocked_bindings(
        scholar_get = fake_get,
        scholar_handle = function() NULL,
        scholar_sleep = function(time) NULL,
        {
            expect_warning(
                expect_null(get_scholar_resp("https://scholar.google.com/citations",
                                             attempts_left = 5)),
                "waiting budget")
        },
        .package = "scholar"
    )

    ## the first refusal waits about a second, the second about two; the third
    ## would pass a three second budget, so the request is abandoned at two
    expect_equal(calls, 2)
    expect_lte(getOption("scholar_wait_used"), 3)
})

test_that("the waiting budget covers the whole session, not one request", {
    withr::local_options(list(scholar_warned = NULL, scholar_retry_budget = 3,
                              scholar_wait_used = 2.9, scholar_retry_delay = 1,
                              scholar_retry_max_delay = 30))
    calls <- 0
    fake_get <- function(url, handle) {
        calls <<- calls + 1
        scholar_response(429L, "https://scholar.google.com/citations")
    }

    with_mocked_bindings(
        scholar_get = fake_get,
        scholar_handle = function() NULL,
        scholar_sleep = function(time) NULL,
        {
            expect_warning(
                expect_null(get_scholar_resp("https://scholar.google.com/citations",
                                             attempts_left = 5)),
                "waiting budget")
        },
        .package = "scholar"
    )

    ## a hundred seconds left of nothing: the next wait would break the budget,
    ## so one refusal is enough and the server is not hammered for the rest of
    ## the session
    expect_equal(calls, 1)
})
