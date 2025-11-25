#' Fix common issues in a single R Markdown file
#'
#' @description
#' Processes a single R Markdown file to fix common student submission issues:
#' \itemize{
#'   \item Sequentially evaluates all R code chunks in a shared environment
#'   \item Adds `eval = FALSE` to chunks that fail to execute
#'   \item Optionally wraps bare file paths with `here::here()`
#'   \item Optionally adds student folder name as heading
#'   \item Creates backups before modification
#'   \item Adds transparency comments explaining all modifications
#' }
#'
#' Successfully executed chunks remain unchanged to preserve student work.
#'
#' @param input_rmd Character string. Path to the input R Markdown file.
#' @param output_rmd Character string or NULL. Path for the output file.
#'   If NULL (default), appends "_FIXED" before the .Rmd extension.
#' @param backup Logical. If TRUE (default), creates a backup file with .bak extension.
#' @param fix_paths Logical. If TRUE (default), wraps bare filenames in import
#'   functions with `here::here()`. The 'here' package is required.
#' @param data_folder Character string. Subfolder name for data files when using
#'   `fix_paths = TRUE`. Default is "data". Special values:
#'   - ".": Data files are at project root
#'   - "..": Data files are in parent directory
#'   - "auto": Automatically detect if data files are in parent directory
#' @param add_student_info Logical. If TRUE, adds the parent folder name (student
#'   identifier) as a numbered heading at the beginning of the document. Useful
#'   when students forget to include their name. Default is FALSE.
#' @param limit_output Logical. If TRUE (default), injects global setup code to
#'   prevent massive data dumps by setting appropriate pander options and output limits.
#'   The setup code is added to existing setup chunks or creates a new setup chunk.
#' @param max_print_lines Integer. This parameter is deprecated and ignored.
#'   Output limiting is now handled through global setup code injection.
#' @param quiet Logical. If TRUE, suppresses progress messages. Default is FALSE.
#'
#' @return Invisibly returns the path to the output file.
#'
#' @examples
#' \dontrun{
#' # Fix a single file
#' fix_rmd("student_submission.Rmd")
#'
#' # Add student folder name as heading
#' fix_rmd("Smith_John_12345/homework.Rmd", add_student_info = TRUE)
#'
#' # Specify custom output location
#' fix_rmd("homework.Rmd", output_rmd = "homework_corrected.Rmd")
#'
#' # Disable path fixing if not needed
#' fix_rmd("project.Rmd", fix_paths = FALSE)
#'
#' # Use custom data folder
#' fix_rmd("analysis.Rmd", data_folder = "raw_data")
#' }
#'
#' @import here
#' @import pander
#' @import rmarkdown
#' @export
fix_rmd <- function(input_rmd,
                    output_rmd = NULL,
                    backup = TRUE,
                    fix_paths = TRUE,
                    data_folder = "data",
                    add_student_info = FALSE,
                    limit_output = TRUE,
                    max_print_lines = 100,  # deprecated parameter kept for compatibility
                    quiet = FALSE) {

  # Validate input file exists
  if (!file.exists(input_rmd)) {
    stop("Input file does not exist: ", input_rmd, call. = FALSE)
  }

  # Validate input is an Rmd file
  if (!grepl("\\.Rmd$", input_rmd, ignore.case = TRUE)) {
    stop("Input file must be an R Markdown (.Rmd) file", call. = FALSE)
  }

  # Set output path if not provided
  if (is.null(output_rmd)) {
    output_rmd <- sub("\\.Rmd$", "_FIXED.Rmd", input_rmd, ignore.case = TRUE)
  }

  # Create backup if requested
  if (backup) {
    backup_path <- paste0(input_rmd, ".bak")
    file.copy(input_rmd, backup_path, overwrite = TRUE)
    if (!quiet) {
      message("Backup created: ", backup_path)
    }
  }

  # Read input file
  lines <- readLines(input_rmd, encoding = "UTF-8", warn = FALSE)

  # Auto-detect data folder if requested
  if (fix_paths && data_folder == "auto") {
    detected_folder <- auto_detect_data_folder(lines, input_rmd)
    data_folder <- detected_folder
    if (!quiet && detected_folder == "..") {
      message("Auto-detected: data files are in parent directory")
    }
  }

  output_lines <- character()

  # Extract student info from folder name if requested
  student_info <- NULL
  if (add_student_info) {
    folder_name <- basename(dirname(normalizePath(input_rmd, mustWork = FALSE)))
    if (folder_name != ".") {
      student_info <- folder_name
    }
  }

  # State variables for parsing
  in_r_chunk <- FALSE
  current_chunk <- character()
  chunk_counter <- 0
  in_yaml <- FALSE
  yaml_end_line <- 0

  # Persistent environment for sequential chunk evaluation
  eval_env <- new.env(parent = globalenv())

  # First pass: find end of YAML header
  if (add_student_info && !is.null(student_info)) {
    yaml_delimiter_count <- 0
    for (j in seq_along(lines)) {
      if (grepl("^---\\s*$", lines[j])) {
        yaml_delimiter_count <- yaml_delimiter_count + 1
        if (yaml_delimiter_count == 2) {
          yaml_end_line <- j
          break
        }
      }
    }
  }

  # Inject setup code BEFORE processing chunks if requested
  # This must happen before chunk processing to avoid renumbering chunks
  if (limit_output) {
    lines <- inject_setup_code(lines)
    # Adjust yaml_end_line if we inserted a setup chunk
    # (inject_setup_code inserts after YAML, so yaml_end_line doesn't change)
  }

  # Process line by line
  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Insert student info heading after YAML if requested
    if (add_student_info && !is.null(student_info) && i == yaml_end_line && yaml_end_line > 0) {
      output_lines <- c(output_lines, line)
      output_lines <- c(output_lines, "")
      output_lines <- c(output_lines, paste0("# ", student_info))
      output_lines <- c(output_lines, "")
      output_lines <- c(output_lines, paste0(
        "<!-- Student folder name added by fixrmdsubmissions package for identification -->"
      ))
      i <- i + 1
      next
    }

    # Start of R code chunk
    if (grepl("^\\s*```+\\s*\\{\\s*r[ ,\\}]", line, ignore.case = TRUE)) {
      in_r_chunk <- TRUE
      chunk_counter <- chunk_counter + 1
      current_chunk <- line

      # If chunk already has eval = FALSE, copy as-is but still fix paths
      if (grepl("\\beval\\s*=\\s*FALSE\\b", line, ignore.case = TRUE)) {
        output_lines <- c(output_lines, line)
        i <- i + 1

        # Copy chunk body with path fixes
        while (i <= length(lines) && !grepl("^\\s*```+\\s*$", lines[i])) {
          l_original <- lines[i]
          l <- l_original
          if (fix_paths) {
            l <- fix_paths_in_line(l, data_folder)
            # Add transparency comment if line was modified
            if (l != l_original && !grepl("^\\s*#", l_original)) {
              output_lines <- c(output_lines, paste0(
                "# [fixrmdsubmissions] Path fixed to use here::here() for portability"
              ))
            }
          }
          output_lines <- c(output_lines, l)
          i <- i + 1
        }

        # Copy closing fence
        if (i <= length(lines) && grepl("^\\s*```+\\s*$", lines[i])) {
          output_lines <- c(output_lines, lines[i])
        }

        in_r_chunk <- FALSE
        i <- i + 1
        next
      }

    # End of R code chunk
    } else if (in_r_chunk && grepl("^\\s*```+\\s*$", line)) {
      current_chunk <- c(current_chunk, line)

      # Extract code body (everything except first and last line)
      code_body <- current_chunk[-c(1, length(current_chunk))]
      code_raw <- paste(code_body, collapse = "\n")
      code_clean <- trimws(code_raw)

      failed <- FALSE

      # Only evaluate non-empty chunks
      if (nzchar(code_clean)) {
        if (!quiet) {
          cat(sprintf("Chunk %2d (line ~%d) ... ", chunk_counter, i - length(code_body)),
              appendLF = FALSE)
        }

        result <- tryCatch(
          {
            suppressWarnings({
              eval(parse(text = code_clean), envir = eval_env)
            })
            NULL
          },
          error = function(e) e
        )

        if (inherits(result, "error")) {
          failed <- TRUE
          if (!quiet) {
            cat(" FAILED\n")
            cat("   Error: ", result$message, "\n", sep = "")
          }
        } else {
          if (!quiet) {
            cat(" OK\n")
          }
        }
      }

      # Add eval = FALSE if chunk failed
      error_message <- NULL
      if (failed) {
        header <- current_chunk[1]
        error_message <- result$message

        # Try to intelligently add eval = FALSE to the chunk header
        new_header <- sub(
          "^(\\s*```+\\s*\\{\\s*r)([,\\s\\}])",
          "\\1, eval = FALSE\\2",
          header,
          perl = TRUE
        )

        # Fallback if above pattern didn't match
        if (!grepl("eval", new_header)) {
          new_header <- sub("\\{\\s*r", "{r, eval = FALSE", header)
        }

        current_chunk[1] <- new_header

        if (!quiet) {
          cat("   -> marked as eval = FALSE\n")
        }
      }

      # Fix paths in code body if requested
      original_code_body <- code_body
      if (fix_paths) {
        code_body <- vapply(
          code_body,
          fix_paths_in_line,
          character(1),
          data_folder = data_folder,
          USE.NAMES = FALSE
        )
      }

      # Add transparency comments
      chunk_output <- current_chunk[1]

      # Add comment if chunk execution was disabled
      if (failed && !is.null(error_message)) {
        chunk_output <- c(chunk_output, paste0(
          "# [fixrmdsubmissions] Chunk execution disabled due to error: ",
          substr(error_message, 1, 80)
        ))
      }

      # Add transparency comments for path fixes
      if (fix_paths) {
        for (j in seq_along(code_body)) {
          if (code_body[j] != original_code_body[j] &&
              !grepl("^\\s*#", original_code_body[j])) {
            chunk_output <- c(chunk_output, paste0(
              "# [fixrmdsubmissions] Path fixed to use here::here() for portability"
            ))
          }
          chunk_output <- c(chunk_output, code_body[j])
        }
      } else {
        chunk_output <- c(chunk_output, code_body)
      }

      # Write chunk to output
      output_lines <- c(output_lines, chunk_output, line)

      in_r_chunk <- FALSE
      current_chunk <- character()

    # Inside R chunk (accumulate)
    } else if (in_r_chunk) {
      current_chunk <- c(current_chunk, line)

    # Outside R chunk
    } else {
      output_lines <- c(output_lines, line)
    }

    i <- i + 1
  }

  # Write output file
  writeLines(output_lines, output_rmd, useBytes = TRUE)

  # Summary statistics
  n_failed <- sum(grepl(
    "\\beval\\s*=\\s*FALSE\\b",
    output_lines[grepl("^\\s*```+\\{\\s*r", output_lines)]
  ))

  if (!quiet) {
    cat("\nFinished!\n")
    cat("   Output -> ", output_rmd, "\n")
    cat("   ", n_failed, " chunk(s) disabled with eval = FALSE\n", sep = "")
    if (fix_paths) {
      cat("   Bare file paths converted to here::here(\"", data_folder, "\", ...)\n", sep = "")
    }
    if (limit_output) {
      cat("   Global setup code injected for output management\n")
    }
  }

  invisible(output_rmd)
}
