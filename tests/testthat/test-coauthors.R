context("coauthor parsing")

test_that("parse_colleague_list reads full colleagues page", {
  html <- paste0(
    "<html><body>",
    "<div id='gsc_codb_data' data-max='107'></div>",
    "<div class='gs_ai'><h3 class='gs_ai_name'>",
    "<a href='/citations?hl=en&amp;user=abc123AAAAJ'>Alice A</a>",
    "</h3></div>",
    "<div class='gs_ai'><h3 class='gs_ai_name'>",
    "<a href='/citations?hl=en&amp;user=def456BBBBJ'>Bob B</a>",
    "</h3></div>",
    "<div class='gs_ai'><h3 class='gs_ai_name'>",
    "<a href='/citations?hl=en&amp;user=ghi789CCCCJ'>Carol C</a>",
    "</h3></div>",
    "</body></html>"
  )
  url_template <- "https://scholar.google.com/citations?hl=en&user=%s"

  out <- scholar:::parse_colleague_list(
    xml2::read_html(html),
    author_name = "Main Author",
    author_url = "https://scholar.google.com/citations?hl=en&user=main",
    n_coauthors = 2,
    url_template = url_template
  )

  expect_equal(nrow(out), 2)
  expect_equal(out$author, c("Main Author", "Main Author"))
  expect_equal(out$coauthors, c("Alice A", "Bob B"))
  expect_equal(
    out$coauthors_url,
    c(
      "https://scholar.google.com/citations?hl=en&user=abc123AAAAJ",
      "https://scholar.google.com/citations?hl=en&user=def456BBBBJ"
    )
  )
})

test_that("parse_colleague_list supports all available coauthors", {
  html <- paste0(
    "<html><body>",
    "<div class='gs_ai'><h3 class='gs_ai_name'>",
    "<a href='/citations?user=abc123AAAAJ'>Alice A</a>",
    "</h3></div>",
    "<div class='gs_ai'><h3 class='gs_ai_name'>",
    "<a href='/citations?user=def456BBBBJ'>Bob B</a>",
    "</h3></div>",
    "</body></html>"
  )

  out <- scholar:::parse_colleague_list(
    xml2::read_html(html),
    author_name = "Main Author",
    author_url = "https://scholar.google.com/citations?hl=en&user=main",
    n_coauthors = Inf,
    url_template = "https://scholar.google.com/citations?hl=en&user=%s"
  )

  expect_equal(out$coauthors, c("Alice A", "Bob B"))
})

test_that("parse_profile_coauthor_list remains available as fallback", {
  html <- paste0(
    "<html><body>",
    "<a tabindex='-1' href='/citations?hl=en&amp;user=abc123AAAAJ'>Alice A</a>",
    "<a tabindex='-1' href='/citations?hl=en&amp;user=def456BBBBJ'>Bob B</a>",
    "</body></html>"
  )

  out <- scholar:::parse_profile_coauthor_list(
    xml2::read_html(html),
    author_name = "Main Author",
    author_url = "https://scholar.google.com/citations?hl=en&user=main",
    n_coauthors = 10,
    url_template = "https://scholar.google.com/citations?hl=en&user=%s"
  )

  expect_equal(out$coauthors, c("Alice A", "Bob B"))
})
