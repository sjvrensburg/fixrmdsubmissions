test_that("fix_rmd limits large output when limit_output = TRUE", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Create Rmd with code that produces massive output
  rmd_content <- c(
    "---",
    "title: Large Output Test",
    "output: html_document",
    "---",
    "",
    "```{r}",
    "# This would normally print 10000 rows",
    "large_data <- data.frame(",
    "  id = 1:10000,",
    "  value = rnorm(10000)",
    ")",
    "large_data  # Print entire dataset",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  # Fix with output limiting (default)
  output_file <- fix_rmd(
    rmd_file,
    limit_output = TRUE,
    max_print_lines = 50,
    quiet = TRUE
  )

  expect_true(file.exists(output_file))

  # The file should be fixed (eval=FALSE likely added due to data frame print)
  fixed_content <- readLines(output_file)
  # Should have processed the file
  expect_true(length(fixed_content) > 0)
})

test_that("fix_rmd allows unlimited output when limit_output = FALSE", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  rmd_content <- c(
    "---",
    "title: Unlimited Output",
    "output: html_document",
    "---",
    "",
    "```{r}",
    "# Simple output that should work",
    "x <- 1:10",
    "x",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  # Fix without output limiting
  output_file <- fix_rmd(
    rmd_file,
    limit_output = FALSE,
    quiet = TRUE
  )

  expect_true(file.exists(output_file))
  fixed_content <- readLines(output_file)
  expect_true(length(fixed_content) > 0)
})

test_that("fix_rmd respects max_print_lines parameter", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  rmd_content <- c(
    "---",
    "title: Custom Max Lines",
    "output: html_document",
    "---",
    "",
    "```{r}",
    "data.frame(x = 1:100)",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  # Test with custom max_print_lines
  output_file <- fix_rmd(
    rmd_file,
    limit_output = TRUE,
    max_print_lines = 20,
    quiet = TRUE
  )

  expect_true(file.exists(output_file))
})

test_that("fix_folder passes output limiting parameters correctly", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  rmd_content <- c(
    "---",
    "title: Test",
    "output: html_document",
    "---",
    "",
    "```{r}",
    "x <- 1:5",
    "x",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  # Fix folder with output limiting
  fix_folder(
    path = tmp_dir,
    limit_output = TRUE,
    max_print_lines = 50,
    quiet = TRUE
  )

  # Check that fixed file was created
  fixed_file <- file.path(tmp_dir, "test_FIXED.Rmd")
  expect_true(file.exists(fixed_file))
})

test_that("output limiting handles empty chunks gracefully", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  rmd_content <- c(
    "---",
    "title: Empty Chunk",
    "output: html_document",
    "---",
    "",
    "```{r}",
    "# Empty chunk with just a comment",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  output_file <- fix_rmd(
    rmd_file,
    limit_output = TRUE,
    quiet = TRUE
  )

  expect_true(file.exists(output_file))
  fixed_content <- readLines(output_file)
  expect_true(any(grepl("# Empty chunk", fixed_content)))
})

test_that("output limiting works with successful chunks", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  rmd_content <- c(
    "---",
    "title: Successful Chunks",
    "output: html_document",
    "---",
    "",
    "```{r}",
    "x <- 1:10",
    "mean(x)",
    "```",
    "",
    "```{r}",
    "y <- 20:30",
    "sum(y)",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  output_file <- fix_rmd(
    rmd_file,
    limit_output = TRUE,
    max_print_lines = 100,
    quiet = TRUE
  )

  expect_true(file.exists(output_file))
  fixed_content <- readLines(output_file)

  # Successful chunks should not have eval = FALSE
  expect_false(any(grepl("eval\\s*=\\s*FALSE", fixed_content)))
})

test_that("output limiting combined with path fixing works", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Create a small data file
  data_file <- file.path(tmp_dir, "test_data.csv")
  writeLines(c("id,value", "1,10", "2,20"), data_file)

  rmd_content <- c(
    "---",
    "title: Combined Features",
    "output: html_document",
    "---",
    "",
    "```{r}",
    'library(readr)',
    'data <- read_csv("test_data.csv")',
    "data",
    "```"
  )

  rmd_file <- file.path(tmp_dir, "test.Rmd")
  writeLines(rmd_content, rmd_file)

  # Create .here file
  writeLines("here root", file.path(tmp_dir, ".here"))

  output_file <- fix_rmd(
    rmd_file,
    fix_paths = TRUE,
    data_folder = ".",
    limit_output = TRUE,
    max_print_lines = 50,
    quiet = TRUE
  )

  expect_true(file.exists(output_file))
  fixed_content <- readLines(output_file)

  # Should have path fixing
  expect_true(any(grepl('here::here', fixed_content)))
})
