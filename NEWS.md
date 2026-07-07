# scholar 0.2.7

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
