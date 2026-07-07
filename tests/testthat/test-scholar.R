context("scholar tests - online")

skip_if_no_scholar_data <- function(x) {
  if (is.null(x) || (length(x) == 1 && is.na(x))) {
    skip("Google Scholar data is unavailable for this query")
  }
}

skip_if_no_publications <- function(x) {
  skip_if_no_scholar_data(x)
  if (!is.data.frame(x) || nrow(x) == 0) {
    skip("Google Scholar publications are unavailable for this query")
  }
}

test_that("get_profile works", {
    skip_on_cran()
    skip_if_offline()
    p <- get_profile("B7vSqZsAAAAJ")
    skip_if_no_scholar_data(p)
    expect_is(p, "list")
    expect_true(nzchar(p[["name"]]))
})

test_that("get_complete_authors works (single)", {
  skip_on_cran()
  skip_if_offline()
  id = "B7vSqZsAAAAJ"
  pubs = get_publications(id)
  skip_if_no_publications(pubs)
  result = get_complete_authors(id, pubs$pubid[1])
  expect_equal(length(result), 1)
})

test_that("get_complete_authors works (vector)", {
  skip_on_cran()
  skip_if_offline()
  id = "B7vSqZsAAAAJ"
  pubs = get_publications(id)
  skip_if_no_publications(pubs)
  result = get_complete_authors(id, pubs$pubid[1:2])
  expect_equal(length(result), 2)
})

test_that("get_citation_history works", {
    skip_on_cran()
    skip_if_offline()
    h <- get_citation_history("B7vSqZsAAAAJ")
    skip_if_no_scholar_data(h)
    expect_is(h, 'data.frame')
    expect_equal(names(h), c("year", "cites"))
})

test_that("get_article_cite_history works", {
  skip_on_cran()
  skip_if_offline()
  expect_is(ach <- get_article_cite_history("B7vSqZsAAAAJ", "qxL8FJ1GzNcC"),
            'data.frame')
  expect_equal(names(ach), c("year", "cites", "pubid"))
})

test_that("get_profile works", {
    skip_on_cran()
    skip_if_offline()
    id <- "B7vSqZsAAAAJ"
    pubs <- scholar::get_publications(id)
    skip_if_no_publications(pubs)
    profile <- scholar::get_profile(id)
    skip_if_no_scholar_data(profile)
    expect_is(author_position(pubs$author, profile$name), "data.frame")

    h <- get_citation_history(id)
    skip_if_no_scholar_data(h)
    expect_is(h, 'data.frame')
    expect_equal(names(h), c("year", "cites"))
})


test_that("get_publication_abstract works", {
  skip_on_cran()
  skip_if_offline()
  id <- 'K6EVDoYAAAAJ'
  #pub <- scholar::get_publications(id)
  pub_id <- "HIFyuExEbWQC" # pub[1,]$pubid

  abst <- scholar::get_publication_abstract(id, pub_id)
  #message(paste0(" ",stringr::str_sub(abst, 1, 21)))
  testthat::expect_equal(stringr::str_sub(abst,1,20), "Practitioner Summary")
})

test_that("get_publication_url works", {
  skip_on_cran()
  skip_if_offline()
  id <- 'K6EVDoYAAAAJ'
  #pub <- scholar::get_publications(id)
  pub_id <- "HIFyuExEbWQC" #pub_id <- pub[1,]$pubid

  url <- scholar::get_publication_url(id, pub_id)
  # message(paste0(" ",stringr::str_sub(url, 1, 8)))
  testthat::expect_equal(stringr::str_sub(url, 1,8), "https://")
})



# Here we could add tests that use cached data
# context("scholar tests - offline")

