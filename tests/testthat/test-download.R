
context("downloads")

test_that("download_file", {

  skip_if_offline()

  dir.create(dir <- tempfile())
  dx <- download_file(
    url    <- "https://httpbin.org/etag/foobar",
    target <- file.path(dir, "file1"),
    etag   <- file.path(dir, "etag")
  )

  await(dx)
  expect_true(file.exists(target))
  expect_equal(jsonlite::fromJSON(target)$url, url)
  expect_true(file.exists(etag))
  expect_equal(readLines(etag), "foobar")
})

test_that("download_if_newer, no etag file", {

  skip_if_offline()

  dir.create(dir <- tempfile())
  dx <- download_if_newer(
    url    <- "https://httpbin.org/etag/foobar",
    target <- file.path(dir, "file1"),
    etag   <- file.path(dir, "etag")
  )

  await(dx)
  expect_true(file.exists(target))
  expect_equal(jsonlite::fromJSON(target)$url, url)
  expect_true(file.exists(etag))
  expect_equal(readLines(etag), "foobar")
})

test_that("download_if_newer, different etag", {

  skip_if_offline()

  dir.create(dir <- tempfile())

  cat("eeeetag\n", file = etag <- file.path(dir, "etag"))
  dx <- download_if_newer(
    url    <- "https://httpbin.org/etag/foobar",
    target <- file.path(dir, "file1"),
    etag
  )

  await(dx)
  expect_true(file.exists(target))
  expect_equal(jsonlite::fromJSON(target)$url, url)
  expect_true(file.exists(etag))
  expect_equal(readLines(etag), "foobar")
})

test_that("download_if_newer, matching etag", {

  skip_if_offline()

  dir.create(dir <- tempfile())

  cat("foobar\n", file = etag <- file.path(dir, "etag"))
  cat("dummy\n", file = target <- file.path(dir, "file1"))
  dx <- download_if_newer(
    url    <- "https://httpbin.org/etag/foobar",
    target,
    etag
  )

  await(dx)
  expect_true(file.exists(target))
  expect_equal(readLines(target), "dummy")
  expect_true(file.exists(etag))
  expect_equal(readLines(etag), "foobar")
})

test_that("download_try_list", {

  skip_if_offline()

  dx <- download_try_list(
    c("https://httpbin.org/status/404",
      "https://httpbin.org/status/403",
      "https://httpbin.org/get?q=1"),
    tmp <- tempfile()
  )

  async::await(dx)
  res <- jsonlite::fromJSON(readLines(tmp), simplifyVector = FALSE)
  expect_equal(res$args$q, "1")
})

test_that("download_try_list, errors", {

  skip_if_offline()

  dx <- download_try_list(
    c("https://httpbin.org/status/404",
      "https://httpbin.org/status/403",
      "https://httpbin.org/status/404"),
    tmp <- tempfile()
  )

  expect_error(async::await(dx), "All URLs failed")
  expect_false(file.exists(tmp))
})
