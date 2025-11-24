test_that("fix_rmd adds eval=FALSE to failing chunks", {
  # Create a temporary Rmd file with a failing chunk
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    "x <- 1 + 1",
    "```",
    "",
    "```{r}",
    "y <- nonexistent_function()",
    "```"
  )

  writeLines(rmd_content, tmp)

  # Fix the file (disable limit_output to avoid injecting setup chunk)
  output <- fix_rmd(tmp, limit_output = FALSE, quiet = TRUE)

  # Read the output
  result <- readLines(output)

  # First chunk should be unchanged (no eval=FALSE)
  first_chunk <- result[grepl("```\\{r", result)][1]
  expect_false(grepl("eval.*FALSE", first_chunk))

  # Second chunk should have eval=FALSE
  second_chunk <- result[grepl("```\\{r", result)][2]
  expect_true(grepl("eval.*FALSE", second_chunk, ignore.case = TRUE))
})

test_that("fix_rmd preserves successful chunks", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    "x <- 1 + 1",
    "y <- 2 + 2",
    "z <- x + y",
    "```"
  )

  writeLines(rmd_content, tmp)

  output <- fix_rmd(tmp, limit_output = FALSE, quiet = TRUE)
  result <- readLines(output)

  # Chunk should not have eval=FALSE
  chunk_header <- result[grepl("```\\{r", result)]
  expect_false(grepl("eval.*FALSE", chunk_header))

  # Code should be preserved
  expect_true(any(grepl("x <- 1 \\+ 1", result)))
  expect_true(any(grepl("y <- 2 \\+ 2", result)))
  expect_true(any(grepl("z <- x \\+ y", result)))
})

test_that("fix_rmd creates backup when requested", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  writeLines(c("---", "title: Test", "---"), tmp)

  fix_rmd(tmp, backup = TRUE, quiet = TRUE)

  expect_true(file.exists(paste0(tmp, ".bak")))
})

test_that("fix_rmd does not create backup when backup=FALSE", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  writeLines(c("---", "title: Test", "---"), tmp)

  fix_rmd(tmp, backup = FALSE, quiet = TRUE)

  expect_false(file.exists(paste0(tmp, ".bak")))
})

test_that("fix_rmd handles chunks with existing eval=FALSE", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r, eval=FALSE}",
    "this_will_not_run()",
    "```"
  )

  writeLines(rmd_content, tmp)

  output <- fix_rmd(tmp, limit_output = FALSE, quiet = TRUE)
  result <- readLines(output)

  # Should preserve existing eval=FALSE
  chunk_header <- result[grepl("```\\{r", result)]
  expect_true(grepl("eval.*FALSE", chunk_header, ignore.case = TRUE))
})

test_that("fix_rmd fixes paths when fix_paths=TRUE", {
  skip_if_not_installed("here")

  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    'data <- read_csv("scores.csv")',
    "```"
  )

  writeLines(rmd_content, tmp)

  output <- fix_rmd(tmp, fix_paths = TRUE, quiet = TRUE)
  result <- readLines(output)

  # Should have here::here in the output
  expect_true(any(grepl("here::here", result)))
})

test_that("fix_rmd does not fix paths when fix_paths=FALSE", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    'data <- read_csv("scores.csv")',
    "```"
  )

  writeLines(rmd_content, tmp)

  output <- fix_rmd(tmp, fix_paths = FALSE, quiet = TRUE)
  result <- readLines(output)

  # Should NOT have here::here in the output
  expect_false(any(grepl("here::here", result)))
})

test_that("fix_rmd handles empty chunks", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    "```"
  )

  writeLines(rmd_content, tmp)

  # Should not error
  expect_error(fix_rmd(tmp, quiet = TRUE), NA)
})

test_that("fix_rmd handles chunks with only comments", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    "# This is just a comment",
    "# Another comment",
    "```"
  )

  writeLines(rmd_content, tmp)

  # Should not error
  expect_error(fix_rmd(tmp, quiet = TRUE), NA)
})

test_that("fix_rmd validates input file exists", {
  expect_error(
    fix_rmd("nonexistent_file.Rmd"),
    "Input file does not exist"
  )
})

test_that("fix_rmd validates input is Rmd file", {
  tmp <- tempfile(fileext = ".txt")
  writeLines("test", tmp)
  on.exit(unlink(tmp))

  expect_error(
    fix_rmd(tmp),
    "must be an R Markdown"
  )
})

test_that("fix_rmd handles sequential chunk dependencies", {
  tmp <- tempfile(fileext = ".Rmd")
  on.exit(unlink(c(tmp, paste0(tmp, ".bak"), sub("\\.Rmd$", "_FIXED.Rmd", tmp))))

  rmd_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "```{r}",
    "x <- 10",
    "```",
    "",
    "```{r}",
    "y <- x + 5",
    "```",
    "",
    "```{r}",
    "z <- y * 2",
    "```"
  )

  writeLines(rmd_content, tmp)

  output <- fix_rmd(tmp, quiet = TRUE)
  result <- readLines(output)

  # None of the chunks should have eval=FALSE since they all work sequentially
  chunk_headers <- result[grepl("```\\{r", result)]
  expect_true(all(!grepl("eval.*FALSE", chunk_headers)))
})
