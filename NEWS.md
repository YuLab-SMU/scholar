# scholar 1.0.1

+ Google Scholar refuses a script in more ways than a failed request, and each one is now named: a sign-in redirect, a captcha page served with HTTP 200, a 403, a dropped connection, or a rate limit. A refusal is reported once per session with its real cause instead of "Cannot connect to Google Scholar. Is the ID you provided correct?" (2026-10-29, Thu, jkeirstead#123)
+ send browser-like headers on every request, back off exponentially with jitter when rate limited, honour `Retry-After` in both its forms, and bound the total waiting per process with `scholar_retry_budget` (60 seconds by default), so a blocked check fails fast instead of spending its time on delays (2026-10-29, Thu, jkeirstead#123)
+ author search now requires a signed-in session, so `get_scholar_id()` and `search_scholar_ids()` are deprecated for anonymous use and say when Google refused rather than finding nothing; `search_openalex_authors()` answers the same question from OpenAlex with no session, and a fractional `max_results` is rounded rather than sent as a request OpenAlex rejects (2026-10-29, Thu, jkeirstead#91)
+ `set_scholar_cookie()` and the `scholar_cookie` / `scholar_cookie_file` settings present a session exported from a browser. It is sent as a cookie, so it merges with Google's own and survives the redirect to the sign-in host, and it is never sent to a mirror that is not a Google host (2026-10-29, Thu, jkeirstead#91)
+ add `get_citing_articles()`: the works citing a publication, with venue, year and their own citation counts (2026-10-29, Thu, jkeirstead#4, jkeirstead#107)
+ add `get_h_index_history()`: the h-index year by year, rebuilt from each publication's citation history and cached so the expensive pass happens once. It works for a profile whose cited papers all fall in one year, and a refused history is no longer cached as a paper that was never cited (2026-10-29, Thu, jkeirstead#73)
+ `get_profile()` reports every colleague rather than the twenty the sidebar shows, and no longer mistakes a profile's sort-menu links for coauthors (2026-10-29, Thu)
+ `get_journalrank()` is deprecated and downloads nothing: SCImago serves a JavaScript challenge to scripts and its table carries no published licence. The help page points at OpenAlex for journal metrics (2026-10-29, Thu)
+ new settings, each falling back to an environment variable of the same name in upper case, for hosted deployments and CI: `scholar_user_agent`, `scholar_accept_language`, `scholar_request_delay`, `scholar_retry_delay`, `scholar_retry_max_delay`, `scholar_retry_budget`, `scholar_timeout`, `scholar_cookie`, `scholar_cookie_file` and `scholar_openalex_mailto` (2026-10-29, Thu)
+ the README and the vignette say what to do when Scholar refuses a request, list every setting the package reads, and warn which endpoints a server cannot reach (2026-10-29, Thu, jkeirstead#123, jkeirstead#91)

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
