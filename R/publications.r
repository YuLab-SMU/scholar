# Ugly hack for CRAN checks
utils::globalVariables(c("."))

##' Gets the publications for a scholar
##'
##' Gets the publications of a specified scholar.
##'
##' @param id a character string specifying the Google Scholar ID.  If
##' multiple IDs are specified, only the publications of the first
##' scholar will be retrieved.
##' @param cstart an integer specifying the first article to start
##' counting.  To get all publications for an author, omit this
##' parameter.
##' @param cstop an integer specifying the last article to
##' process.
##' @param pagesize an integer specifying the number of articles to fetch in one
##'   batch. It is recommended to leave the default value of 100 unless you
##'   experience time-out errors. Note this is \emph{not} the \bold{total}
##'   number of publications to fetch.
##' @param flush should the cache be flushed?  Search results are
##' cached by default to speed up repeated queries.  If this argument
##' is TRUE, the cache will be cleared and the data reloaded from
##' Google.
##' @param sortby a character with value \code{"citation"} or
##' value \code{"year"} specifying how results are sorted.
##' @details Google uses two id codes to uniquely reference a
##' publication.  The results of this method includes \code{cid} which
##' can be used to link to a publication's full citation history
##' (i.e. if you click on the number of citations in the main scholar
##' profile page), and \code{pubid} which links to the details of the
##' publication (i.e. if you click on the title of the publication in
##' the main scholar profile page.)
##' @return a data frame listing the publications and their details.
##' These include the publication title, author, journal, number,
##' cites, year, and two id codes (see details).
##' @importFrom stringr str_extract str_sub str_trim str_replace
##' @importFrom dplyr "%>%" row_number filter
##' @importFrom xml2 read_html
##' @importFrom rvest html_nodes html_text html_attr
##' @import R.cache
##' @export
get_publications <- function(id, cstart = 0, cstop = Inf, pagesize=100, flush=FALSE, sortby="citation") {

    ## Make sure pagesize is not greater than max allowed by Google Scholar
    if (pagesize > 100) {
        warning("pagesize: ", pagesize, " exceeds Google Scholar maximum. Setting to 100.")
        pagesize <- 100
    }

    ## Ensure we're only getting one scholar's publications
    id <- tidy_id(id)

    ## Define the cache path
    cache.dir <- file.path(tempdir(), "r-scholar")
    setCacheRootPath(cache.dir)

    ## Clear the cache if requested
    if (flush) saveCache(NULL, key=list(id, cstart))

    ## Check if we've cached it already
    data <- loadCache(list(id, cstart))

    site <- getOption("scholar_site")

    ## If not, get the data and save it to cache
    if (is.null(data)) {

        ## Build the URL

        stopifnot(sortby == "citation" | sortby == "year")

        if(sortby == "citation"){
            url_template <- paste0(site, "/citations?hl=en&user=%s&cstart=%d&pagesize=%d")
        }

        if(sortby == "year"){
            url_template <- paste0(site, "/citations?hl=en&user=%s&cstart=%d&pagesize=%d&sortby=pubdate")
        }

        url <- sprintf(url_template, id, cstart, pagesize)

        ## Load the page
        page <- get_scholar_resp(url)
        if (is.null(page)) return(NA)

        page <- page %>% read_html()
        cites <- page %>% html_nodes(xpath="//tr[@class='gsc_a_tr']")

        title <- cites %>% html_nodes(".gsc_a_at") %>% html_text()
        pubid <- cites %>% html_nodes(".gsc_a_at") %>%
            html_attr("href") %>% str_extract(":.*$") %>% str_sub(start=2)
        doc_id <- cites %>% html_nodes(".gsc_a_ac") %>% html_attr("href") %>%
            str_extract("cites=.*$") %>% str_sub(start=7)
        cited_by <- suppressWarnings(cites %>% html_nodes(".gsc_a_ac") %>%
                                     html_text() %>%
                                     as.numeric(.) %>% replace(is.na(.), 0))
        year <- cites %>% html_nodes(".gsc_a_y") %>% html_text() %>%
            as.numeric()
        authors <- cites %>% html_nodes("td .gs_gray") %>% html_text() %>%
            as.data.frame(stringsAsFactors=FALSE) %>%
                filter(row_number() %% 2 == 1)  %>% .[[1]]

        ## Get the more complicated parts
        details <- cites %>% html_nodes("td .gs_gray") %>% html_text() %>%
            as.data.frame(stringsAsFactors=FALSE) %>%
                filter(row_number() %% 2 == 0) %>% .[[1]]


        ## Clean up the journal titles (assume there are no numbers in
        ## the journal title)
        first_digit <- as.numeric(regexpr("[\\[\\(]?\\d", details)) - 1
        journal <- str_trim(str_sub(details, end=first_digit)) %>%
            str_replace(",$", "")

        ## Clean up the numbers part
        numbers <- str_sub(details, start=first_digit) %>%
            str_trim() %>% str_sub(end=-5) %>% str_trim() %>% str_replace(",$", "")

        ## Put it all together
        data <- data.frame(title=title,
                           author=authors,
                           journal=journal,
                           number=numbers,
                           cites=cited_by,
                           year=year,
                           cid=doc_id,
                           pubid=pubid)

        ## Check if we've reached pagesize articles. Might need
        ## to search the next page
        if (cstart >= I(cstop)) {
          return(data)
        }

        if (nrow(data) > 0 && nrow(data)==pagesize) {
            data <- rbind(data, get_publications(id, cstart=cstart+pagesize, pagesize=pagesize))
        }

        ## Save it after everything has been retrieved.
        if (cstart == 0) {
            saveCache(data, key=list(id, cstart))
        }
    }

    return(data)
}

##' Gets the citation history of a single article
##'
##' @param id a character string giving the id of the scholar
##' @param article a character string giving the article id.
##' @return a data frame giving the year, citations per year, and
##' publication id
##' @importFrom dplyr "%>%"
##' @importFrom stringr str_replace
##' @importFrom xml2 read_html
##' @importFrom rvest html_nodes html_attr html_text
##' @export
get_article_cite_history <- function (id, article) {
    dummy_output <- data.frame(year=1, cites=1, pubid='a')
    dummy_output <- dummy_output[-1, ]

    site <- getOption("scholar_site")
    id <- tidy_id(id)
    url_base <- paste0(site, "/citations?",
                       "view_op=view_citation&hl=en&citation_for_view=")
    url_tail <- paste(id, article, sep=":")
    url <- paste0(url_base, url_tail)

    res <- get_scholar_resp(url)
    if (is.null(res)) return(dummy_output)

    httr::stop_for_status(res, "get user id / article information")
    doc <- read_html(res)

    ## Inspect the bar chart to retrieve the citation values and years
    years <- doc %>%
        html_nodes(".gsc_oci_g_a") %>%
        html_attr('href') %>%
        stringr::str_match("as_ylo=(\\d{4})&") %>%
        "["(,2) %>%
        as.numeric()
    vals <- doc %>%
        html_nodes(".gsc_oci_g_al") %>%
        html_text() %>%
        as.numeric()

    df <- data.frame(year = years, cites = vals)
    if(nrow(df)>0) {
        ## There may be undefined years in the sequence so fill in these gaps
        df <- merge(data.frame(year=min(years):max(years)),
                     df, all.x=TRUE)
        df[is.na(df)] <- 0
        df$pubid <- article
    } else {
        # complete the 0 row data.frame to be consistent with normal results
        df$pubid <- vector(mode = mode(article))
    }
    return(df)
}

##' Calculates how many articles a scholar has published
##'
##' Calculate how many articles a scholar has published.
##'
##' @param id a character string giving the Google Scholar ID
##' @return an integer value (max 100)
##' @export
get_num_articles <- function(id) {
    papers <- get_publications(id)
    return(nrow(papers))
}

##' Gets the year of the oldest article for a scholar
##'
##' Gets the year of the oldest article published by a given scholar.
##'
##' @param id 	a character string giving the Google Scholar ID
##' @return the year of the oldest article
##' @export
get_oldest_article <- function(id) {
    papers <- get_publications(id)
    return(min(papers$year, na.rm=TRUE))
}





# ##' Get journal metrics.
# ##'
# ##' Get journal metrics (impact factor) for a journal list.
# ##'
# ##' @examples
# ##' \dontrun{
# ##' library(scholar)
# ##'
# ##' id <- get_publications("DO5oG40AAAAJ")
# ##' impact <- get_impactfactor(journals=id$journal, max.distance = 0.1)
# ##'
# ##' id <- cbind(id, impact)
# ##'}
# ##' @param journals a character list giving the journal list
# ##' @param max.distance maximum distance allowed for a match between journal and journal list.
# ##' Expressed either as integer, or as a fraction of the pattern length times the maximal transformation cost
# ##' (will be replaced by the smallest integer not less than the corresponding fraction), or a list with possible components
# ##'
# ##' @return Journal metrics data.
# ##'
# ##' @import dplyr
# ##' @export
# ##' @author Dominique Makowski and Guangchuang Yu
# get_impactfactor <- function(journals, max.distance = 0.05) {
#     message("The impact factor data is out-of-date and we may remove this function in future release.")
#     get_journal_stats(journals, max.distance, impactfactor)
# }


get_journal_stats <- function(journals, max.distance, source_data, col = "Journal") {
    journals <- as.character(journals)
    index <- rep(NA, length(journals))

    for(i in seq_along(journals)) {
        journal <- journals[i]
        if(journal == ""){
            next
        }

        closest <- agrep(journal,
                         source_data[[col]],
                         max.distance = max.distance,
                         value = FALSE,
                         ignore.case = TRUE)

        if(!is.null(closest)){
            ## agrep() returns all "close" matches
            ## but unfortunately does not return the degree of closeness.

            ## index[i] <- closest[1]


            j <- grep(paste0("^", journal, "$"), source_data[[col]][closest], ignore.case=TRUE)
            if (length(j) > 0) {
                j <- j[1]
                index[i] <- closest[j]
                next
            }

            get_hit <- function(pattern, x) {
                j <- grep(pattern, x, ignore.case = TRUE)
                if (length(j) > 0) {
                    return(j[1])
                }
                return(NULL)
            }

            hit <- closest[1]
            patterns <- c(paste0("^", journal, "$"),
                          paste0("^", journal),
                          paste0(journal, "$"))
            for (pp in patterns) {
                j <- get_hit(pp, source_data[[col]][closest])
                if (!is.null(j)) {
                    hit <- j
                    break
                }
            }

            index[i] <- hit
        }

    }

    return(source_data[index, ])
}


##' Get journal ranking.
##'
##' Get journal ranking for a journal list.
##'
##' @examples
##' \dontrun{
##' library(scholar)
##'
##' id <- get_publications("bg0BZ-QAAAAJ&hl")
##' impact <- get_journalrank(journals=id$journal)
##'
##' id <- cbind(id, impact)
##' }
##' @param journals a character list giving the journal list
##' @param max.distance maximum distance allowed for a match between journal and journal list.
##' Expressed either as integer, or as a fraction of the pattern length times the maximal transformation cost
##' (will be replaced by the smallest integer not less than the corresponding fraction), or a list with possible components
##'
##' @return Journal ranking data.
##'
##' @import dplyr
##' @export
##' @author Dominique Makowski and Guangchuang Yu
get_journalrank <- function(journals, max.distance = 0.05) {
    get_journal_stats(journals, max.distance, journalrankings)
}




##' Gets the abstract for a publication id.
##'
##' @param id a character string specifying the Google Scholar ID.
##' @param pub_id a character string specifying the publication id.
##' @param flush Whether or not to clear the cache
##'
##' @return a String that contains the abstract of the publication.
##'
##' @importFrom dplyr "%>%"
##' @importFrom xml2 read_html
##' @importFrom rvest html_nodes html_text html_attr
##' @import R.cache
##' @export
#'
# ' @examples
get_publication_abstract <- function(id, pub_id, flush = FALSE) {
  # ensure tidy_id
  id <- tidy_id(id)

  ## Define the cache path
  cache.dir <- file.path(tempdir(), "r-scholar")
  setCacheRootPath(cache.dir)

  ## Clear the cache if requested
  if (flush) saveCache(NULL, key=list(id, pub_id, "abstract"))

  ## Check if we've cached it already
  data <- loadCache(list(id, pub_id, "abstract"))

  site <- getOption("scholar_site")

  ## If not, get the data and save it to cache
  if (is.null(data)) {

    url_template <- paste0(site, "/citations?view_op=view_citation&hl=en&user=%s&citation_for_view=%s")
    url <- sprintf(url_template, id, paste0(id,":",pub_id))

    page <- get_scholar_resp(url)
    if (is.null(page)) return(NA)

    page <- page %>% rvest::read_html()

    data <- page %>% rvest::html_nodes(xpath="//div[@class='gsh_csp']") %>% rvest::html_text()
    #url <- page %>% rvest::html_nodes(xpath="//a[@class='gsc_oci_title_link']") %>% rvest::html_attr("href")


  }

  return(data)

}

##' Gets the PDF URL for a publication id.
##'
##' @param id a character string specifying the Google Scholar ID.
##' @param pub_id a character string specifying the publication id.
##' @param flush Whether or not to clear the cache
##'
##' @return a String that contains the URL to the PDF of the publication.
##'
##' @importFrom dplyr "%>%"
##' @importFrom xml2 read_html
##' @importFrom rvest html_nodes html_text html_attr
##' @import R.cache
##' @export
#'
# ' @examples
get_publication_url <- function(id, pub_id, flush = FALSE) {
  # ensure tidy_id
  id <- tidy_id(id)

  ## Define the cache path
  cache.dir <- file.path(tempdir(), "r-scholar")
  setCacheRootPath(cache.dir)

  ## Clear the cache if requested
  if (flush) saveCache(NULL, key=list(id, pub_id, "url"))

  ## Check if we've cached it already
  data <- loadCache(list(id, pub_id, "url"))

  site <- getOption("scholar_site")

  ## If not, get the data and save it to cache
  if (is.null(data)) {

    url_template <- paste0(site, "/citations?view_op=view_citation&hl=en&user=%s&citation_for_view=%s")
    url <- sprintf(url_template, id, paste0(id,":",pub_id))

    page <- get_scholar_resp(url)
    if (is.null(page)) return(NA)

    page <- page %>% rvest::read_html()

    data <- page %>% rvest::html_nodes(xpath="//a[@class='gsc_oci_title_link']") %>% rvest::html_attr("href")


  }

  return(data)

}


##' Gets the URL to the google scholar website of an article.
##'
##' @param id a character string specifying the Google Scholar ID.
##' @param pubid a character string specifying the article id.
##'
##' @return a String that contains the URL to the scholar website of the article
##'
##' @export
#'
# ' @examples
get_article_scholar_url <- function(id, pubid){

  # ensure tidy_id
  id <- tidy_id(id)

  site <- getOption("scholar_site")

  url_template <- paste0(site, "/citations?view_op=view_citation&hl=en&user=%s&citation_for_view=%s")
  url <- sprintf(url_template, id, paste0(id,":",pubid))
  url
}


##' Gets the full date for a publication
##'
##' @param id a character string specifying the Google Scholar ID.
##' @param pub_id a character string specifying the publication id.
##' @param flush Whether or not to clear the cache
##'
##' @return a String that contains the publication date
##'
##' @importFrom stringr str_which
##' @importFrom dplyr "%>%"
##' @importFrom xml2 read_html
##' @importFrom rvest html_nodes html_text html_attr
##' @import R.cache
##' @export
#'
# ' @examples
get_publication_date <- function(id, pub_id, flush = FALSE) {
  # ensure tidy_id
  id <- tidy_id(id)
  #debug
  #id <- "K6EVDoYAAAAJ"
  #pub_id <- "HIFyuExEbWQC"

  ## Define the cache path
  cache.dir <- file.path(tempdir(), "r-scholar")
  setCacheRootPath(cache.dir)

  ## Clear the cache if requested
  if (flush) saveCache(NULL, key=list(id, pub_id, "date"))

  ## Check if we've cached it already
  data <- loadCache(list(id, pub_id, "date"))

  site <- getOption("scholar_site")

  ## If not, get the data and save it to cache
  if (is.null(data)) {

    url_template <- paste0(site, "/citations?view_op=view_citation&hl=en&user=%s&citation_for_view=%s")
    url <- sprintf(url_template, id, paste0(id,":",pub_id))

    page <- get_scholar_resp(url)
    if (is.null(page)) return(NA)

    page <- page %>% rvest::read_html()

    fields <- page %>% rvest::html_nodes(xpath="//div[@class='gsc_oci_field']") %>% rvest::html_text()
    field_num <- stringr::str_which(fields, "Publication date")
    data_fields <- page %>% rvest::html_nodes(xpath="//div[@class='gsc_oci_value']") %>% rvest::html_text()

    data <- data_fields[field_num]
  }

  return(data)

}


##' Gets the full data for a publication
##'
##' @param id a character string specifying the Google Scholar ID.
##' @param pub_id a character string specifying the publication id.
##' @param flush Whether or not to clear the cache
##'
##' @return a list that contains the full data
##'
##' @importFrom stringr str_which
##' @importFrom dplyr "%>%"
##' @importFrom xml2 read_html
##' @importFrom rvest html_nodes html_text html_attr
##' @import R.cache
##' @export
#'
# ' @examples
get_publication_data_extended <- function(id, pub_id, flush = FALSE) {
  # ensure tidy_id
  id <- tidy_id(id)
  #debug
  #id <- "K6EVDoYAAAAJ"
  #pub_id <- "HIFyuExEbWQC"

  ## Define the cache path
  cache.dir <- file.path(tempdir(), "r-scholar")
  setCacheRootPath(cache.dir)

  ## Clear the cache if requested
  if (flush) saveCache(NULL, key=list(id, pub_id, "data"))

  ## Check if we've cached it already
  data <- loadCache(list(id, pub_id, "data"))

  site <- getOption("scholar_site")

  ## If not, get the data and save it to cache
  if (is.null(data)) {

    url_template <- paste0(site, "/citations?view_op=view_citation&hl=en&user=%s&citation_for_view=%s")
    url <- sprintf(url_template, id, paste0(id,":",pub_id))

    page <- get_scholar_resp(url)
    if (is.null(page)) return(NA)

    page <- page %>% rvest::read_html()

    fields <- page %>% rvest::html_nodes(xpath="//div[@class='gsc_oci_field']") %>% rvest::html_text()
    field_num <- stringr::str_which(fields, "Publication date")
    data_fields <- page %>% rvest::html_nodes(xpath="//div[@class='gsc_oci_value']") %>% rvest::html_text()

    names(data_fields) <- fields
    data <- as.data.frame(t(data_fields))
  }

  return(data)

}
