context("citing articles")

## A trimmed excerpt of a live Scholar result page, kept verbatim so that the
## parser is tested against the markup Google actually serves rather than against
## a description of it.
real_page <- function() {
    path <- test_path("fixtures", "citing-page.html")
    xml2::read_html(path, encoding = "UTF-8")
}

test_that("a real result page is read into one row per citing work", {
    out <- scholar:::parse_citing_page(real_page())

    expect_equal(nrow(out), 2)
    expect_equal(names(out),
                 c("title", "author", "venue", "year", "cites", "url", "cid"))
    expect_equal(out$title[[1]],
                 "Background bias in functional enrichment analysis: Insights from clusterProfiler")
    expect_equal(out$author[[1]], "G Yu")
    expect_equal(out$venue[[1]], "The Innovation Life")
    expect_equal(out$year[[1]], 2025)
    expect_equal(out$cites[[1]], 3L)
    expect_match(out$url[[1]], "^https://the-innovation\\.org")
    ## The key is the number in the work's own "Cited by" link, not the lettered
    ## data-cid attribute of the row.
    expect_equal(out$cid[[1]], "17759105513826976119")
    expect_equal(out$cites[[2]], 10L)
})

test_that("the byline is split with and without a host or a year", {
    expect_equal(
        scholar:::split_byline("A Author\u00a0- Journal of Things, 2019 - example.org"),
        list(author = "A Author", venue = "Journal of Things", year = 2019))
    expect_equal(
        scholar:::split_byline("A Author\u00a0- Book publisher"),
        list(author = "A Author", venue = "Book publisher", year = NA_real_))
    expect_equal(
        scholar:::split_byline("A Author"),
        list(author = "A Author", venue = NA_character_, year = NA_real_))
    expect_equal(
        scholar:::split_byline(NA_character_),
        list(author = NA_character_, venue = NA_character_, year = NA_real_))
    ## a conference number is not a year of record
    expect_equal(
        scholar:::split_byline("A Author\u00a0- Proc. 21st Intl. Conf., 2020"),
        list(author = "A Author", venue = "Proc. 21st Intl. Conf.", year = 2020))
})

test_that("a merged citation key is queried as Scholar writes it", {
    url <- scholar:::citing_page_url("https://scholar.google.com",
                                     "4662368611310421617,17993553171323683785",
                                     start = 20)
    expect_equal(
        url,
        paste0("https://scholar.google.com/scholar?cites=",
               "4662368611310421617,17993553171323683785",
               "&as_sdt=2005&sciodt=0,5&hl=en&start=20"))
})

test_that("citation keys come from the publication table Scholar returned", {
    pubs <- data.frame(pubid = c("a1", "b2"),
                       cid = c("111,222", NA),
                       stringsAsFactors = FALSE)

    expect_equal(scholar:::resolve_citation_keys(pubs, "b2")[[1]]$cid, NA_character_)
    expect_equal(scholar:::resolve_citation_keys(pubs, c("a1", "b2"))[[1]]$cid, "111,222")
    expect_error(scholar:::resolve_citation_keys(pubs, "zz"), "not in")
    expect_error(scholar:::resolve_citation_keys(data.frame(title = "x"), "a1"),
                 "get_publications")
})

test_that("a publication with no citation key is reported and skipped", {
    pubs <- data.frame(pubid = c("b2", "a1"), cid = c(NA, "99"),
                       stringsAsFactors = FALSE)
    out <- NULL
    expect_warning(out <- get_citing_articles("x", c("b2", "a1"), max_pages = 1,
                                              publications = pubs),
                   "no citation key")
    ## the resolvable one is still attempted, and a refusal leaves an empty table
    expect_equal(names(out), names(scholar:::empty_citing_articles()))
})

test_that("arguments are checked before any request is made", {
    expect_error(get_citing_articles("x", character()), "non-empty")
    expect_error(get_citing_articles("x", NA_character_), "non-empty")
    expect_error(get_citing_articles("x", "a1", max_pages = 0), "positive")
})

test_that("a captcha shell yields no rows and is recognised as a refusal", {
    shell <- paste0(
        "<html><body><div id=\"gs_ab_md\"><div class=\"gs_ab_mdw\">",
        "Articles</div></div>",
        "<div id=\"gs_captcha\"></div>",
        "<p>Sorry, we can&#39;t verify that you&#39;re not a robot when ",
        "JavaScript is turned off.</p></body></html>")

    expect_equal(nrow(scholar:::parse_citing_page(xml2::read_html(shell))), 0)
    expect_true(scholar:::scholar_captcha_markup(shell))
})

test_that("a page with data is never called a captcha", {
    expect_false(scholar:::scholar_captcha_markup(
        paste0(readLines(test_path("fixtures", "citing-page.html"), warn = FALSE),
               collapse = "\n")))
    expect_false(scholar:::scholar_captcha_markup(""))
    expect_false(scholar:::scholar_captcha_markup(NA_character_))
})
