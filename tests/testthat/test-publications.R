context("publication parsing")

test_that("parse_citation_counts handles formatted and struck-through text", {
  html <- paste0(
    "<html><body>",
    "<a class='gsc_a_ac'>1,234</a>",
    "<a class='gsc_a_ac'></a>",
    "<a class='gsc_a_ac'><span>1\u03362\u03363\u0336</span><br>45</a>",
    "</body></html>"
  )
  nodes <- xml2::read_html(html) %>% rvest::html_nodes(".gsc_a_ac")

  expect_equal(scholar:::parse_citation_counts(nodes), c(1234, 0, 45))
})

test_that("fill_publication_authors only fetches truncated author lists", {
  pubs <- data.frame(
    title = c("A", "B", "C"),
    author = c("A Author, B Author", "C Author, ...", "D Author, ..."),
    journal = c("J1", "J2", "J3"),
    number = c("", "", ""),
    cites = c(1, 2, 3),
    year = c(2020, 2021, 2022),
    cid = c("c1", "c2", "c3"),
    pubid = c("p1", "p2", "p3"),
    stringsAsFactors = FALSE
  )
  fetched <- character(0)
  fetcher <- function(id, pubid, delay, initials) {
    fetched <<- c(fetched, pubid)
    paste("complete", pubid)
  }

  out <- scholar:::fill_publication_authors(
    pubs, "scholarid", delay = 0, initials = FALSE, author_fetcher = fetcher
  )

  expect_equal(fetched, c("p2", "p3"))
  expect_equal(out$author, c("A Author, B Author", "complete p2", "complete p3"))
})

test_that("fill_publication_authors keeps original author when completion fails", {
  pubs <- data.frame(
    author = c("A Author, ...", "B Author, ..."),
    pubid = c("p1", "p2"),
    stringsAsFactors = FALSE
  )
  fetcher <- function(id, pubid, delay, initials) {
    if (pubid == "p1") NA_character_ else ""
  }

  out <- scholar:::fill_publication_authors(
    pubs, "scholarid", delay = 0, initials = FALSE, author_fetcher = fetcher
  )

  expect_equal(out$author, pubs$author)
})
