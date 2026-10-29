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

test_that("parse_profile_coauthor_list ignores menu items", {
  html <- paste0(
    "<html><body>",
    "<a role='menuitem' tabindex='-1' class='gs_md_li' ",
    "href='/citations?hl=en&amp;user=main&amp;view_op=list_works'>Sort by citations</a>",
    "<a role='menuitem' tabindex='-1' class='gs_md_li' ",
    "href='/citations?hl=en&amp;user=main&amp;view_op=list_works&amp;sortby=pubdate'>Sort by year</a>",
    "<a role='menuitem' tabindex='-1' href='/intl/en/scholar/about.html'>About Scholar</a>",
    "<a tabindex='-1' href='/citations?user=nMP0iF4AAAAJ&amp;hl=en'>Thijs Bol</a>",
    "</body></html>"
  )

  out <- scholar:::parse_profile_coauthor_list(
    xml2::read_html(html),
    author_name = "Main Author",
    author_url = "https://scholar.google.com/citations?hl=en&user=main",
    n_coauthors = 20,
    url_template = "https://scholar.google.com/citations?hl=en&user=%s"
  )

  expect_equal(out$coauthors, "Thijs Bol")
})

test_that("a profile without listed colleagues yields no coauthors", {
  html <- paste0(
    "<html><body>",
    "<a role='menuitem' tabindex='-1' ",
    "href='/citations?hl=en&amp;user=main&amp;view_op=list_works'>Sort by citations</a>",
    "</body></html>"
  )

  out <- scholar:::parse_profile_coauthor_list(
    xml2::read_html(html),
    author_name = "Legacy Author",
    author_url = "https://scholar.google.com/citations?hl=en&user=main",
    n_coauthors = 20,
    url_template = "https://scholar.google.com/citations?hl=en&user=%s"
  )

  expect_equal(nrow(out), 0)
})

test_that("get_profile keeps every colleague, not just the sidebar page", {
    ## The sidebar shows twenty names; the colleagues list behind it is longer.
    ## Capping at twenty made get_profile() and get_coauthors() disagree about
    ## the same person.
    many <- paste0("<html><body><div id='gsc_codb_data' data-max='25'></div>",
        paste(vapply(seq_len(25), function(i) paste0(
            "<div class='gs_ai'><h3 class='gs_ai_name'>",
            "<a href='/citations?hl=en&amp;user=id", i, "AAAAJ'>Colleague ", i,
            "</a></h3></div>"), character(1)), collapse = ""),
        "</body></html>")
    profile <- paste0("<html><body><div id='gsc_prf_in'>Main Author</div>",
                      "<div class='gsc_prf_il'>Somewhere</div>",
                      "<div class='gsc_prf_il'>topic</div>",
                      "</body></html>")

    with_mocked_bindings(
        get_scholar_resp = function(url, attempts_left = 5) {
            structure(list(status_code = 200L, url = url), class = "response")
        },
        read_scholar_html = function(resp) {
            xml2::read_html(if (grepl("list_colleagues", resp$url)) many else profile)
        },
        {
            got <- scholar:::list_coauthors("mainAAAAJ", Inf)
        },
        .package = "scholar"
    )
    expect_equal(nrow(got), 25)

    capped <- NULL
    with_mocked_bindings(
        get_scholar_resp = function(url, attempts_left = 5) {
            structure(list(status_code = 200L, url = url), class = "response")
        },
        read_scholar_html = function(resp) {
            xml2::read_html(if (grepl("list_colleagues", resp$url)) many else profile)
        },
        {
            capped <- scholar:::list_coauthors("mainAAAAJ", 20)
        },
        .package = "scholar"
    )
    ## the cap still works when a caller asks for one
    expect_equal(nrow(capped), 20)
})
