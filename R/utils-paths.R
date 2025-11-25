# Path fixing and output management utilities
# Internal helper functions for intelligently fixing bare file paths and managing output

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


#' Auto-detect if data files are in parent directory
#'
#' @description
#' Scans the file for common data import patterns and checks if the files
#' referenced exist in the current directory or parent directory.
#' Returns ".." if data files are found in parent, "." otherwise.
#'
#' @param lines Character vector of R Markdown file lines
#' @param rmd_file_path Character string with path to the Rmd file
#'
#' @return Character string: ".." if parent directory has data files, "." otherwise
#'
#' @keywords internal
#' @noRd
auto_detect_data_folder <- function(lines, rmd_file_path) {
  # Extract directory of the Rmd file
  rmd_dir <- dirname(normalizePath(rmd_file_path, mustWork = TRUE))
  parent_dir <- dirname(rmd_dir)

  # Find all likely data filenames from import statements
  # Match patterns like read_csv("filename") or read.csv("filename")
  import_pattern <- '(?:read_csv|read_tsv|read_delim|read_table|read_fwf|read\\.csv|read\\.csv2|read\\.table|read\\.delim|read\\.delim2|readRDS|load|source|read_excel|read_xlsx|read_xls|fread|vroom|qread)\\s*\\(\\s*["\']([^"\']+)["\']'

  filenames <- character()
  for (line in lines) {
    matches <- gregexpr(import_pattern, line, perl = TRUE)
    if (matches[[1]][1] != -1) {
      # Extract captured group (filename)
      capture_starts <- attr(matches[[1]], "capture.start")
      capture_lengths <- attr(matches[[1]], "capture.length")

      for (i in seq_along(capture_starts)) {
        if (capture_starts[i] > 0) {
          filename <- substr(line, capture_starts[i], capture_starts[i] + capture_lengths[i] - 1)
          filenames <- c(filenames, filename)
        }
      }
    }
  }

  # Check if extracted filenames exist in parent directory
  # (and not already in current directory as absolute/relative paths)
  for (filename in filenames) {
    # Skip if it looks like an absolute path or has path separators
    if (!grepl("[/\\\\]|^~/|^\\.\\.|\\.\\./", filename)) {
      if (file.exists(file.path(parent_dir, filename))) {
        # Found a data file in parent directory
        return("..")
      }
    }
  }

  # No data files found in parent directory
  return(".")
}

#' Generate setup chunk code for output management
#'
#' @description
#' Creates R code that sets up global options for limiting output
#' and managing large data dumps. This code is injected into setup chunks
#' or added as a new setup chunk if none exists.
#'
#' @return Character vector of R code lines for setup
#'
#' @keywords internal
#' @noRd
generate_setup_code <- function() {
  setup_lines <- c(
    "# Global options to prevent massive data dumps",
    "# Added automatically by fixrmdsubmissions package",
    "library(pander)",
    "",
    "# Limit console output to prevent massive data dumps",
    "options(max.print = 1000)",
    "",
    "# Configure pander for reasonable table output",
    "panderOptions('table.split.table', 80)",
    "panderOptions('table.emphasize.rownames', FALSE)",
    "panderOptions('table.split.cells', 30)",
    "panderOptions('keep.line.breaks', TRUE)",
    "",
    "# Set reasonable line width",
    "options(width = 80)"
  )
  
  return(setup_lines)
}

#' Inject setup code into document
#'
#' @description
#' Searches for existing setup chunks and appends global options code to them.
#' If no setup chunk exists, creates one after the YAML header.
#' Preserves existing setup chunk code while adding output management.
#'
#' @param lines Character vector of R Markdown file lines
#' @return Modified character vector with setup code injected
#'
#' @keywords internal
#' @noRd
inject_setup_code <- function(lines) {
  setup_code <- generate_setup_code()

  # Look for existing setup chunks (setup, echo=FALSE, include=FALSE patterns)
  setup_chunk_pattern <- "^\\s*```+\\s*\\{\\s*r[^}]*\\b(setup|echo\\s*=\\s*FALSE|include\\s*=\\s*FALSE)"
  setup_chunks <- grep(setup_chunk_pattern, lines, ignore.case = TRUE)

  if (length(setup_chunks) > 0) {
    # Use first setup chunk found
    setup_start <- setup_chunks[1]

    # Find end of this chunk
    setup_end <- setup_start
    while (setup_end <= length(lines) && !grepl("^\\s*```+\\s*$", lines[setup_end])) {
      setup_end <- setup_end + 1
    }

    if (setup_end > setup_start && setup_end <= length(lines)) {
      # Check if our code is already there
      existing_content <- paste(lines[(setup_start + 1):(setup_end - 1)], collapse = "\n")
      if (!grepl("Added automatically by fixrmdsubmissions package", existing_content)) {
        # Insert our setup code before the closing ```
        before_chunk <- lines[1:(setup_end - 1)]
        after_chunk <- lines[setup_end:length(lines)]

        # Add setup code with blank lines
        lines <- c(before_chunk, "", setup_code, "", after_chunk)
      }
    }
  } else {
    # No setup chunk found - create one after YAML header
    # Find end of YAML header
    yaml_end <- 0
    in_yaml <- FALSE
    yaml_count <- 0

    for (i in seq_along(lines)) {
      if (grepl("^---\\s*$", lines[i])) {
        yaml_count <- yaml_count + 1
        if (yaml_count == 1) {
          in_yaml <- TRUE
        } else if (yaml_count == 2) {
          yaml_end <- i
          break
        }
      }
    }

    # Insert setup chunk after YAML (or at beginning if no YAML)
    insert_pos <- if (yaml_end > 0) yaml_end else 0

    new_setup_chunk <- c(
      "",
      "```{r setup, include=FALSE}",
      "knitr::opts_chunk$set(echo = TRUE)",
      "",
      setup_code,
      "```",
      ""
    )

    if (insert_pos > 0) {
      before_yaml <- lines[1:insert_pos]
      after_yaml <- lines[(insert_pos + 1):length(lines)]
      lines <- c(before_yaml, new_setup_chunk, after_yaml)
    } else {
      # No YAML, insert at beginning
      lines <- c(new_setup_chunk, lines)
    }
  }

  return(lines)
}
