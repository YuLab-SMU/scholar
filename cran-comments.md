## Submission summary

scholar 1.0.1 is a maintenance release. Google Scholar changed how it refuses a
script, and the package reported every one of those refusals as a wrong profile
ID. This release makes the failure honest, adds two functions that had been
requested for years, and stops two features that can no longer work.

- Google Scholar now answers an automated client with a sign-in redirect, a
  captcha page served with HTTP 200, a plain 403, a dropped connection, or a
  429. Each is now named in the warning, a refusal is not retried, and a request
  that never gets a reply no longer raises a curl error into the caller's
  script. Rate limiting backs off with `Retry-After` and a per-process waiting
  budget, so a check on a blocked IP finishes instead of stalling.
- Author search is behind a Google login. `get_scholar_id()` and
  `search_scholar_ids()` are documented as deprecated for anonymous use;
  `search_openalex_authors()` provides the same lookup through OpenAlex, which
  needs no session.
- SCImago serves its ranking table behind a JavaScript challenge and the table
  carries no published licence, so `get_journalrank()` is deprecated and
  downloads nothing. Its help page points at OpenAlex for journal metrics.
- New: `get_citing_articles()` (the works citing a publication) and
  `get_h_index_history()` (the h-index year by year).
- `set_scholar_cookie()` and a set of options with environment-variable
  fallbacks, for deployments on a server or in CI.

All examples that reach Google Scholar degrade to a warning and `NA` when the
check machine is refused, which is the behaviour documented in `?scholar`.

## R CMD CHECK results

0 errors | 0 warnings | 0 notes

- R 4.6.1 on x86_64-pc-linux-gnu (Ubuntu 24.04), including `--run-donttest`.
- GitHub Actions, all passing: ubuntu-22.04 (release and devel), macOS-latest,
  windows-latest.
- The vignette is rebuilt during the check.

## Reverse dependencies

Reverse imports `CoTiMA` and `margaret`, reverse suggests `easystats`. Checked
their current CRAN sources: they call only `get_publications()` and
`get_profile()$name`. Neither is deprecated, and the one return value that grew
(`get_profile()$coauthors`) is not read by any of them, so no reverse
dependency needed a change.
