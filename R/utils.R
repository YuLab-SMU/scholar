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
                ))
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
                ))
                return(NULL)
            }
            scholar_sleep(delay)
            next
        }

        if (status %in% c(401L, 403L) || is_scholar_interstitial(resp)) {
            warn_scholar(scholar_blocked_message(resp, status))
            return(NULL)
        }

        if (attempt == attempts_left) { # When attempts run out, stop with a warning
            warn_scholar(paste0(
                "Google Scholar did not return data (HTTP ", status, "). ",
                "Check that the ID is correct, then see ?scholar for the ",
                "reasons Scholar refuses a request."
            ))
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
    grepl("accounts\\.google\\.com", url) ||
        grepl("/sorry/", url) ||
        grepl("ServiceLogin", url) ||
        grepl("SIGNIN\\?", url)
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
    if (is.null(header)) return(NA_real_)
    suppressWarnings(as.numeric(header))
}

scholar_blocked_message <- function(resp, status) {
    url <- scholar_response_url(resp)
    sign_in <- grepl("accounts\\.google\\.com", url) || grepl("SIGNIN\\?", url) ||
        grepl("ServiceLogin", url)
    captcha <- grepl("/sorry/", url)
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
        "  problem with the ID or the URL. Retry from a workstation, point the\n",
        "  package at a mirror with set_scholar_mirror(), or reuse a browser\n",
        "  session as described in ?scholar.")
}

warn_scholar <- function(message) {
    warning(message, call. = FALSE)
}

scholar_get <- function(url, handle) {
    delay <- scholar_numeric_option("scholar_request_delay", "SCHOLAR_REQUEST_DELAY", 0)
    if (delay > 0) scholar_sleep(delay)
    httr::GET(url, scholar_headers(), handle = handle)
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
    list(
        httr::user_agent(scholar_user_agent()),
        httr::add_headers(
            Accept = paste("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"),
            `Accept-Language` = scholar_accept_language()
        )
    )
}

scholar_user_agent <- function() {
    default <- "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    scholar_option("scholar_user_agent", "SCHOLAR_USER_AGENT", default)
}

scholar_accept_language <- function() {
    scholar_option("scholar_accept_language", "SCHOLAR_ACCEPT_LANGUAGE", "en-US,en;q=0.9")
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
    if (getOption("scholar_call_home")) {
        sample_url <- paste0(site, "/citations?user=B7vSqZsAAAAJ")
        sink <- GET(sample_url)
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
