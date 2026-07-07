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
