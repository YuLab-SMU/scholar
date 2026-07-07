context("scholar response encoding")

test_that("read_scholar_html falls back for Latin-1 Scholar responses", {
  html <- "<html><body><table><tr><td>Schrödinger</td></tr></table></body></html>"
  resp <- structure(
    list(
      url = "https://scholar.google.com/citations",
      status_code = 200L,
      headers = structure(list("content-type" = "text/html"), class = "insensitive"),
      all_headers = list(),
      cookies = data.frame(),
      content = charToRaw(iconv(html, from = "UTF-8", to = "ISO-8859-1"))
    ),
    class = "response"
  )

  table <- rvest::html_table(scholar:::read_scholar_html(resp))[[1]]

  expect_equal(table[[1]], "Schrödinger")
})
