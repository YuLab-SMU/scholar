# scholar

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/scholar)](https://CRAN.R-project.org/package=scholar)
[![R-CMD-check](https://github.com/YuLab-SMU/scholar/workflows/R-CMD-check/badge.svg)](https://github.com/YuLab-SMU/scholar/actions)
<!-- badges: end -->

`scholar` is an R package for pulling publication and citation data from Google Scholar profiles. It helps you answer the everyday questions that come up when maintaining a CV, checking a collaborator's profile, comparing citation trajectories, or doing a quick bibliometric sanity check.

Google Scholar has no official public API, so this package is necessarily a scraper. That means two things: **use it gently**, and **expect occasional breakage when Google changes its HTML**. I try to keep the package practical rather than magical; if a query can be done with a few small requests, `scholar` is a handy tool. If you want to crawl half of Google Scholar, life is short, don't do that.

## Installation

Install the CRAN release:

```r
install.packages("scholar")
```

Or install the development version from GitHub:

```r
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("YuLab-SMU/scholar")
```

## Find a Scholar ID

Most functions start from a Google Scholar profile ID. In this URL:

```text
https://scholar.google.com/citations?user=B7vSqZsAAAAJ
```

the ID is `B7vSqZsAAAAJ`.

If you only have a name, try searching first:

```r
library(scholar)

search_scholar_ids("Richard Feynman", max_pages = 1)
get_scholar_id(first_name = "Richard", last_name = "Feynman")
```

If you copied a full URL, `tidy_id()` keeps only the useful part:

```r
tidy_id("https://scholar.google.com/citations?user=B7vSqZsAAAAJ&hl=en")
#> "B7vSqZsAAAAJ"
```

## Get Profile and Publication Data

```r
id <- "B7vSqZsAAAAJ"

profile <- get_profile(id)
profile$name
profile[c("total_cites", "h_index", "i10_index")]

pubs <- get_publications(id)
head(pubs)
```

`get_publications()` returns a data frame with publication titles, displayed authors, venue text, citation counts, years, Google Scholar citation IDs, and publication IDs. This is usually the object you want to fetch once and reuse.

```r
recent <- subset(pubs, !is.na(year) & year >= 2020)
get_publication_metrics(recent)
```

## Citation History

Scholar profiles expose yearly citation bars. `scholar` turns them into a data frame, so plotting is just ordinary R code.

```r
ct <- get_citation_history(id)

plot(
  ct$year, ct$cites,
  type = "b",
  xlab = "Year",
  ylab = "Citations"
)
```

For article-level citation history, use a publication ID from `get_publications()`:

```r
get_article_cite_history(id, pubs$pubid[1])
```

## Compare Scholars

```r
ids <- c("B7vSqZsAAAAJ", "DO5oG40AAAAJ")

compare_scholars(ids)
compare_scholar_careers(ids)
```

`compare_scholars()` compares citation totals by publication year. `compare_scholar_careers()` aligns scholars by career year, which is often a fairer comparison than raw calendar year.

## Coauthor Networks

```r
network <- get_coauthors("DO5oG40AAAAJ", n_coauthors = 5, n_deep = 0)
plot_coauthors(network)
```

Keep `n_coauthors` and `n_deep` small. Coauthor graphs get messy quickly, and repeated requests may trigger rate limits. 强迫症想把网络挖到底？我懂，但 Google 不一定惯着你。

## Format Publications for a CV

`format_publications()` returns publication strings that work nicely in R Markdown, Quarto, or CV workflows. The selected author can be highlighted in bold.

```r
format_publications("DO5oG40AAAAJ", author.name = "Guangchuang Yu") |>
  cat(sep = "\n\n")
```

For a numbered list, print the returned vector directly:

```r
format_publications("DO5oG40AAAAJ", author.name = "Guangchuang Yu") |>
  print(quote = FALSE)
```

## More Things It Can Do

A few useful helpers are easy to miss:

- `get_scholar_metrics()` calculates h-index, g-index, i10-index, i50-index, i100-index, and related summaries.
- `get_publication_data_extended()` extracts extra metadata from a publication detail page.
- `get_complete_authors()` completes author lists that Google Scholar truncates with `...`.
- `author_position()` checks where an author appears in publication author lists.
- `get_journalrank()` queries SCImago journal ranking data.
- `predict_h_index()` implements the Acuna et al. h-index prediction model; treat it as illustrative, not prophecy.

## Practical Notes

- Google Scholar may rate-limit repeated requests; small, focused queries are more reliable.
- `get_publications()` caches results with `R.cache`; use `flush = TRUE` when you need fresh data.
- Some Scholar profiles hide fields or have incomplete metadata, so `NA` and empty values are normal.
- For larger analyses, fetch publication data once, save it locally, and analyse the saved data frame.

```r
pubs <- get_publications(id, flush = TRUE)
saveRDS(pubs, "scholar-publications.rds")
```

## Learn More

The package vignette has a fuller walkthrough:

```r
vignette("scholar", package = "scholar")
```

Bugs and feature requests are welcome on GitHub: <https://github.com/YuLab-SMU/scholar/issues>.
