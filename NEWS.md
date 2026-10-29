# scholar 1.0.0.016

+ make `get_h_index_history()` work for a scholar whose cited papers all earned their citations in the same year, and for a single cited paper: accumulating a one-row or one-column table made `apply()` return a bare vector, which then failed on row indexing, so the function errored out for exactly the people it is most useful to (2026-10-29, Thu, jkeirstead#73)

+ cap the total time one process will spend waiting for a rate-limited Scholar (`scholar_retry_budget`, 60 seconds by default): past that a refused request is abandoned at once, because a CI job that keeps waiting on a refusing IP only lengthens its own lockout — the polite backoff added this week turned a blocked check run from three minutes into eighteen (2026-10-29, Thu)

+ add `get_h_index_history()`, which rebuilds the h-index year by year from each publication's citation history, so a profile reads as a trajectory instead of a single number; the histories are cached and uncited publications are skipped, since they cannot enter an h-index in any year (2026-10-29, Thu, jkeirstead#73)

+ `get_journalrank()` is deprecated and fetches nothing: SCImago answers a script with a JavaScript challenge, and the table has no published licence. It now explains where journal metrics can honestly come from (OpenAlex) instead of failing after a download that cannot succeed, and the archived-copy fallback added the same week is gone (2026-10-29, Thu)

+ add `search_openalex_authors()`, which finds authors and their h-index and i10-index in OpenAlex — the route that needs no session, since Google now signs in every anonymous author search (2026-10-29, Thu, jkeirstead#91)
+ deprecate `get_scholar_id()` and `search_scholar_ids()` for anonymous use, in the docs and in what they report, so an empty result no longer reads as a person who does not exist (2026-10-29, Thu, jkeirstead#91)

+ name the captcha that Scholar serves from its own host as what it is, so the advice no longer blames `google.com/sorry` for a page that never redirected there, and drop the indentation that leaked into the middle of the warning (2026-10-29, Thu)

+ document what to do when Scholar refuses a request: the README and the vignette now name the four ways out, list every setting the package reads, and explain why author search and the cited-by list come back empty on a server (2026-10-29, Thu, jkeirstead#123, jkeirstead#91)

+ send the configured session as a cookie rather than as a `Cookie` header, so it is merged with the cookies Google sets instead of replacing them and survives the redirect to a sign-in host (2026-10-29, Thu, jkeirstead#91)
+ refuse to send a session to a mirror that is not a Google host, and say so, because a session is a credential (2026-10-29, Thu)

+ `get_journalrank()` falls back to an archived copy of the SCImago table and accepts a source of your own, because SCImago now answers a script with a JavaScript challenge and the live export cannot be read at all (2026-10-29, Thu)

+ add `get_citing_articles()`, which lists the works Google Scholar cites a publication with — the "who cites it, and where" that jkeirstead#4 and jkeirstead#107 asked for, and what a citation count on its own cannot answer (2026-10-29, Thu, jkeirstead#4, jkeirstead#107)
+ recognise the captcha page Scholar serves from its own host with HTTP 200, so a refused request is reported as a refusal instead of looking like a publication that nothing cites (2026-10-29, Thu, jkeirstead#123)

+ add `set_scholar_cookie()` and the `scholar_cookie` / `scholar_cookie_file` settings, so a session exported from a browser can be presented to the endpoints Google now signs in first (2026-10-29, Thu, jkeirstead#91)
+ make the browser headers actually reach the request: `httr` silently discards a list of settings passed as a single argument, so the request went out as `libcurl` after all (2026-10-29, Thu, jkeirstead#123)
+ explain a Scholar refusal when author search comes back empty, from `get_scholar_id()` and `search_scholar_ids()`, instead of reporting a bare "No Scholar ID found." (2026-10-29, Thu)
+ state sign-in, captcha and rate-limit refusals once per session rather than on every request, and give each request a 30 second timeout (2026-10-29, Thu)

+ stop `get_profile()` reporting the publication sort links of a profile as its coauthors, which happened on every profile that lists no colleagues (2026-10-29, Thu)

+ send browser-like headers to Google Scholar and recognise the sign-in, captcha and 403 pages it returns when it refuses a client, so a blocked request now names the reason instead of blaming the ID (2026-10-29, Thu, jkeirstead#123)
+ back off exponentially before retrying a rate-limited request, honour Scholar's `Retry-After` header, and give up when Google asks for longer than the budget allows (2026-10-29, Thu, jkeirstead#123)
+ add the `scholar_user_agent`, `scholar_accept_language`, `scholar_request_delay`, `scholar_retry_delay` and `scholar_retry_max_delay` options, each falling back to an environment variable of the same name in upper case (2026-10-29, Thu)

+ fix `get_scholar_id()` aborting with "object 'aa' not found" when Google Scholar refuses the connection, so that it now reports that no ID was found and returns `NA` (2026-10-28, Wed)

# scholar 1.0.0

+ convert the package vignette from R Markdown to Quarto and expand the feature overview (2026-07-07, Tue)
+ fix `author_position()` normalized-position typo for missing author positions (2026-07-07, Tue, #105)
+ retry transient Google Scholar 404 responses before returning unavailable data (2026-07-07, Tue, #108)
+ fix `get_complete_authors()` URL construction and tolerate Scholar IDs with trailing query parameters (2026-07-07, Tue, #117)
+ use Google Scholar's full colleagues list when retrieving coauthors to avoid the profile sidebar limit (2026-07-07, Tue, #120)
+ add `get_publications_all_authors()` to fill truncated publication author lists only when needed (2026-07-07, Tue, #122)
+ add `search_scholar_ids()` to return all author IDs from paginated Google Scholar author search results (2026-07-07, Tue, #88)
+ add `get_publication_metrics()` and `get_scholar_metrics()` for h-index, g-index, i10, i50, and i100 metrics (2026-07-07, Tue)
+ make citation history parsing tolerate mismatched Google Scholar chart labels and values (2026-07-07, Tue)
+ make `predict_h_index()` return `NA` instead of erroring when publication metrics are unavailable (2026-07-07, Tue)
+ improve publication citation count parsing for formatted or struck-through Google Scholar values (2026-07-07, Tue)
+ restore `get_journalrank()` with browser-like SCImago CSV download to avoid HTTP 403 errors (2026-07-07, Tue)
+ fix Google Scholar HTML encoding conversion to avoid example failures when pages contain Latin-1 characters (2026-07-07, Tue)

# scholar 0.2.6

+ fix `get_publications(sortby='year')` issue (2026-02-26, Thu, #5)
+ enhance get_scholar_id search with multiple mauthors query variants (2026-02-26, Thu)
+ fix get_scholar_id to robustly parse author search results (2026-02-26, Thu, #4)
+ fix get_scholar_id query encoding to use '+' for spaces and '%22' for quotes (2026-02-26, Thu)
+ add fallback parsing for user%3D and JSON/data-user formats; improve messages (2026-02-26, Thu)
+ updated scholar IDs in compare_scholars examples and vignette to fix R check warnings (2026-02-21, Sat)

# scholar 0.2.5

+ bug fixed in `format_publications()` and fixed R check (2025-06-21, Sat)
+ bug fixed in `predict_h_index()` (2024-01-3, Wed)
+ update vignette and readme with `format_publications()` function (2022-08-09, Tue, @rempsyc, #1)

# scholar 0.2.4

+ `get_article_scholar_url()`, `get_publication_abstract()`, `get_publication_data_extended()`, `get_publication_date()` and `get_publication_url()` (2022-08-01, Mon, #113)
+ fixed bug in parsing ID with '-' character in `get_scholar_id()` (2022-07-26, Tue)
+ fixed duplicated profiles and update regexpr to extract ID in `get_scholar_id()` (2022-06-25, Sat, #111, #112)

# scholar 0.2.3

+ `format_publications` to format publication list (2022-06-21, Tue)
    - <https://github.com/jkeirstead/scholar/issues/110>
+ update journal ranking data
+ remove `get_impactfactor`
+ fixed when some years contain 0 cites (@jefferis, #101)
+ update documents (@jefferis, #100)

# scholar 0.2.2

+ return NULL if fail to access data (follow CRAN policy)
+ restore `pubid` (@conig, #97)
+ extending `get_profile(id)` to include professional interests (@TS404, #95)
+ allow `n_deep = 0`, for immediate author network (#timonelmer, #90)

# scholar 0.2.0

+ `set_scholar_mirror` to allow user to set a google scholar mirror (2021-01-04)
