context("h-index over the years")

test_that("the h-index of one year is the largest k with k papers at k cites", {
    expect_equal(scholar:::h_index_of(c(5, 3, 3, 2, 1)), 3L)
    expect_equal(scholar:::h_index_of(c(1, 1, 1)), 1L)
    expect_equal(scholar:::h_index_of(c(10)), 1L)
    expect_equal(scholar:::h_index_of(c(0, 0)), 0L)
    expect_equal(scholar:::h_index_of(numeric(0)), 0L)
})

test_that("a year counts what had accumulated by then", {
    histories <- list(
        data.frame(year = 2001:2003, cites = c(0, 2, 3), pubid = "a"),
        data.frame(year = 2001:2003, cites = c(1, 1, 1), pubid = "b"))
    out <- scholar:::h_index_from_histories(histories)

    expect_equal(out$year, 2001:2003)
    ## 2001: only b has a citation, so one paper clears one cite
    ## 2002: both at two cites
    ## 2003: a at five and b at three, still only two papers
    expect_equal(out$h_index, c(1L, 2L, 2L))
    expect_equal(out$citations, c(1L, 4L, 8L))
})

test_that("the h-index never falls as years advance", {
    set.seed(11)
    for (trial in 1:20) {
        papers <- sample(2:6, 1)
        years <- 2000 + seq_len(8)
        histories <- lapply(seq_len(papers), function(i) {
            data.frame(year = years,
                       cites = sample(0:4, length(years), replace = TRUE),
                       pubid = paste0("p", i))
        })
        out <- scholar:::h_index_from_histories(histories)
        expect_true(all(diff(out$h_index) >= 0))
        expect_lte(max(out$h_index), papers)
    }
})

test_that("gaps in a history are filled from the other papers", {
    histories <- list(
        data.frame(year = c(2005L, 2007L), cites = c(4L, 6L), pubid = "a"),
        data.frame(year = 2006L, cites = 3L, pubid = "b"),
        data.frame(year = NA_real_, cites = 9L, pubid = "unreported"))
    out <- scholar:::h_index_from_histories(histories)
    expect_equal(out$year, 2005:2007)
    expect_equal(out$h_index, c(1L, 2L, 2L))
})

test_that("a profile with nothing cited yields an empty history", {
    pubs <- data.frame(pubid = c("a", "b"), cites = c(0, NA), stringsAsFactors = FALSE)
    out <- get_h_index_history("abc", publications = pubs)
    expect_equal(nrow(out), 0)
    expect_equal(names(out), c("year", "h_index", "citations"))

    empty <- data.frame(pubid = character(), cites = numeric())
    expect_equal(nrow(get_h_index_history("abc", publications = empty)), 0)
})

test_that("the delay argument is checked before any request", {
    expect_error(get_h_index_history("abc", delay = -1), "non-negative")
    expect_error(get_h_index_history("abc", delay = NA_real_), "non-negative")
})

test_that("histories are cached, so a second call makes no request", {
    calls <- 0
    with_mocked_bindings(
        get_article_cite_history = function(id, article) {
            calls <<- calls + 1
            data.frame(year = 2010:2012, cites = c(1, 2, 3), pubid = article)
        },
        code = {
            pubs <- data.frame(pubid = "a", cites = 6, stringsAsFactors = FALSE)
            first <- get_h_index_history("cachedprofileX", publications = pubs,
                                         flush = TRUE)
            second <- get_h_index_history("cachedprofileX", publications = pubs)
        },
        .package = "scholar"
    )
    expect_equal(calls, 1)
    expect_equal(first$h_index, second$h_index)
})
