context("publication parsing")

test_that("parse_citation_counts handles formatted and struck-through text", {
  html <- paste0(
    "<html><body>",
    "<a class='gsc_a_ac'>1,234</a>",
    "<a class='gsc_a_ac'></a>",
    "<a class='gsc_a_ac'><span>1\u03362\u03363\u0336</span><br>45</a>",
    "</body></html>"
  )
  nodes <- xml2::read_html(html) %>% rvest::html_nodes(".gsc_a_ac")

  expect_equal(scholar:::parse_citation_counts(nodes), c(1234, 0, 45))
})
