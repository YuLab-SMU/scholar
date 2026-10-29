context("scholar session configuration")

cookie_file <- function(lines) {
    path <- file.path(tempdir(), "scholar-cookies.txt")
    writeLines(lines, path)
    path
}

test_that("no session is attached unless one was supplied", {
    withr::local_options(list(scholar_cookie = NULL, scholar_cookie_file = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA, SCHOLAR_COOKIE_FILE = NA))
    settings <- scholar:::scholar_headers("https://scholar.google.com/citations")
    expect_equal(length(settings), 3)
    expect_length(scholar:::scholar_cookie_pairs(), 0)
})

test_that("a session is taken from the option and from a cookie file", {
    withr::local_options(list(scholar_cookie = NULL, scholar_cookie_file = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA, SCHOLAR_COOKIE_FILE = NA))

    options(scholar_cookie = "NID=from-option")
    expect_equal(scholar:::scholar_cookie(), "NID=from-option")

    path <- cookie_file(c(
        "# Netscape HTTP Cookie File",
        "#HttpOnly_.google.com\tTRUE\t/\tTRUE\t1800000000\tNID\tfrom-file",
        ".google.com\tTRUE\t/\tFALSE\t0\tSCHOLAR_DT\tdeadbeef",
        "not-a-cookie-row"
    ))
    options(scholar_cookie_file = path)
    expect_equal(
        scholar:::scholar_cookie(),
        "SCHOLAR_DT=deadbeef; NID=from-option"
    )

    options(scholar_cookie = NULL)
    expect_equal(scholar:::scholar_cookie(),
                 "NID=from-file; SCHOLAR_DT=deadbeef")
})

test_that("a file session can be supplied by the environment", {
    withr::local_options(list(scholar_cookie = NULL, scholar_cookie_file = NULL))
    path <- cookie_file("GOSRC=xyz; SIDCC=qqq")
    withr::local_envvar(list(SCHOLAR_COOKIE_FILE = path, SCHOLAR_COOKIE = NA))
    expect_equal(scholar:::scholar_cookie(), "GOSRC=xyz; SIDCC=qqq")
})

test_that("the session is sent as CURLOPT_COOKIE, not as a custom header", {
    withr::local_options(list(scholar_cookie = "NID=abc; GSP=xyz", scholar_cookie_file = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA, SCHOLAR_COOKIE_FILE = NA))
    settings <- scholar:::scholar_headers("https://scholar.google.com/citations")

    ## A Cookie entry among the custom headers would replace the cookies Google
    ## set on the reused handle, and be stripped on a redirect to a sign-in host.
    expect_false("Cookie" %in% names(settings[[2]]$headers))
    expect_equal(settings[[4]]$options$cookie, "NID=abc;GSP=xyz")
    expect_equal(unname(settings[[2]]$headers[["Accept-Encoding"]]), "gzip, deflate")
})

test_that("a session is never sent to a mirror that is not Google", {
    withr::local_options(list(scholar_cookie = "NID=secret", scholar_cookie_file = NULL,
                              scholar_warned = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA))

    expect_warning(settings <- scholar:::scholar_headers("https://scholar.lanfanshu.cn/citations"),
                   "not a Google host")
    expect_equal(length(settings), 3)
    ## Google's own hosts, including country domains, do get it
    expect_equal(length(scholar:::scholar_headers("https://scholar.google.com.hk/citations")), 4)
})

test_that("cookie values are split into named pairs", {
    withr::local_options(list(scholar_cookie = "NID=abc; SOCS=CAISHY", scholar_cookie_file = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA))
    pairs <- scholar:::scholar_cookie_pairs()
    expect_equal(names(pairs), c("NID", "SOCS"))
    expect_equal(unname(pairs), c("abc", "CAISHY"))
})

test_that("set_scholar_cookie stores what it is given and refuses nonsense", {
    withr::local_options(list(scholar_cookie = NULL, scholar_cookie_file = NULL))
    path <- cookie_file("NID=abc")

    set_scholar_cookie(cookie = "NID=one")
    expect_equal(getOption("scholar_cookie"), "NID=one")
    set_scholar_cookie(file = path)
    expect_equal(getOption("scholar_cookie_file"), path)
    set_scholar_cookie(cookie = "NID=two")
    expect_equal(getOption("scholar_cookie"), "NID=two")

    expect_error(set_scholar_cookie(file = "~/no-such-cookies.txt"), "existing")
    expect_error(set_scholar_cookie(cookie = 42), "single string")
    expect_error(set_scholar_cookie(cookie = c("a=1", "b=2")), "single string")
})

test_that("a refused author search says so once, and not at all when silenced", {
    withr::local_options(list(scholar_cookie = NULL, scholar_degraded = TRUE,
                              scholar_warned = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA))

    expect_warning(scholar:::scholar_refused(), "Author search is deprecated")
    expect_silent(scholar:::scholar_refused())

    options(scholar_degraded = FALSE)
    withr::local_options(list(scholar_warned = NULL))
    expect_silent(scholar:::scholar_refused())
})

test_that("an expired session is reported as expired", {
    withr::local_options(list(scholar_cookie = "NID=abc", scholar_degraded = TRUE,
                              scholar_warned = NULL))
    withr::local_envvar(list(SCHOLAR_COOKIE = NA))
    expect_warning(scholar:::scholar_refused(), "even with the session")
})

test_that("a request carries the configured timeout", {
    withr::local_options(list(scholar_timeout = 7))
    withr::local_envvar(list(SCHOLAR_TIMEOUT = NA))
    expect_equal(scholar:::scholar_headers()[[3]]$options$timeout, 7000)
})
