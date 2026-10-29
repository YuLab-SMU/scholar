##' set scholar mirror
##'
##' setting google scholar mirror
##' @title set_scholar_mirror
##' @param mirror compatible scholar mirror
##' @return NULL
##' @export
##' @author Guangchuang Yu
set_scholar_mirror <- function(mirror = NULL) {
    if (!is.null(mirror)) {
        options("scholar_site" = mirror)
    }   
}


##' set the Scholar session
##'
##' Supply the session that lets Google Scholar treat this R session like the
##' browser you are already signed in with. Some endpoints, author search among
##' them, answer an anonymous request with a Google sign-in page while showing
##' data in a browser; the difference is the cookie.
##'
##' @title set_scholar_cookie
##' @param cookie a \code{Cookie} header value copied from a browser, such as
##'   \code{"NID=...; GSP=..."}, or \code{NULL} to leave it unchanged
##' @param file path to a cookie file exported from a browser, either in the
##'   Netscape format used by \code{curl} or as plain \code{name=value} text.
##'   Both a cookie and a file may be set; their entries are merged.
##' @return \code{NULL}, invisibly; the values are stored as options
##' @details The session is good for as long as the browser session that
##'   produced it, typically a few weeks, and Google ends it earlier when it
##'   notices unusual use. Set it again, or set the \code{SCHOLAR_COOKIE} and
##'   \code{SCHOLAR_COOKIE_FILE} environment variables instead, which is what
##'   to do on a server or in CI where there is no browser to copy from.
##' @examples
##' \dontrun{
##'   set_scholar_cookie(cookie = "NID=abc123; GSP=XQwERT")
##'   set_scholar_cookie(file = "~/scholar-cookies.txt")
##' }
##' @export
##' @author Guangchuang Yu
set_scholar_cookie <- function(cookie = NULL, file = NULL) {
    if (!is.null(cookie)) {
        if (!is.character(cookie) || length(cookie) != 1 || is.na(cookie)) {
            stop("`cookie` must be a single string in `name=value` form.", call. = FALSE)
        }
        options("scholar_cookie" = cookie)
    }
    if (!is.null(file)) {
        if (!is.character(file) || length(file) != 1 || !file.exists(file)) {
            stop("`file` must name an existing cookie file.", call. = FALSE)
        }
        options("scholar_cookie_file" = path.expand(file))
    }
    invisible(NULL)
}


##' Ensures that specified IDs are correctly formatted
##'
##' @param id a character string specifying the Google Scholar ID.
##' If multiple ids are specified, only the first value is used and a
##' warning is generated.
##' @export
##' @importFrom httr GET
##' @keywords internal
tidy_id <- function(id) {
    if (length(id)!=1) {
        id <- id[1]
        msg <- sprintf("Only one ID at a time; retrieving %s", id)
        warning(msg)
    }

    extracted_id <- grab_id(id)
    if (!is.na(extracted_id) && nzchar(extracted_id)) {
        id <- extracted_id
    } else {
        id <- sub("[&#?].*$", "", id)
    }

    return(id)
}


#' Recursively try to GET a Google Scholar Page storing session cookies
#'
#' see \code{\link{scholar-package}} documentation for details about Scholar
#' session cookies.
#'
#' @param url URL to fetch
#' @param attempts_left The number of times to try and fetch the page
#'
#' @return an [response][httr::response] object
#' @seealso [GET][httr::GET]
#' @export
get_scholar_resp <- function(url, attempts_left = 5) {

    stopifnot(attempts_left > 0)

    for (attempt in seq_len(attempts_left)) {

        resp <- scholar_get(url, handle = scholar_handle())
        status <- status_code_or_zero(resp)

        # On a successful GET, return the response
        if (status == 200 && !is_scholar_interstitial(resp)) {
            return(resp)
        }

        # Google Scholar itself told us to go away; the reason decides whether
        # trying again can possibly help.
        if (status == 404) {
            if (attempt == attempts_left) {
                warn_scholar(paste0(
                    "Page 404. Please check whether the provided URL is correct."
                ), key = "status:404")
                return(NULL)
            }
            scholar_sleep(scholar_backoff_delay(attempt))
            next
        }

        if (status == 429) {
            delay <- scholar_backoff_delay(attempt, retry_after = scholar_retry_after(resp))
            if (!is.finite(delay) || attempt == attempts_left) {
                warn_scholar(paste0(
                    "Google Scholar is rate limiting this connection (HTTP 429).",
                    "\n  Try again later, spread requests over time with ",
                    "options(scholar_request_delay = 1), or fetch from a ",
                    "different IP address."
                ), key = "status:429")
                return(NULL)
            }
            scholar_sleep(delay)
            next
        }

        if (status %in% c(401L, 403L) || is_scholar_interstitial(resp)) {
            warn_scholar(scholar_blocked_message(resp, status),
                         key = paste0("blocked:", scholar_block_type(resp, status, status)))
            return(NULL)
        }

        if (attempt == attempts_left) { # When attempts run out, stop with a warning
            warn_scholar(paste0(
                "Google Scholar did not return data (HTTP ", status, "). ",
                "Check that the ID is correct, then see ?scholar for the ",
                "reasons Scholar refuses a request."
            ), key = paste0("status:", status))
            return(NULL)
        }
        scholar_sleep(scholar_backoff_delay(attempt))
    }

    NULL
}

##' @importFrom httr status_code
status_code_or_zero <- function(resp) {
    status <- tryCatch(httr::status_code(resp), error = function(e) NA_integer_)
    if (is.null(status) || is.na(status)) return(-1L)
    as.integer(status)
}

#' Does this response look like a Scholar page, or a Google refusal page?
#'
#' Scholar answers a refused request by redirecting it to a Google sign-in page
#' or to `google.com/sorry` (a captcha), both of which arrive as HTTP 200 with
#' a body full of markup that looks nothing like data. Following the redirect
#' is what `httr` does by default, so the final URL is the reliable signal.
#'
#' @param resp an httr response, as returned by [httr::GET()]
#' @return `TRUE` if the response is a login or captcha interstitial
#' @noRd
is_scholar_interstitial <- function(resp) {
    url <- scholar_response_url(resp)
    if (!nzchar(url)) return(FALSE)
    scholar_sign_in_url(url) || scholar_captcha_url(url)
}

## Anchored on the host and path, because Scholar's own URLs carry a
## `continue=` parameter that quotes the address Google redirected from.
scholar_sign_in_url <- function(url) {
    grepl("^https?://([a-z0-9-]+\\.)*google\\.[a-z.]+/(v[0-9]+/)?(signin|AccountChooser)", url, ignore.case = TRUE) ||
        grepl("^https?://accounts\\.google\\.[a-z.]+/", url, ignore.case = TRUE) ||
        grepl("[?&]flowEntry=ServiceLogin", url)
}

scholar_captcha_url <- function(url) {
    grepl("^https?://([a-z0-9-]+\\.)*google\\.[a-z.]+/(sorry|recaptcha)(/|\\?)", url, ignore.case = TRUE)
}

scholar_response_url <- function(resp) {
    if (!is.list(resp) || is.null(resp$url)) return("")
    url <- resp$url
    if (!is.character(url) || length(url) != 1 || is.na(url)) return("")
    url
}

#' The HTTP status Google Scholar asked us to wait for, in seconds
#'
#' @param resp an httr response
#' @return a numeric scalar, or `NA` when the header is absent
#' @noRd
scholar_retry_after <- function(resp) {
    header <- tryCatch(httr::headers(resp)[["retry-after"]], error = function(e) NULL)
    if (is.null(header) || !nzchar(header)) return(NA_real_)
    seconds <- suppressWarnings(as.numeric(header))
    if (is.finite(seconds)) return(seconds)
    ## `Retry-After: Wed, 21 Oct 2026 07:28:00 GMT` is a deadline, not a delay.
    deadline <- suppressWarnings(strptime(substr(header, 1, 25),
                                         "%a, %d %b %Y %H:%M:%S", tz = "GMT"))
    if (is.na(deadline)) return(NA_real_)
    max(as.numeric(difftime(deadline, Sys.time(), units = "secs")), 0)
}

scholar_block_type <- function(resp, url = NULL, status = NULL) {
    url <- scholar_response_url(resp)
    if (scholar_sign_in_url(url)) return("sign-in")
    if (scholar_captcha_url(url)) return("captcha")
    paste0("http", status)
}

scholar_blocked_message <- function(resp, status) {
    url <- scholar_response_url(resp)
    sign_in <- scholar_sign_in_url(url)
    captcha <- scholar_captcha_url(url)
    if (sign_in) {
        lead <- "Google Scholar redirected to a Google sign-in page, which means
            this endpoint now requires an authenticated session."
    } else if (captcha) {
        lead <- "Google Scholar answered with its captcha page (google.com/sorry)
            instead of data."
    } else {
        lead <- paste0("Google Scholar refused the request (HTTP ", status, ").")
    }
    paste0(lead, "\n",
        "  This is what happens when requests come from an IP that Google does not\n",
        "  trust, typically a hosted application or a CI runner, and it is not a\n",
        "  problem with the ID or the URL. Carry the session of a browser that can\n",
        "  open the page with set_scholar_cookie(), point the package at a mirror\n",
        "  with set_scholar_mirror(), or run it from a workstation.")
}

#' Report a Scholar problem, once per kind per session
#'
#' Retrieval loops call this hundreds of times for the same blocked endpoint, so
#' repeats are silent. `options(scholar_warned = NULL)` brings the notices back
#' within a session.
#'
#' @param message the warning text
#' @param key identifies the kind of problem; without one, always warn
#' @noRd
warn_scholar <- function(message, key = NULL) {
    if (!is.null(key)) {
        seen <- getOption("scholar_warned", character(0))
        if (key %in% seen) return(invisible(FALSE))
        options("scholar_warned" = c(seen, key))
    }
    warning(message, call. = FALSE)
    invisible(TRUE)
}

#' Explain that Scholar refused author search rather than finding nothing
#'
#' Google moved `view_op=search_authors` behind a sign-in page, so the result of
#' [get_scholar_id()] and [search_scholar_ids()] can be empty even when the
#' profile exists. Retrying cannot change that, so the user is pointed at the
#' three things that do work; an empty result with no warning means the name
#' really did not match anything.
#' @noRd
scholar_refused <- function() {
    if (!isTRUE(getOption("scholar_degraded", TRUE))) return(invisible(FALSE))
    if (nzchar(scholar_cookie())) {
        return(warn_scholar(paste0(
            "Google Scholar refused author search even with the session you supplied. ",
            "The cookie has probably expired or does not cover this endpoint; ",
            "export it again with set_scholar_cookie()."),
            key = "degraded:expired-session"))
    }
    warn_scholar(paste0(
        "Google Scholar no longer answers author search for an anonymous client, ",
        "so the result can be empty even when the profile exists.\n",
        "  Carry the session of a browser that opens the page with ",
        "set_scholar_cookie(), point the package at a mirror with ",
        "set_scholar_mirror(), or resolve authors through OpenAlex ",
        "(https://api.openalex.org/authors?search=name).\n",
        "  Silence this notice with options(scholar_degraded = FALSE)."),
        key = "degraded:author-search")
}

scholar_get <- function(url, handle) {
    delay <- scholar_numeric_option("scholar_request_delay", "SCHOLAR_REQUEST_DELAY", 0)
    if (delay > 0) scholar_sleep(delay)
    ## The configuration objects have to reach httr as separate arguments:
    ## `GET(url, list(user_agent(...), add_headers(...)))` is accepted and then
    ## dropped, so the request silently goes out with the libcurl User-Agent
    ## that Scholar answers with HTTP 403. `config` is bound to an empty list
    ## first so that every setting lands in the dots rather than filling the
    ## `config` slot by position.
    settings <- c(list(url = url, config = list(), handle = handle), scholar_headers())
    do.call(httr::GET, settings)
}

scholar_sleep <- function(time) {
    Sys.sleep(time)
}

#' Request headers sent to Google Scholar
#'
#' Scholar rejects a request whose `User-Agent` announces a library rather than
#' a browser, so the package always sends browser-like headers. Both can be
#' overridden, see [scholar][scholar-package].
#'
#' @return a list of httr configuration objects
#' @noRd
#' @importFrom httr user_agent add_headers
scholar_headers <- function() {
    headers <- list(
        Accept = paste("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"),
        `Accept-Encoding` = "gzip, deflate",
        `Accept-Language` = scholar_accept_language()
    )
    cookie <- scholar_cookie()
    if (nzchar(cookie)) {
        headers <- c(headers, list(Cookie = cookie))
    }
    list(
        httr::user_agent(scholar_user_agent()),
        httr::add_headers(.headers = unlist(headers)),
        httr::timeout(scholar_timeout())
    )
}

scholar_timeout <- function() {
    scholar_numeric_option("scholar_timeout", "SCHOLAR_TIMEOUT", 30)
}

scholar_user_agent <- function() {
    default <- "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    scholar_option("scholar_user_agent", "SCHOLAR_USER_AGENT", default)
}

scholar_accept_language <- function() {
    scholar_option("scholar_accept_language", "SCHOLAR_ACCEPT_LANGUAGE", "en-US,en;q=0.9")
}

#' Session cookie sent to Google Scholar, if the user supplied one
#'
#' Some Scholar endpoints answer a script's request with a Google sign-in page
#' while the very same page is open in a browser, because the browser carries a
#' session. The value comes from `options(scholar_cookie)` or from a cookie file
#' exported by a browser, and both are merged into one `Cookie` header.
#'
#' @return a character scalar, possibly empty
#' @noRd
scholar_cookie <- function() {
    file <- scholar_option("scholar_cookie_file", "SCHOLAR_COOKIE_FILE", "")
    pairs <- character(0)
    if (nzchar(file) && file.exists(file)) {
        pairs <- c(pairs, read_scholar_cookie_file(file))
    }

    ## The cookie supplied by hand wins over the one in the file, so that a
    ## stale export does not shadow a session pasted in for this run.
    explicit <- scholar_option("scholar_cookie", "SCHOLAR_COOKIE", "")
    pairs <- c(pairs, unlist(strsplit(explicit, ";", fixed = TRUE), use.names = FALSE))

    pairs <- trimws(pairs)
    pairs <- pairs[nzchar(pairs) & grepl("=", pairs, fixed = TRUE)]
    names <- sub("=.*$", "", pairs)
    keep <- !duplicated(names, fromLast = TRUE)
    paste(pairs[keep], collapse = "; ")
}

#' Read `name=value` pairs out of an exported cookie file
#'
#' Accepts both the Netscape format written by `curl` and by browser export
#' extensions, where each cookie is a tab separated row and an `HttpOnly`
#' cookie's domain cell carries a `#HttpOnly_` prefix, and a plain `Cookie:`
#' style string.
#'
#' @param path path to the cookie file
#' @return a character vector of `name=value` pairs
#' @noRd
read_scholar_cookie_file <- function(path) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[nzchar(trimws(lines))]
    tabular <- grepl("\t", lines, fixed = TRUE)

    rows <- strsplit(lines[tabular], "\t", fixed = TRUE)
    complete <- vapply(rows, function(fields) length(fields) >= 7, logical(1))
    pairs <- vapply(rows[complete], function(fields) paste0(fields[[6]], "=", fields[[7]]),
                    character(1))

    loose <- lines[!tabular & !grepl("^\\s*#", lines)]
    extra <- unlist(strsplit(paste(loose, collapse = ";"), ";", fixed = TRUE),
                    use.names = FALSE)

    trimws(c(unname(pairs), extra))
}

#' Read a scholar option, falling back to an environment variable
#'
#' @param option name of the option, e.g. `"scholar_user_agent"`
#' @param envvar name of the equivalent environment variable
#' @param default value used when neither is set to a non-empty string
#' @return a character scalar
#' @noRd
scholar_option <- function(option, envvar, default) {
    value <- getOption(option, Sys.getenv(envvar, unset = ""))
    if (is.character(value) && length(value) == 1 && nzchar(value) && !is.na(value)) {
        return(value)
    }
    default
}

#' How long to wait before the next attempt at a Scholar request
#'
#' Waits grow geometrically from `options(scholar_retry_delay)` (1 second by
#' default) up to `options(scholar_retry_max_delay)` (30 seconds), with a
#' random fraction added so that a fleet of CI jobs does not come back in sync.
#' A `Retry-After` header from Scholar is honoured, but when Google asks for
#' longer than the maximum delay the result is `Inf`: waiting is pointless.
#'
#' @param attempt the number of the attempt just made, starting at 1
#' @param retry_after value of the `Retry-After` header, or `NA`
#' @return seconds to wait, or `Inf` when the request should be abandoned
#' @noRd
#' @importFrom stats runif
scholar_backoff_delay <- function(attempt, retry_after = NA_real_) {
    base <- scholar_numeric_option("scholar_retry_delay", "SCHOLAR_RETRY_DELAY", 1)
    cap <- scholar_numeric_option("scholar_retry_max_delay", "SCHOLAR_RETRY_MAX_DELAY", 30)
    if (is.finite(retry_after) && retry_after > 0) {
        return(if (retry_after > cap) Inf else retry_after)
    }
    attempt <- max(1L, as.integer(attempt))
    delay <- base * 2^(attempt - 1L)
    jitter <- suppressWarnings(stats::runif(1, min = 0, max = 0.25 * delay))
    min(delay + jitter, cap)
}

scholar_numeric_option <- function(option, envvar, default) {
    value <- suppressWarnings(as.numeric(getOption(option, Sys.getenv(envvar, unset = ""))))
    if (length(value) == 1 && is.finite(value) && value >= 0) {
        return(value)
    }
    default
}

# GB: Add this function to R/utils.R, right after get_scholar_resp() to fix
#     potential issues with encoding

#' Parse an httr response from Google Scholar as HTML, respecting the
#' encoding declared in the response's Content-Type header
#'
#' Google Scholar sometimes serves pages with non-UTF-8 encodings
#' (e.g. ISO-8859-1) when the page contains certain non-ASCII characters,
#' for example accented names in author or institution fields. xml2's
#' read_html(), when given an httr response directly, does not always
#' correctly detect this, which results in an error such as:
#' "Input is not proper UTF-8". This helper reads the declared charset
#' from the HTTP header and converts to UTF-8 before parsing, falling
#' back to UTF-8 if no charset is declared.
#'
#' @param resp an httr response object, as returned by get_scholar_resp()
#' @return an xml2 HTML document, or NULL if resp is NULL
#' @noRd
read_scholar_html <- function(resp) {
  if (is.null(resp)) return(NULL)

  txt <- scholar_response_text(resp)

  xml2::read_html(txt)
}

#' Convert an httr response body from Google Scholar to UTF-8 text
#'
#' @param resp an httr response object, as returned by get_scholar_resp()
#' @return a UTF-8 character scalar
#' @noRd
scholar_response_text <- function(resp) {
  ct <- httr::headers(resp)[["content-type"]]
  declared_encoding <- if (!is.null(ct) && grepl("charset=", ct, ignore.case = TRUE)) {
    sub(".*charset=([^;]+).*", "\\1", ct, ignore.case = TRUE)
  } else {
    character(0)
  }

  raw_bytes <- httr::content(resp, as = "raw")
  raw_text <- rawToChar(raw_bytes)
  encodings <- unique(c(declared_encoding, "UTF-8", "Windows-1252", "ISO-8859-1"))

  for (encoding in encodings) {
    txt <- iconv(raw_text, from = encoding, to = "UTF-8", sub = NA)
    if (!is.na(txt)) {
      Encoding(txt) <- "UTF-8"
      return(txt)
    }
  }

  txt <- iconv(raw_text, from = encodings[1], to = "UTF-8", sub = "byte")
  Encoding(txt) <- "UTF-8"
  txt
}


# get a curl handle with Google scholar cookies set
scholar_handle <- function() {
    site <- getOption("scholar_site")
    if (isTRUE(getOption("scholar_call_home"))) {
        sample_url <- paste0(site, "/citations?user=B7vSqZsAAAAJ")
        ## Goes through scholar_get() so that the session is seeded with the
        ## same headers, and the same cookie, as the requests that follow it.
        sink <- suppressWarnings(scholar_get(sample_url, handle = NULL))
        options("scholar_call_home"=FALSE, "scholar_handle"=sink)
    }
    getOption("scholar_handle")
}

## We can use this function through the package to compose
## a url by only providing the id
compose_url <- function(id, url_template) {
    if (is.na(id)) return(NA_character_)
    id <- tidy_id(id)
    url <- sprintf(url_template, id)

    url
}

# Extract the google scholar id of a url
grab_id <- function(url) {
    stringr::str_extract(url, "(?<=user=)[^&#]*")
}
