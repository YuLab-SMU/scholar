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

    resp <- scholar_get(url, handle = scholar_handle())

    # On a successful GET, return the response
    if (httr::status_code(resp) == 200) {
        resp
    } else if (httr::status_code(resp) == 404) {
        if (attempts_left == 1) {
            warning("Page 404. Please check whether the provided URL is correct.")
            return(NULL)
        }
        scholar_sleep(1)
        get_scholar_resp(url, attempts_left - 1)
    } else if(httr::status_code(resp) == 429){
        warning("Response code 429. Google is rate limiting you for making too many requests too quickly.")
        return(NULL)
    } else if (attempts_left == 1) { # When attempts run out, stop with an error
        warning("Cannot connect to Google Scholar. Is the ID you provided correct?")
        return(NULL)
    } else { # Otherwise, sleep a second and try again
        scholar_sleep(1)
        get_scholar_resp(url, attempts_left - 1)
    }
}

scholar_get <- function(url, handle) {
    httr::GET(url, handle = handle)
}

scholar_sleep <- function(time) {
    Sys.sleep(time)
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
