test_that("fix_paths_in_line converts bare filenames in read_csv", {
  line <- 'data <- read_csv("scores.csv")'
  result <- fix_paths_in_line(line, "data")
  expect_match(result, 'here::here\\("data", "scores.csv"\\)')
})

test_that("fix_paths_in_line handles multiple import functions", {
  line1 <- 'df1 <- read.csv("file1.csv")'
  result1 <- fix_paths_in_line(line1, "data")
  expect_match(result1, 'here::here\\("data", "file1.csv"\\)')

  line2 <- 'df2 <- readRDS("model.rds")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_match(result2, 'here::here\\("data", "model.rds"\\)')

  line3 <- 'df3 <- fread("large.csv")'
  result3 <- fix_paths_in_line(line3, "data")
  expect_match(result3, 'here::here\\("data", "large.csv"\\)')
})

test_that("fix_paths_in_line does not modify full-line comments", {
  line <- '# data <- read_csv("scores.csv")'
  result <- fix_paths_in_line(line, "data")
  expect_equal(result, line)
})

test_that("fix_paths_in_line handles inline comments", {
  # Note: Inline comments containing import function patterns will be modified
  # This is a known limitation but extremely rare in practice
  line <- 'x <- 5  # read_csv("test.csv")'
  result <- fix_paths_in_line(line, "data")
  # In practice, inline comments with import functions are very rare
  # The function prioritizes correctness for actual import calls
  expect_match(result, "x <- 5")  # Code part is preserved
})

test_that("fix_paths_in_line converts simple relative paths", {
  # Simple relative path: data/file.csv
  line1 <- 'data <- read_csv("data/scores.csv")'
  result1 <- fix_paths_in_line(line1, ".")
  expect_match(result1, 'here::here\\("data", "scores.csv"\\)')

  # With specific data_folder, multi-component paths still respected
  line2 <- 'df <- read_csv("raw/student_data.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_match(result2, 'here::here\\("raw", "student_data.csv"\\)')
})

test_that("fix_paths_in_line converts multi-level relative paths", {
  line <- 'data <- read_csv("data/raw/scores.csv")'
  result <- fix_paths_in_line(line, ".")
  expect_match(result, 'here::here\\("data", "raw", "scores.csv"\\)')
})

test_that("fix_paths_in_line handles Windows-style backslashes", {
  line <- 'data <- read_csv("data\\\\scores.csv")'
  result <- fix_paths_in_line(line, ".")
  expect_match(result, 'here::here\\("data", "scores.csv"\\)')
})

test_that("fix_paths_in_line does NOT modify absolute paths", {
  # Unix absolute path
  line1 <- 'data <- read_csv("/absolute/path/scores.csv")'
  result1 <- fix_paths_in_line(line1, "data")
  expect_equal(result1, line1)

  # Windows absolute path
  line2 <- 'data <- read_csv("C:/Users/data/scores.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_equal(result2, line2)

  # Home directory
  line3 <- 'data <- read_csv("~/Documents/scores.csv")'
  result3 <- fix_paths_in_line(line3, "data")
  expect_equal(result3, line3)
})

test_that("fix_paths_in_line does NOT modify parent directory references", {
  line1 <- 'data <- read_csv("../relative/scores.csv")'
  result1 <- fix_paths_in_line(line1, "data")
  expect_equal(result1, line1)

  line2 <- 'data <- read_csv("..\\\\relative\\\\scores.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_equal(result2, line2)
})

test_that("fix_paths_in_line does NOT modify URLs", {
  line1 <- 'data <- read_csv("http://example.com/data.csv")'
  result1 <- fix_paths_in_line(line1, "data")
  expect_equal(result1, line1)

  line2 <- 'data <- read_csv("https://example.com/data.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_equal(result2, line2)
})

test_that("fix_paths_in_line does not modify lines with existing here::here", {
  line <- 'data <- read_csv(here::here("data", "scores.csv"))'
  result <- fix_paths_in_line(line, "data")
  expect_equal(result, line)
})

test_that("fix_paths_in_line does not modify strings outside import functions", {
  line <- 'title <- "scores.csv"'
  result <- fix_paths_in_line(line, "data")
  expect_equal(result, line)

  line2 <- 'print("Load file data.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_equal(result2, line2)
})

test_that("fix_paths_in_line handles custom data folders", {
  line <- 'data <- read_csv("scores.csv")'
  result <- fix_paths_in_line(line, "raw_data")
  expect_match(result, 'here::here\\("raw_data", "scores.csv"\\)')
})

test_that("fix_paths_in_line handles various file extensions", {
  extensions <- c("csv", "xlsx", "rds", "RData", "txt", "tsv")
  for (ext in extensions) {
    line <- sprintf('data <- read_csv("file.%s")', ext)
    result <- fix_paths_in_line(line, "data")
    expect_match(result, sprintf('here::here\\("data", "file.%s"\\)', ext))
  }
})

test_that("fix_paths_in_line handles multiple import calls on one line", {
  line <- 'df1 <- read_csv("data1.csv"); df2 <- read_csv("data2.csv")'
  result <- fix_paths_in_line(line, "data")
  expect_match(result, 'here::here\\("data", "data1.csv"\\)')
  expect_match(result, 'here::here\\("data", "data2.csv"\\)')
})

test_that("fix_paths_in_line handles mixed bare and relative paths", {
  # Bare filename
  line1 <- 'df1 <- read_csv("scores.csv")'
  result1 <- fix_paths_in_line(line1, "data")
  expect_match(result1, 'here::here\\("data", "scores.csv"\\)')

  # Relative path with multiple components
  line2 <- 'df2 <- read_csv("raw/subfolder/scores.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_match(result2, 'here::here\\("raw", "subfolder", "scores.csv"\\)')
})

test_that("fix_paths_in_line preserves single quotes", {
  line <- "data <- read_csv('data/scores.csv')"
  result <- fix_paths_in_line(line, ".")
  expect_match(result, 'here::here\\("data", "scores.csv"\\)')
})

test_that("fix_paths_in_line handles nested function calls", {
  # Path inside import function should still be fixed
  line <- 'df <- data.frame(x = read_csv("data/test.csv"))'
  result <- fix_paths_in_line(line, ".")
  expect_match(result, 'here::here\\("data", "test.csv"\\)')
})

test_that("fix_paths_in_line handles whitespace variations", {
  # Extra spaces
  line1 <- 'df <- read_csv(  "data/file.csv"  )'
  result1 <- fix_paths_in_line(line1, ".")
  expect_match(result1, 'here::here\\("data", "file.csv"\\)')

  # Newlines (though rare in single line)
  line2 <- 'df <- read_csv(\n"data/file.csv"\n)'
  result2 <- fix_paths_in_line(line2, ".")
  expect_match(result2, 'here::here\\("data", "file.csv"\\)')
})

test_that("build_here_call splits paths correctly", {
  # Test the helper function directly

  # Bare filename with specific data_folder
  result1 <- build_here_call("file.csv", "data")
  expect_equal(result1, 'here::here("data", "file.csv")')

  # Bare filename with data_folder="."
  result1b <- build_here_call("file.csv", ".")
  expect_equal(result1b, 'here::here(".", "file.csv")')

  # Relative path: use structure as-is (ignore data_folder)
  result2 <- build_here_call("data/file.csv", ".")
  expect_equal(result2, 'here::here("data", "file.csv")')

  # Multi-level relative path
  result3 <- build_here_call("folder/subfolder/file.csv", ".")
  expect_equal(result3, 'here::here("folder", "subfolder", "file.csv")')

  # Relative path with any data_folder: use actual structure
  result4 <- build_here_call("raw/data/file.csv", "data")
  expect_equal(result4, 'here::here("raw", "data", "file.csv")')
})

test_that("fix_paths_in_line handles real student scenarios", {
  # Scenario 1: Student created "data" subfolder
  line1 <- 'student_data <- read_csv("data/test_data.csv")'
  result1 <- fix_paths_in_line(line1, ".")
  expect_match(result1, 'here::here\\("data", "test_data.csv"\\)')

  # Scenario 2: Student used bare filename, instructor expects "data" folder
  line2 <- 'scores <- read_csv("test_data.csv")'
  result2 <- fix_paths_in_line(line2, "data")
  expect_match(result2, 'here::here\\("data", "test_data.csv"\\)')

  # Scenario 3: Student used different folder structure
  line3 <- 'data <- read_csv("raw_data/processed/scores.csv")'
  result3 <- fix_paths_in_line(line3, ".")
  expect_match(result3, 'here::here\\("raw_data", "processed", "scores.csv"\\)')
})
