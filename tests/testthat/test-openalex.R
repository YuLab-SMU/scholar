context("OpenAlex author lookup")

author_record <- function(id = "https://openalex.org/A5027320896",
                          orcid = "https://orcid.org/0000-0002-6485-8781",
                          name = "Guangchuang Yu",
                          institutions = list(list(display_name = "Southern Medical University")),
                          stats = list(h_index = 39L, i10_index = 68L),
                          works = 210L, cites = 98765L) {
    list(id = id, orcid = orcid, display_name = name,
         last_known_institutions = institutions,
         works_count = works, cited_by_count = cites, summary_stats = stats)
}

test_that("an OpenAlex author record is flattened into one row", {
    out <- scholar:::parse_openalex_authors(list(author_record()))
    expect_equal(nrow(out), 1)
    expect_equal(out$openalex_id, "A5027320896")
    expect_equal(out$display_name, "Guangchuang Yu")
    expect_equal(out$affiliation, "Southern Medical University")
    expect_equal(out$h_index, 39L)
    expect_equal(out$i10_index, 68L)
    expect_equal(out$works_count, 210L)
    expect_equal(out$url, "https://openalex.org/A5027320896")
})

test_that("missing pieces become NA instead of an error", {
    out <- scholar:::parse_openalex_authors(list(
        author_record(orcid = NULL, institutions = list(), stats = NULL,
                      works = NULL, cites = NULL)))
    expect_equal(out$orcid, NA_character_)
    expect_equal(out$affiliation, NA_character_)
    expect_equal(out$h_index, NA_integer_)
    expect_equal(out$works_count, NA_integer_)
    expect_true(nzchar(out$openalex_id))
    expect_equal(nrow(scholar:::parse_openalex_authors(list())), 0)
})

test_that("the request asks for only the fields the table uses", {
    withr::local_options(list(scholar_openalex_mailto = NULL))
    withr::local_envvar(list(SCHOLAR_OPENALEX_MAILTO = NA))
    url <- scholar:::openalex_authors_url("Guangchuang Yu", per_page = 3)
    expect_match(url, "^https://api.openalex.org/authors\\?search=Guangchuang%20Yu")
    expect_match(url, "per-page=3")
    expect_match(url, "select=id,orcid,display_name")
    expect_false(grepl("mailto=", url, fixed = TRUE))

    withr::local_options(list(scholar_openalex_mailto = "me@example.org"))
    expect_match(scholar:::openalex_authors_url("x y"), "mailto=me@example.org")
})

test_that("arguments are checked", {
    expect_error(search_openalex_authors(""), "non-empty")
    expect_error(search_openalex_authors(NA_character_), "non-empty")
    expect_error(search_openalex_authors(c("a", "b")), "non-empty")
    expect_error(search_openalex_authors("a", max_results = 0), "positive")
})

test_that("a failed lookup returns the right shape rather than an error", {
    with_mocked_bindings(
        GET = function(...) stop("no route to host"),
        .package = "httr",
        {
            expect_warning(out <- search_openalex_authors("nobody"), "OpenAlex")
        }
    )
    expect_equal(names(out), names(scholar:::empty_openalex_authors()))
    expect_equal(nrow(out), 0)
})

test_that("a real lookup finds the author", {
    skip_on_cran()
    skip_if_offline()
    out <- search_openalex_authors("Guangchuang Yu", max_results = 5)
    if (!nrow(out)) skip("OpenAlex returned nothing for this query")
    expect_true(any(grepl("Guangchuang Yu", out$display_name, fixed = TRUE)))
    top <- out[1, ]
    expect_gte(top$h_index, 1)
    expect_match(top$openalex_id, "^A[0-9]+$")
})
