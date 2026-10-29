context("scholar ID search parsing")

test_that("parse_scholar_id_search extracts authors and next page", {
  html <- paste0(
    "<html><body>",
    "<div class='gs_ai_chpr'>",
    "<h3 class='gs_ai_name'><a href='/citations?user=abc123AAAAJ&hl=en'>Hao Xu</a></h3>",
    "<div class='gs_ai_aff'>University A</div>",
    "<div class='gs_ai_eml'>Verified email at example.edu</div>",
    "<a class='gs_ai_one_int'>Machine learning</a>",
    "<a class='gs_ai_one_int'>Statistics</a>",
    "</div>",
    "<div class='gs_ai_chpr'>",
    "<h3 class='gs_ai_name'><a href='https://scholar.google.com/citations?user=def456BBBBJ&hl=en'>H Xu</a></h3>",
    "<div class='gs_ai_aff'>Institute B</div>",
    "</div>",
    "<button aria-label='Next' onclick=\"window.location='/citations?view_op=search_authors&hl=en&mauthors=hao+xu&after_author=E1J5AEv9__8J&astart=10'\">Next</button>",
    "</body></html>"
  )

  parsed <- scholar:::parse_scholar_id_search(
    xml2::read_html(html),
    site = "https://scholar.google.com"
  )

  expect_equal(parsed$results$id, c("abc123AAAAJ", "def456BBBBJ"))
  expect_equal(parsed$results$name, c("Hao Xu", "H Xu"))
  expect_equal(parsed$results$affiliation, c("University A", "Institute B"))
  expect_equal(parsed$results$email, c("Verified email at example.edu", ""))
  expect_equal(parsed$results$interests[1], "Machine learning; Statistics")
  expect_equal(
    parsed$results$url[1],
    "https://scholar.google.com/citations?user=abc123AAAAJ&hl=en"
  )
  expect_equal(
    parsed$next_url,
    "https://scholar.google.com/citations?view_op=search_authors&hl=en&mauthors=hao+xu&after_author=E1J5AEv9__8J&astart=10"
  )
})

test_that("parse_scholar_id_search handles empty author results", {
  parsed <- scholar:::parse_scholar_id_search(
    xml2::read_html("<html><body>No authors</body></html>"),
    site = "https://scholar.google.com"
  )

  expect_equal(nrow(parsed$results), 0)
  expect_true(is.na(parsed$next_url))
})

test_that("grab_id ignores trailing URL query parameters", {
  expect_equal(
    scholar:::grab_id("/citations?user=abc123AAAAJ&hl=en"),
    "abc123AAAAJ"
  )
})

test_that("search_scholar_ids validates scalar inputs", {
  expect_error(search_scholar_ids(NA_character_), "non-empty character")
  expect_error(search_scholar_ids("hao xu", max_pages = NA_real_), "positive number")
  expect_error(search_scholar_ids("hao xu", delay = Inf), "non-negative number")
})

test_that("a refused author search is not retried with every spelling of the name", {
    ## get_scholar_id tries several query variants. When the first one cannot be
    ## fetched at all, the rest meet the same wall; each is another request
    ## against an endpoint that is refusing us.
    withr::local_options(list(scholar_warned = NULL, scholar_degraded = TRUE))
    urls <- character(0)
    with_mocked_bindings(
        get_scholar_resp = function(url, attempts_left = 5) {
            urls <<- c(urls, url)
            NULL
        },
        {
            out <- suppressWarnings(get_scholar_id(first_name = "a", last_name = "b",
                                                   affiliation = "c"))
        },
        .package = "scholar"
    )
    expect_true(is.na(out))
    expect_length(urls, 1)
})

test_that("a page with no matching author still tries the other variants", {
    ## The opposite case must keep working: an answer with no ids is not a
    ## refusal, so the next spelling is worth a try.
    withr::local_options(list(scholar_warned = NULL))
    urls <- character(0)
    with_mocked_bindings(
        get_scholar_resp = function(url, attempts_left = 5) {
            urls <<- c(urls, url)
            structure(list(status_code = 200L, url = url), class = "response")
        },
        read_scholar_html = function(resp) xml2::read_html("<html><body></body></html>"),
        scholar_response_text = function(resp) "<html><body></body></html>",
        {
            out <- suppressMessages(get_scholar_id(first_name = "a", last_name = "b"))
        },
        .package = "scholar"
    )
    expect_true(is.na(out))
    expect_gt(length(urls), 1)
})
