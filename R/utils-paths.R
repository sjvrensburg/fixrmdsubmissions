# Simple path fixing utilities using filename-to-absolute-path mapping

#' Build path mapping from data files
#'
#' @description
#' Scans for common data files in the parent directory and creates a mapping
#' from filename to absolute path. This is used to replace any reference to
#' these files with their full absolute paths.
#'
#' @param rmd_file_path Path to the R Markdown file being processed
#' @param search_dirs Character vector of directories to search. If NULL, searches
#'   parent directory of the Rmd file
#'
#' @return Named list where names are filenames and values are absolute paths
#'
#' @keywords internal
#' @noRd
build_path_map <- function(rmd_file_path, search_dirs = NULL) {
  rmd_dir <- dirname(normalizePath(rmd_file_path, mustWork = TRUE))

  if (is.null(search_dirs)) {
    # Default: search parent directory
    search_dirs <- dirname(rmd_dir)
  }

  path_map <- list()

  # Common data file extensions
  data_extensions <- c("csv", "tsv", "txt", "rds", "RDS", "rda", "RData",
                       "xlsx", "xls", "json", "xml", "feather", "parquet",
                       "sav", "dta", "sas7bdat", "qs")

  for (search_dir in search_dirs) {
    if (!dir.exists(search_dir)) next

    # Find all potential data files
    all_files <- list.files(search_dir, full.names = FALSE, recursive = FALSE)

    for (file in all_files) {
      ext <- tools::file_ext(file)
      if (ext %in% data_extensions) {
        # Map filename to absolute path
        path_map[[file]] <- normalizePath(file.path(search_dir, file), mustWork = TRUE)
      }
    }
  }

  return(path_map)
}

#' Replace file paths in code using path mapping
#'
#' @description
#' Simple string replacement: replaces any quoted occurrence of a filename
#' with its absolute path from the map.
#'
#' @param text Character string of R code
#' @param path_map Named list where names are filenames and values are absolute paths
#'
#' @return Character string with paths replaced
#'
#' @keywords internal
#' @noRd
replace_paths_with_map <- function(text, path_map) {
  if (is.null(path_map) || length(path_map) == 0) {
    return(text)
  }

  result <- text

  # For each file in the map, replace all occurrences
  for (filename in names(path_map)) {
    absolute_path <- path_map[[filename]]

    # Escape special regex characters in filename
    filename_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", filename)

    # Replace patterns like:
    # - "filename.ext"
    # - 'filename.ext'
    # - "path/to/filename.ext" (replace just the last part or whole thing)

    # Pattern 1: Quoted filename (possibly with path components before it)
    # This will match "filename.csv", "data/filename.csv", "../filename.csv", etc.
    pattern1 <- paste0('(["\'])([^"\']*[/\\\\])?', filename_escaped, '\\1')
    replacement1 <- paste0('\\1', absolute_path, '\\1')
    result <- gsub(pattern1, replacement1, result, perl = TRUE)
  }

  return(result)
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
