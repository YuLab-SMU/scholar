##' Look up authors and their citation metrics in OpenAlex
##'
##' Google Scholar put author search behind a Google login, so
##' [get_scholar_id()] and [search_scholar_ids()] can only reach it with a
##' session borrowed from a browser. OpenAlex is the alternative that needs no
##' session and no scraping: it is an openly licensed index of scholarly
##' records, maintained for programmatic use, and it publishes the h-index and
##' i10-index alongside the works it counted.
##'
##' The numbers will not match Google Scholar's. OpenAlex counts citations in
##' its own corpus, so an h-index here is usually lower than the one a Scholar
##' profile shows, and the two should not be mixed in one table.
##'
##' @param name a character string to search for, such as
##'   \code{"Guangchuang Yu"}.
##' @param max_results the number of author records to return, at most 50.
##'   Results come back in OpenAlex's relevance order, so the person you want is
##'   usually first when the name is not common.
##'
##' @return a data frame with one row per candidate author and the columns
##'   \code{openalex_id}, \code{orcid}, \code{display_name}, \code{affiliation},
##'   \code{works_count}, \code{cited_by_count}, \code{h_index},
##'   \code{i10_index} and \code{url}.
##'
##' @section The polite pool: OpenAlex asks callers who can be identified to
##'   pass an email address, which routes the request to a separately managed
##'   pool. Set \code{options(scholar_openalex_mailto = "you@example.org")} or
##'   the \code{SCHOLAR_OPENALEX_MAILTO} environment variable to do so; without
##'   it the lookup still works.
##'
##' @examples
##' \donttest{
##'   search_openalex_authors("Guangchuang Yu")
##'   search_openalex_authors("Richard Feynman", max_results = 3)
##' }
##' @seealso [get_scholar_id()] for the Google Scholar route, and
##'   [get_scholar_metrics()] for the same metrics as Scholar reports them.
##' @importFrom stringr str_replace
##' @export
search_openalex_authors <- function(name, max_results = 10) {
    if (!is.character(name) || length(name) != 1 || is.na(name) || !nzchar(name)) {
        stop("`name` must be a single non-empty string.", call. = FALSE)
    }
    if (!is.numeric(max_results) || length(max_results) != 1 ||
        is.na(max_results) || max_results < 1) {
        stop("`max_results` must be a single positive number.", call. = FALSE)
    }

    url <- openalex_authors_url(name, min(max_results, 50))
    resp <- tryCatch(httr::GET(url, httr::timeout(30)), error = function(e) NULL)
    if (is.null(resp) || httr::status_code(resp) >= 400) {
        status <- if (is.null(resp)) "could not be reached" else
            paste0("answered HTTP ", httr::status_code(resp))
        warning("OpenAlex ", status, "; no authors were retrieved.", call. = FALSE)
        return(empty_openalex_authors())
    }

    parsed <- tryCatch(httr::content(resp, as = "parsed"), error = function(e) NULL)
    if (is.null(parsed) || !is.list(parsed$results)) return(empty_openalex_authors())
    out <- parse_openalex_authors(parsed$results)
    out[seq_len(min(nrow(out), max_results)), , drop = FALSE]
}

openalex_authors_url <- function(name, per_page = 10) {
    query <- utils::URLencode(name, reserved = TRUE)
    mailto <- scholar_option("scholar_openalex_mailto", "SCHOLAR_OPENALEX_MAILTO", "")
    paste0("https://api.openalex.org/authors?search=", query,
           "&per-page=", per_page,
           "&select=id,orcid,display_name,last_known_institutions,",
           "works_count,cited_by_count,summary_stats",
           if (nzchar(mailto)) paste0("&mailto=", mailto) else "")
}

parse_openalex_authors <- function(results) {
    row_for <- function(author) {
        stats <- author$summary_stats
        institutions <- author$last_known_institutions
        affiliation <- if (length(institutions)) institutions[[1]]$display_name else NA_character_
        data.frame(
            openalex_id = openalex_short_id(author$id),
            orcid = openalex_orcid(author$orcid),
            display_name = author$display_name %||% NA_character_,
            affiliation = affiliation %||% NA_character_,
            works_count = as.integer(author$works_count %||% NA_integer_),
            cited_by_count = as.integer(author$cited_by_count %||% NA_integer_),
            h_index = as.integer(stats$h_index %||% NA_integer_),
            i10_index = as.integer(stats$i10_index %||% NA_integer_),
            url = author$id %||% NA_character_,
            stringsAsFactors = FALSE)
    }
    rows <- lapply(results, row_for)
    if (!length(rows)) return(empty_openalex_authors())
    do.call("rbind", rows)
}

##' `https://openalex.org/A5027320896` into `A5027320896`
##' @noRd
openalex_short_id <- function(id) {
    if (is.null(id)) return(NA_character_)
    str_replace(id, "^https?://openalex\\.org/", "")
}

##' OpenAlex gives `https://orcid.org/0000-...`, or null when it has no match
##' @noRd
openalex_orcid <- function(orcid) {
    if (is.null(orcid)) return(NA_character_)
    orcid
}

empty_openalex_authors <- function() {
    data.frame(
        openalex_id = character(),
        orcid = character(),
        display_name = character(),
        affiliation = character(),
        works_count = integer(),
        cited_by_count = integer(),
        h_index = integer(),
        i10_index = integer(),
        url = character(),
        stringsAsFactors = FALSE)
}
