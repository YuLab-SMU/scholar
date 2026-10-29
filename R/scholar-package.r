#' scholar
#'
#' The \code{scholar} package provides functions to extract citation data from
#' Google Scholar.  There are also convenience functions for comparing multiple
#' scholars and predicting h-index scores based on past publication records.
#'
#' @section Google Scholar cookies: Google does not encourage people to use the
#'   scholar website as an API. You will find a number of issues related to this
#'   if you follow:
#'   \url{https://github.com/jkeirstead/scholar/issues?q=is:issue+cookie}
#'
#'   If you try to fetch too many pages, you can expect to see your access to
#'   scholar blocked. One step that they do take is to provide a session cookie.
#'   Reusing these seems to help. If you wish to write your own code to interact
#'   with Google Scholar, we recommend that you use the
#'   \code{\link{get_scholar_resp}} function to carry out the query.
#'
#'   Some endpoints, author search among them, now want a session that only a
#'   browser has. \code{\link{set_scholar_cookie}} hands that session to the
#'   package: either paste the \code{Cookie} value from a browser that can open
#'   the page, or point it at a file exported from one. Prefer the file: cookies
#'   that begin with \code{#HttpOnly_} in a Netscape jar are the decisive ones,
#'   and pasting a session into a script leaves it in your command history. The
#'   package sends them itself as a \code{Cookie} header rather than leaving it
#'   to \code{libcurl}, which discards exactly those \code{HttpOnly} rows.
#'   A session expires with the browser session it came from, and Google ends it
#'   sooner when it sees unusual use, so expect to refresh it.
#'
#'   None of this is a sanctioned API. Scholar's terms of service forbid
#'   automated access, and using your own account's session puts that account's
#'   Google access at risk of a challenge or suspension; a dedicated or
#'   disposable account is the safer choice, and the risk stays with you.
#'
#' @section Requests are refused, rate limited or redirected: Google Scholar has
#'   no public API and guards the website against automated clients, so a
#'   request can fail for reasons that have nothing to do with the ID you
#'   passed. The package sends browser-like headers on every request and backs
#'   off before retrying, but three outcomes are still worth recognising:
#'
#'   \itemize{
#'     \item HTTP 403 on the search pages. Scholar rejects a client whose
#'       \code{User-Agent} names a library, which is why the same query works
#'       in a browser and not in a script.
#'     \item A redirect to a sign-in or captcha page, reported as \emph{Google
#'       Scholar redirected to a Google sign-in page} or \emph{answered with
#'       its captcha page}. Some endpoints, author search among them, now sit
#'       behind a Google login, and a shared or data-centre IP (a hosted shiny
#'       app, a CI runner) is challenged more often than a workstation. These
#'       requests are not retried, because retrying cannot change the answer.
#'     \item HTTP 429, meaning this IP has asked too often. The package waits,
#'       using the \code{Retry-After} header when Scholar supplies it and
#'       otherwise an exponentially growing delay, and gives up with a warning
#'       when Google asks for longer than the budget allows.
#'   }
#'
#'   When a function returns \code{NA} or an empty table, read the warning: it
#'   names the reason. To keep Scholar happy, request less (set
#'   \code{scholar_request_delay}), fetch from a residential connection, or
#'   point the package at a mirror with \code{\link{set_scholar_mirror}}.
#'
#' @section Configuration: the following options are read on every request, and
#'   each falls back to the environment variable of the same name in upper
#'   case, which is what to set on a server or in CI.
#'
#'   \itemize{
#'     \item \code{scholar_site}: base URL of Google Scholar or a compatible
#'       mirror, see \code{\link{set_scholar_mirror}}.
#'     \item \code{scholar_user_agent} (\code{SCHOLAR_USER_AGENT}): the
#'       \code{User-Agent} sent. Defaults to a desktop Chrome string.
#'     \item \code{scholar_accept_language} (\code{SCHOLAR_ACCEPT_LANGUAGE}):
#'       sent as \code{Accept-Language}. Defaults to \code{en-US,en;q=0.9};
#'       Scholar serves different markup per language, so change it only if you
#'       know why.
#'     \item \code{scholar_request_delay} (\code{SCHOLAR_REQUEST_DELAY}):
#'       seconds to wait before every request. Default \code{0}. Set this in
#'       loops over many publications, where one profile fetch follows another.
#'     \item \code{scholar_retry_delay} and \code{scholar_retry_max_delay}: the
#'       first wait and the ceiling for the exponentially growing wait before a
#'       retry. Defaults to 1 and 30 seconds.
#'     \item \code{scholar_cookie} (\code{SCHOLAR_COOKIE}) and
#'       \code{scholar_cookie_file} (\code{SCHOLAR_COOKIE_FILE}): the session to
#'       present, see \code{\link{set_scholar_cookie}}. Entries from the option
#'       win over entries of the same name in the file. Prefer the environment
#'       variable, since an option value can end up in the command history.
#'     \item \code{scholar_scimago_url} (\code{SCHOLAR_SCIMAGO_URL}): source of
#'       the SCImago journal ranking table, either a URL or a file saved from a
#'       browser. When set it is the only source tried; otherwise the live
#'       export is fetched and an archived copy is used if SCImago refuses.
#'     \item \code{scholar_timeout} (\code{SCHOLAR_TIMEOUT}): seconds a single
#'       request may take before it is abandoned. Default 30.
#'     \item \code{scholar_degraded}: set to \code{FALSE} to stop the notice
#'       that author search is being refused by Google, which otherwise appears
#'       once per session.
#'     \item \code{scholar_call_home} and \code{scholar_handle}: whether to seed
#'       a session, and the handle holding its cookies. Both are managed for you.
#'   }
#'
#'
#' @source The package reads data from \url{https://scholar.google.com}.  Dates
#'   and citation counts are estimated and are determined automatically by a
#'   computer program. Use at your own risk.
#'
#' @keywords internal
"_PACKAGE"

# The following block is used by usethis to automatically manage
# roxygen namespace tags. Modify with care!
## usethis namespace: start
## usethis namespace: end
NULL
