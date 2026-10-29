##' List the publications that cite a publication
##'
##' Follows the "cited by" link of one publication and returns the works
##' Google Scholar lists as citing it, ten at a time. The citation counts on a
##' profile say how often a paper was cited; this says by whom, and through
##' which venue, so that a citation curve can be split by community, an
##' autocitation rate measured, or the speed of adoption plotted.
##'
## @details The list is the one Google Scholar shows behind the "cited by"
##' number on a profile page, and it is bounded the same way: Scholar exposes at
##' most the first thousand citing works in ten-entry pages, and folds the
##' versions of one work into a single entry. Google guards this list more
##' strictly than it guards a profile page, so a hosted or data-centre IP is
##' frequently answered with a captcha instead of data; see
##' \code{\link{scholar-package}} and \\code{\\link{set_scholar_cookie}}. A refusal is reported
##' as a warning and returns an empty table, never a silently short list.
##'
##' @param id a character string specifying the Google Scholar ID of the author
##'   whose publication is to be expanded.
##' @param pubid a character vector of publication IDs, as found in the
##'   \code{pubid} column of \\code{\\link{get_publications}}.
##' @param max_pages the number of ten-entry pages to read per publication.
##' @param delay seconds to wait between pages, for the benefit of the shared
##'   rate limit.
##' @param publications a table as returned by \\code{\\link{get_publications}}, used to
##'   resolve \code{pubid} to a citation key. Supply it when expanding several
##'   publications, so that the list is fetched once rather than per pubid.
##'
##' @return a data frame with one row per citing publication and the columns
##'   \code{pubid}, the publication it cites; \code{title}; \code{author};
##'   \code{venue}; \code{year}; \code{cites}, citations to the citing work
##'   itself; \code{url}, the publisher page where Scholar links to one; and
##'   \code{cid}, Scholar's citation key for the citing work, which can be
##'   handed to this function's internals to follow the list one step further.
##'   Rows keep the order Scholar uses, which is by relevance. The table is
##'   empty when nothing cites the publication or when Scholar refused.
##'
##' @seealso \\code{\\link{get_publications}} for the \code{pubid} column, and
##'   \\code{\\link{get_article_cite_history}} for citations to one publication per year.
##'
##' @examples
##' \donttest{
##'   pubs <- get_publications("B7vSqZsAAAAJ")
##'   get_citing_articles("B7vSqZsAAAAJ", pubs$pubid[1], publications = pubs,
##'                       max_pages = 1)
##' }
##' @importFrom stringr str_trim str_extract
##' @importFrom rvest html_nodes html_attr html_text
##' @export
get_citing_articles <- function(id, pubid, max_pages = 5, delay = 0,
                                publications = NULL) {
    if (!is.character(pubid) || !length(pubid) || any(is.na(pubid)) ||
        !all(nzchar(pubid))) {
        stop("`pubid` must be one or more non-empty publication IDs.", call. = FALSE)
    }
    if (!is.numeric(max_pages) || length(max_pages) != 1 || is.na(max_pages) ||
        max_pages <= 0) {
        stop("`max_pages` must be a positive number", call. = FALSE)
    }

    pubs <- publications
    if (is.null(pubs)) {
        pubs <- get_publications(tidy_id(id))
    }
    keys <- resolve_citation_keys(pubs, pubid)
    missing <- vapply(keys, function(key) is.na(key$cid), logical(1))
    if (any(missing)) {
        warning("Scholar gives no citation key for `pubid` ",
                paste(unlist(lapply(keys[missing], function(key) key$pubid)),
                      collapse = ", "),
                "; its citing list cannot be followed.", call. = FALSE)
    }
    keys <- keys[!missing]

    results <- lapply(keys, function(key) parse_citation_list(key$cid, key$pubid,
                                                              max_pages, delay))
    out <- do.call(rbind, results)
    if (is.null(out)) empty_citing_articles() else out
}

##' Resolve publication IDs into the citation keys Scholar lists by
##'
##' `get_publications()` keeps those keys in its `cid` column, several of them
##' joined by commas where Scholar has folded versions of one work into a single
##' row; such a group is queried as it stands, because Scholar reads it as "cited
##' by any of these".
##' @noRd
resolve_citation_keys <- function(publications, pubid) {
    if (!is.data.frame(publications) ||
        !all(c("pubid", "cid") %in% names(publications))) {
        stop("`publications` must be a table returned by get_publications(), ",
             "which carries the `pubid` and `cid` columns.", call. = FALSE)
    }
    lapply(pubid, function(one) {
        rows <- publications[publications$pubid == one, , drop = FALSE]
        if (!nrow(rows)) {
            stop("`pubid` '", one, "' is not in `publications`.", call. = FALSE)
        }
        cid <- as.character(rows$cid[[1]])
        if (is.na(cid) || !nzchar(cid)) cid <- NA_character_
        list(pubid = one, cid = cid)
    })
}

parse_citation_list <- function(cid, pubid, max_pages, delay) {
    site <- getOption("scholar_site")
    collected <- list()

    for (page in seq_len(max_pages)) {
        url <- citing_page_url(site, cid, start = (page - 1L) * 10L)
        resp <- get_scholar_resp(url)
        if (is.null(resp)) break

        rows <- parse_citing_page(read_scholar_html(resp))
        if (!nrow(rows)) break
        rows$pubid <- pubid
        collected[[length(collected) + 1L]] <- rows

        if (page < max_pages && delay > 0) Sys.sleep(delay)
    }

    if (!length(collected)) return(empty_citing_articles())
    do.call(rbind, collected)
}

citing_page_url <- function(site, cid, start = 0) {
    paste0(site, "/scholar?cites=", gsub(" ", "+", cid),
           "&as_sdt=2005&sciodt=0,5&hl=en&start=", start)
}

##' Read one page of a Scholar result list
##'
##' The citing pages and the search pages share this markup: a row carrying a
##' citation key, then a title in `h3.gs_rt` whose leading `[PDF]` or
##' `[CITATION]` tag lives outside the link, an
##' `authors - venue, year - host` line, and a `div.gs_fl` of actions holding
##' the work's own "Cited by n" link.
##' @noRd
parse_citing_page <- function(doc) {
    items <- rvest::html_nodes(doc, css = "#gs_res_ccl_mid .gs_ri")
    if (!length(items)) return(empty_citing_articles())

    titles <- vapply(items, citing_title, character(1))
    links <- vapply(items, citing_link, character(1))
    bylines <- vapply(items, citing_byline, character(1))
    keys <- vapply(items, function(item) {
        key <- rvest::html_attr(xml2::xml_parent(item), "data-cid")
        if (length(key) != 1 || is.na(key)) NA_character_ else key
    }, character(1))
    cites <- vapply(items, citing_count, numeric(1))
    cids <- vapply(items, citing_citation_key, character(1))

    parsed <- lapply(bylines, split_byline)
    out <- data.frame(
        title = titles,
        author = vapply(parsed, function(x) x$author, character(1)),
        venue = vapply(parsed, function(x) x$venue, character(1)),
        year = vapply(parsed, function(x) x$year, numeric(1)),
        cites = as.integer(cites),
        url = links,
        cid = cids,
        stringsAsFactors = FALSE)
    out[!is.na(out$title) & nzchar(out$title), , drop = FALSE]
}

citing_title <- function(item) {
    heading <- rvest::html_nodes(item, css = "h3.gs_rt")
    if (!length(heading)) return(NA_character_)
    ## The link text is the title alone; the heading itself also carries the
    ## bracketed [PDF] and [CITATION] tags and, in a citing list, the "Cited by"
    ## prefix of a merged record.
    link <- rvest::html_nodes(heading, "a")
    text <- if (length(link)) rvest::html_text(link[[1]]) else rvest::html_text(heading[[1]])
    na_if_empty(str_trim(gsub("\\s+", " ", text)))
}

citing_link <- function(item) {
    href <- rvest::html_attr(rvest::html_nodes(rvest::html_nodes(item,
                        css = "h3.gs_rt"), "a"), "href")
    if (!length(href) || is.na(href[[1]]) || !nzchar(href[[1]])) {
        return(NA_character_)
    }
    if (grepl("^https?://", href[[1]])) href[[1]]
    else paste0(getOption("scholar_site"), href[[1]])
}

citing_byline <- function(item) {
    node <- rvest::html_nodes(item, css = "div.gs_a")
    if (!length(node)) return(NA_character_)
    str_trim(rvest::html_text(node))
}

citing_count <- function(item) {
    labels <- str_trim(rvest::html_text(rvest::html_nodes(item, css = "div.gs_fl a")))
    hits <- grep("^Cited by [0-9,]+$", labels)
    if (!length(hits)) return(0)
    suppressWarnings(as.numeric(gsub("[^0-9]", "", sub("^Cited by ", "", labels[hits[1]]))))
}

##' The citation key of a result, as found in its own "Cited by" link
##'
##' This is the number Scholar indexes a work by, and the thing a citing list is
##' queried with; the `data-cid` attribute of the row is a different, lettered
##' key that addresses the article record instead.
##' @noRd
citing_citation_key <- function(item) {
    href <- rvest::html_attr(rvest::html_nodes(item, css = "div.gs_fl a"), "href")
    hits <- grep("cites=", href, fixed = TRUE)
    if (!length(hits)) return(NA_character_)
    value <- str_extract(href[hits[1]], "(?<=cites=)[0-9,]+")
    if (is.na(value)) NA_character_ else value
}

##' Split Scholar's "authors - venue, year - host" line
##'
##' Scholar writes the separators as a non-breaking space before the dash, and
##' the host is there only when it found a publisher, so the year stays glued to
##' the venue and an occasional third piece is the domain.
##' @noRd
split_byline <- function(byline) {
    if (!is.character(byline) || length(byline) != 1 || is.na(byline)) {
        return(list(author = NA_character_, venue = NA_character_, year = NA_real_))
    }
    pieces <- str_trim(strsplit(gsub("\u00a0", " ", byline), " - ", fixed = TRUE)[[1]])
    author <- na_if_empty(pieces[[1]])
    ## Scholar puts the venue and its year in one piece; a third piece, when
    ## there is one, is the host and says nothing a reader needs.
    rest <- if (length(pieces) > 1) pieces[[2]] else NA_character_
    year <- suppressWarnings(as.numeric(str_extract(
        rest, "(?<![0-9])(1[89]|20)[0-9]{2}(?![0-9])")))
    venue <- if (is.na(rest) || !nzchar(rest)) {
        NA_character_
    } else {
        na_if_empty(str_trim(sub(",?\\s*(1[89]|20)[0-9]{2}\\s*$", "", rest)))
    }
    list(author = author, venue = venue, year = year)
}

na_if_empty <- function(value) {
    if (!length(value) || is.na(value) || !nzchar(value)) NA_character_ else value
}

empty_citing_articles <- function() {
    data.frame(
        title = character(),
        author = character(),
        venue = character(),
        year = numeric(),
        cites = integer(),
        url = character(),
        cid = character(),
        pubid = character(),
        stringsAsFactors = FALSE)
}
