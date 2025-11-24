# Path fixing utilities
# Internal helper functions for intelligently fixing bare file paths

#' Fix bare file paths in a line of R code
#'
#' @description
#' Intelligently replaces file paths in common data import functions
#' with `here::here()` wrapped paths. Handles both bare filenames and
#' relative paths with subdirectories. Only modifies actual file references,
#' never comments, strings outside import calls, absolute paths, or URLs.
#'
#' @param line Character string representing a line of R code
#' @param data_folder Character string for the data subfolder (e.g., "data")
#'
#' @return Modified line with paths wrapped in here::here()
#'
#' @keywords internal
#' @noRd
fix_paths_in_line <- function(line, data_folder) {
  # Skip full-line comments
  if (grepl("^\\s*#", line)) {
    return(line)
  }

  # Skip lines that already use here::here()
  if (grepl("here::here\\(", line)) {
    return(line)
  }

  # Skip lines with problematic path patterns:
  # - Absolute paths: start with / or C:/ etc
  # - Home directory: ~/
  # - Parent directory: ../
  # - URLs: http://, https://, ftp://
  # - Network paths: \\\\
  if (grepl("[\"']((/|[A-Za-z]:[\\\\/])|~/|(\\.\\.[\\\\/])|[a-z]+://|\\\\\\\\)", line)) {
    return(line)
  }

  # Common student import patterns (both tidyverse and base R)
  import_functions <- c(
    # readr and tidyverse
    "read_csv", "read_tsv", "read_delim", "read_table", "read_fwf",
    # base R
    "read\\.csv", "read\\.csv2", "read\\.table", "read\\.delim", "read\\.delim2",
    "readRDS", "load", "source",
    # readxl
    "read_excel", "read_xlsx", "read_xls",
    # data.table
    "fread",
    # vroom
    "vroom",
    # qs
    "qread"
  )

  pattern_prefix <- paste0(
    "\\b(?:", paste(import_functions, collapse = "|"), ")\\s*\\(\\s*"
  )

  # Strategy: Use a callback function to process each match
  # This allows us to split paths and build proper here::here() calls
  result <- line

  # Match pattern: function("path/to/file.ext") or function('path/to/file.ext')
  # Captures: (1) function with opening paren, (2) quote type, (3) the path, (4) closing quote
  full_pattern <- paste0(
    "(", pattern_prefix, ")([\"'])([^\"']+\\.([A-Za-z0-9]+))\\2"
  )

  # Find all matches
  matches <- gregexpr(full_pattern, result, perl = TRUE)

  if (matches[[1]][1] != -1) {
    # Process matches in reverse order to maintain string positions
    match_starts <- as.vector(matches[[1]])
    match_lengths <- attr(matches[[1]], "match.length")
    capture_starts <- attr(matches[[1]], "capture.start")
    capture_lengths <- attr(matches[[1]], "capture.length")

    # Process from end to beginning to maintain positions
    for (i in length(match_starts):1) {
      # Extract the matched path (capture group 3)
      path_start <- capture_starts[i, 3]
      path_length <- capture_lengths[i, 3]
      file_path <- substr(result, path_start, path_start + path_length - 1)

      # Extract function prefix (capture group 1)
      func_start <- capture_starts[i, 1]
      func_length <- capture_lengths[i, 1]
      func_prefix <- substr(result, func_start, func_start + func_length - 1)

      # Build the replacement
      replacement <- build_here_call(file_path, data_folder)
      full_replacement <- paste0(func_prefix, replacement)

      # Replace in result string
      match_start <- match_starts[i]
      match_end <- match_start + match_lengths[i] - 1
      result <- paste0(
        substr(result, 1, match_start - 1),
        full_replacement,
        substr(result, match_end + 1, nchar(result))
      )
    }
  }

  return(result)
}

#' Build a here::here() call from a file path
#'
#' @description
#' Converts a file path (bare or relative) into a proper here::here() call.
#' Handles both forward and back slashes, splits path into components.
#'
#' @param file_path Character string with the file path
#' @param data_folder Character string for the data subfolder
#'
#' @return Character string with here::here() call
#'
#' @keywords internal
#' @noRd
build_here_call <- function(file_path, data_folder) {
  # Split path by forward or back slash
  # Handle both / and \ (escaped in regex)
  path_components <- strsplit(file_path, "[/\\\\]")[[1]]

  # Remove empty components
  path_components <- path_components[nchar(path_components) > 0]

  # Logic:
  # 1. If student used relative path (multiple components): use as-is
  # 2. If student used bare filename with data_folder=".": prepend "."
  # 3. If student used bare filename with specific data_folder: prepend that folder

  if (length(path_components) > 1) {
    # Student already specified folder structure: respect it
    # e.g., "data/file.csv" -> here::here("data", "file.csv")
    components_str <- paste0(
      '"', path_components, '"',
      collapse = ", "
    )
  } else {
    # Bare filename: prepend data_folder
    # e.g., "file.csv" with data_folder="." -> here::here(".", "file.csv")
    # e.g., "file.csv" with data_folder="data" -> here::here("data", "file.csv")
    components_str <- paste0('"', data_folder, '", "', path_components, '"')
  }

  return(paste0("here::here(", components_str, ")"))
}


#' Check if 'here' package is available
#'
#' @description
#' Checks if the 'here' package is installed and loads it if needed.
#' Provides helpful error message if not available.
#'
#' @return Logical indicating success
#'
#' @keywords internal
#' @noRd
ensure_here_available <- function() {
  if (!requireNamespace("here", quietly = TRUE)) {
    stop(
      "The 'here' package is required for path fixing but is not installed.\n",
      "Install it with: install.packages(\"here\")\n",
      "Or disable path fixing with: fix_paths = FALSE",
      call. = FALSE
    )
  }

  # Load here package quietly
  suppressPackageStartupMessages(
    requireNamespace("here", quietly = TRUE)
  )

  return(TRUE)
}
