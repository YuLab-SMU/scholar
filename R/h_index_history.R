##' Track how an h-index developed over the years
##'
##' A profile reports one h-index, at one moment. This rebuilds the number year
##' by year, from the citation history of each publication, so that the shape of
##' a career is visible: whether the h-index was set early by a few papers, is
##' still climbing, or plateaued when an author stopped publishing.
##'
## @details Each publication needs its own citation history, which is one request
##' apiece. That is the expensive part, so the histories are cached with
##' \code{R.cache} the way \code{\link{get_publication_date}} caches its pages,
##' and a second call for the same profile costs nothing. Publications with no
##' citations are skipped: they cannot enter an h-index in any year. The years
##' covered are the years Google reports per publication, so a publication whose
##' history Google truncates contributes only the years it publishes.
##'
##' The h-index in a given year is counted from the citations accumulated up to
##' and including that year, which is what the number means on a profile today.
##' The result is a plain data frame, so plotting the trajectory is one ggplot2
##' call away (\code{geom_step(direction = "hv")} suits a step function); the
##' package vignette carries the worked example.
##'
##' @param id a character string specifying the Google Scholar ID.
##' @param publications a table, as returned by \code{\link{get_publications}},
##'   to take the publication IDs from instead of fetching them again.
##' @param delay seconds to wait between the per-publication requests. Worth
##'   setting on a shared or data-centre IP, where a loop over a long publication
##'   list is exactly what gets a connection rate limited.
##' @param flush whether to discard the cached citation histories and fetch them
##'   again.
##'
##' @return a data frame with one row per year, oldest first: \code{year},
##'   \code{h_index} counted up to that year, and \code{citations}, the
##'   citations accumulated across all publications by that year. The h-index
##'   never falls as the years advance, since accumulated citations do not
##'   decrease.
##'
##' @seealso \code{\link{get_profile}} for the h-index Google reports today,
##'   \code{\link{get_article_cite_history}} for one publication's history, and
##'   \code{\link{get_publication_metrics}} for h-index, g-index and i10-index
##'   counted over a set of publications.
##'
##' @examples
##' \donttest{
##'   pubs <- get_publications("B7vSqZsAAAAJ")
##'   # Scholar may refuse the list outright, answering with NA
##'   if (is.data.frame(pubs) && nrow(pubs)) {
##'     # one request per publication, so start from the few that matter
##'     few <- head(pubs[pubs$cites > 0, c("pubid", "cites")], 3)
##'     head(get_h_index_history("B7vSqZsAAAAJ", publications = few))
##'   }
##' }
##' @import R.cache
##' @importFrom dplyr "%>%"
##' @export
get_h_index_history <- function(id, publications = NULL, delay = 0, flush = FALSE) {
    if (!is.numeric(delay) || length(delay) != 1 || is.na(delay) || delay < 0) {
        stop("delay must be a non-negative number")
    }
    id <- tidy_id(id)
    pubs <- publications
    if (is.null(pubs)) {
        pubs <- get_publications(id)
    }
    if (!has_publication_data(pubs)) {
        return(empty_h_index_history())
    }

    pubids <- pubs$pubid[!is.na(pubs$cites) & pubs$cites > 0 & !is.na(pubs$pubid)]
    if (!length(pubids)) {
        return(empty_h_index_history())
    }

    histories <- lapply(pubids, function(pubid) {
        article_history_cached(id, pubid, delay = delay, flush = flush)
    })
    h_index_from_histories(histories)
}

##' The cached citation history of one publication
##' @noRd
article_history_cached <- function(id, pubid, delay = 0, flush = FALSE) {
    setCacheRootPath(file.path(tempdir(), "r-scholar"))
    key <- list(id, pubid, "cite_history")
    if (flush) saveCache(NULL, key = key)
    history <- loadCache(key)
    if (is.null(history)) {
        if (delay > 0) Sys.sleep(delay)
        history <- get_article_cite_history(id, pubid)
        saveCache(history, key = key)
    }
    history
}

##' Count the h-index of every year from a set of citation histories
##'
##' The histories become a year by publication table of citations awarded,
##' accumulated down the rows: in year Y a publication counts what it had earned
##' through Y. The h-index of that row is the largest k with at least k
##' publications at k citations or more.
##' @noRd
h_index_from_histories <- function(histories) {
    rows <- do.call(rbind, Filter(function(h) is.data.frame(h) && nrow(h), histories))
    if (is.null(rows) || !nrow(rows)) {
        return(empty_h_index_history())
    }
    rows <- rows[!is.na(rows$year) & !is.na(rows$cites), , drop = FALSE]
    if (!nrow(rows)) {
        return(empty_h_index_history())
    }

    awarded <- tapply(rows$cites, list(as.character(rows$year), rows$pubid), sum)
    awarded[is.na(awarded)] <- 0

    ## `apply()` returns a bare vector rather than a matrix whenever the result
    ## has only one row or only one column, and both are ordinary cases here:
    ## one row means every cited publication earned its citations in the same
    ## year, which is what a new researcher looks like. Indexing that vector by
    ## row then fails, so the shape is put back before anything uses it.
    accumulated <- apply(awarded, 2, cumsum)
    if (is.null(dim(accumulated))) {
        accumulated <- matrix(accumulated, nrow = nrow(awarded),
                              dimnames = dimnames(awarded))
    }

    years <- as.integer(rownames(accumulated))
    h_index <- vapply(seq_len(nrow(accumulated)), function(i) {
        h_index_of(accumulated[i, ])
    }, integer(1))

    data.frame(
        year = years,
        h_index = as.integer(h_index),
        citations = as.integer(rowSums(accumulated)),
        stringsAsFactors = FALSE)
}

h_index_of <- function(citations) {
    citations <- sort(as.numeric(citations), decreasing = TRUE)
    qualifies <- which(citations >= seq_along(citations))
    if (!length(qualifies)) return(0L)
    as.integer(max(qualifies))
}

empty_h_index_history <- function() {
    data.frame(
        year = integer(),
        h_index = integer(),
        citations = integer(),
        stringsAsFactors = FALSE)
}
