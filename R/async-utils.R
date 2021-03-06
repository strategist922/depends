
read_etag <- function(etag_file) {
  if (file.exists(etag_file)) {
    tryCatch(readLines(etag_file)[1], error = function(e) NA)
  } else {
    NA
  }
}

download_file <- function(url, target, etag_file = NULL) {
  force(url) ; force(target) ; force(etag_file)
  message("Getting ", sQuote(url))
  http_get(url)$then(function(resp) {
    message("Pulled: ", sQuote(url))
    write_bin_atomic(resp$content, target)
    if (!is.null(etag_file)) {
      etag <- parse_headers_list(resp$headers)[["etag"]]
      writeLines(etag, etag_file)
    }
  })
}

download_if_newer <- function(url, target, etag_file = NULL) {
  force(url) ; force(target)

  headers <- character()
  if (!is.null(etag_file)) {
    etag_old <- read_etag(etag_file)
    if (file.exists(target) && !is.na(etag_old)) {
      headers <- c(headers, c("If-None-Match" = etag_old))
    }
  }

  message("Getting ", sQuote(url))
  http_get(url, headers = headers)$then(function(resp) {
    if (resp$status_code == 304) {
      message("Current: ", sQuote(url))
    } else if (resp$status_code == 200) {
      message("Pulled: ", sQuote(url))
      write_bin_atomic(resp$content, target)
      etag <- parse_headers_list(resp$headers)[["etag"]]
      if (!is.null(etag_file)) writeLines(etag, etag_file)
    } else {
      stop(paste("HTTP error: ", resp$status_code))
    }

    resp
  })
}

download_try_list <- function(urls, targets, etag_file = NULL,
                              headers = character()) {
  assert_that(is.character(urls), length(urls) >= 1)

  force(urls) ; force(targets) ; force(etag_file) ; force(headers)

  message("Getting ", sQuote(urls[1]))

  if (!is.null(etag_file)) {
    etag_old <- read_etag(etag_file)
    if (any(file.exists(targets)) && !is.na(etag_old)) {
      headers <- c(headers, c("If-None-Match" = etag_old))
    }
  }

  status_code <- NULL
  error <- NULL
  async_detect(
    urls,
    function(x) {
      http_get(x, headers = headers)$
        then(function(resp) {
          http_stop_for_status(resp)
          if (resp$status_code == "304") {
            message("Current ", sQuote(x))
          } else {
            message("Pulled ", sQuote(x))
            write_bin_atomic(resp$content, targets[1])
            etag <- parse_headers_list(resp$headers)[["etag"]]
            if (!is.null(etag_file)) writeLines(etag, etag_file)
          }
          status_code <<- resp$status_code
          TRUE
        })$
        catch(~ FALSE)
    },
    .limit = 1
  )$then(function(url) {
    if (is.null(url)) {
      stop(make_error("All URLs failed", "http_error", error = error))
    }
    status_code
  })

}
