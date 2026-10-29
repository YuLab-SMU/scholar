context("SCImago journal ranking sources")

ranking_fixture <- function(text = NULL) {
    path <- tempfile(fileext = ".csv")
    writeLines(text %||% paste0(
        "Rank;Sourceid;Title;Type;Issn;SJR;H index\n",
        "1;12345;Nature;journal;0028-0836;45.321;1000\n",
        "2;12346;Science;journal;0036-8075;38.120;900\n"), path)
    path
}

test_that("the live export is tried before the archived copy", {
    withr::local_options(list(scholar_scimago_url = NULL))
    withr::local_envvar(list(SCHOLAR_SCIMAGO_URL = NA))

    sources <- scholar:::scimagojr_sources()
    expect_equal(sources[[1]], scholar:::scimagojr_official_url)
    expect_match(sources[[2]], paste0("^https://web\\.archive\\.org/web/",
                                      scholar:::scimagojr_snapshot, "id_/"))
})

test_that("a configured source replaces the defaults", {
    path <- ranking_fixture()
    withr::local_options(list(scholar_scimago_url = path))
    expect_equal(scholar:::scimagojr_sources()[[1]], path)

    withr::local_options(list(scholar_scimago_url = NULL))
    withr::local_envvar(list(SCHOLAR_SCIMAGO_URL = path))
    expect_equal(scholar:::scimagojr_sources()[[1]], path)

    expect_equal(scholar:::scimagojr_sources("https://mirror.example/rank.csv"),
                 "https://mirror.example/rank.csv")
})

test_that("a saved export is read like a downloaded one", {
    table <- scholar:::download_scimagojr_rankings(url = ranking_fixture())
    expect_s3_class(table, "data.frame")
    expect_equal(nrow(table), 2)
    expect_equal(table$Title, c("Nature", "Science"))
})

test_that("a challenge page is rejected even when it is served as a success", {
    blocked <- ranking_fixture("<!DOCTYPE html><html><head><title>Just a moment...</title>")
    ## configured source replaces the defaults, so nothing here reaches the network
    expect_error(scholar:::download_scimagojr_rankings(url = blocked),
                 "not the ranking table", fixed = TRUE)
})

test_that("the archived copy is announced when it is used", {
    table <- NULL
    with_mocked_bindings(
        read_scimagojr_table = function(source) {
            if (identical(source, scholar:::scimagojr_official_url)) NULL
            else paste0("Rank;Sourceid;Title;Type;Issn;SJR;H index\n1;1;Cell;j;0092-8674;50;1")
        },
        code = {
            expect_message(table <- scholar:::download_scimagojr_rankings(),
                           "Internet Archive snapshot")
        },
        .package = "scholar"
    )
    expect_equal(table$Title, "Cell")
})

test_that("a journal can still be looked up from a local table", {
    path <- ranking_fixture()
    withr::local_options(list(scholar_scimago_url = path))
    out <- get_journalrank("Nature")
    expect_s3_class(out, "data.frame")
    expect_true(nrow(out) >= 1)
    expect_equal(out$Title, "Nature")
})
