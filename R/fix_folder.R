#' Fix all R Markdown files in a folder
#'
#' @description
#' Batch processes all R Markdown files in a directory (optionally recursive).
#' Designed for processing entire folders of student submissions efficiently.
#' Each file is processed with `fix_rmd()` and saved as `*_FIXED.Rmd` in the
#' same location as the original.
#'
#' @param path Character string. Path to the folder containing R Markdown files.
#'   Default is "submissions".
#' @param pattern Character string. Regular expression pattern to match files.
#'   Default is "\\\\.Rmd$" (all .Rmd files).
#' @param recursive Logical. If TRUE (default), searches subdirectories recursively.
#' @param fix_paths Logical. If TRUE (default), wraps bare filenames with
#'   `here::here()`. The 'here' package is required.
#' @param data_folder Character string. Subfolder name for data files when using
#'   `fix_paths = TRUE`. Default is "data".
#' @param add_student_info Logical. If TRUE, adds the parent folder name (student
#'   identifier) as a numbered heading at the beginning of each document. Useful
#'   when students forget to include their name. Default is FALSE.
#' @param limit_output Logical. If TRUE (default), injects global setup code to
#'   prevent massive data dumps. Passed to `fix_rmd()`.
#' @param max_print_lines Integer. This parameter is deprecated and ignored.
#'   Kept for compatibility. Passed to `fix_rmd()`.
#' @param quiet Logical. If TRUE, suppresses individual file progress messages.
#'   Summary is still printed. Default is FALSE.
#'
#' @return Invisibly returns a character vector of output file paths.
#'
#' @examples
#' \dontrun{
#' # Fix all Rmd files in a submissions folder
#' fix_folder("submissions")
#'
#' # Add student folder names as headings
#' fix_folder("submissions", add_student_info = TRUE)
#'
#' # Fix non-recursively (only top-level folder)
#' fix_folder("homework", recursive = FALSE)
#'
#' # Custom data folder
#' fix_folder("projects", data_folder = "raw_data")
#'
#' # Disable path fixing
#' fix_folder("assignments", fix_paths = FALSE)
#'
#' # Only show summary, not individual file progress
#' fix_folder("tests", quiet = TRUE)
#' }
#'
#' @export
fix_folder <- function(path = "submissions",
                       pattern = "\\.Rmd$",
                       recursive = TRUE,
                       fix_paths = TRUE,
                       data_folder = "data",
                       add_student_info = FALSE,
                       limit_output = TRUE,
                       max_print_lines = 100,  # deprecated parameter kept for compatibility
                       quiet = FALSE) {

  # Validate folder exists
  if (!dir.exists(path)) {
    stop("Directory does not exist: ", path, call. = FALSE)
  }

  # Find all matching files
  files <- list.files(
    path = path,
    pattern = pattern,
    full.names = TRUE,
    recursive = recursive,
    ignore.case = TRUE
  )

  if (length(files) == 0) {
    message("No R Markdown files found in: ", path)
    return(invisible(character(0)))
  }

  message("Found ", length(files), " R Markdown file(s) in: ", path)
  message("Starting repair...\n")

  output_paths <- character(length(files))
  success_count <- 0
  error_count <- 0

  # Process each file
  for (i in seq_along(files)) {
    file_path <- files[i]
    file_name <- basename(file_path)

    if (!quiet) {
      cat("\n")
      cat(strrep("=", 70), "\n")
      cat("Processing [", i, "/", length(files), "]: ", file_name, "\n", sep = "")
      cat(strrep("=", 70), "\n")
    } else {
      cat("Processing [", i, "/", length(files), "]: ", file_name, " ... ",
          sep = "", appendLF = FALSE)
    }

    # Try to fix the file
    result <- tryCatch(
      {
        output_path <- fix_rmd(
          input_rmd = file_path,
          output_rmd = NULL,  # Will auto-generate _FIXED.Rmd name
          backup = TRUE,
          fix_paths = fix_paths,
          data_folder = data_folder,
          add_student_info = add_student_info,
          limit_output = limit_output,
          max_print_lines = max_print_lines,
          quiet = quiet
        )
        success_count <- success_count + 1
        output_paths[i] <- output_path

        if (quiet) {
          cat("Done\n")
        }

        list(success = TRUE, output = output_path)
      },
      error = function(e) {
        error_count <- error_count + 1

        if (quiet) {
          cat("ERROR\n")
        }
        cat("\n   ERROR: ", e$message, "\n", sep = "")

        list(success = FALSE, error = e$message)
      }
    )
  }

  # Print summary
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("SUMMARY\n")
  cat(strrep("=", 70), "\n")
  cat("Total files processed: ", length(files), "\n")
  cat("Successful: ", success_count, "\n")
  cat("Errors: ", error_count, "\n")

  if (success_count > 0) {
    cat("\nFixed files saved with '_FIXED.Rmd' suffix in original locations.\n")
    cat("Backups saved with '.bak' extension.\n")
  }

  invisible(output_paths[output_paths != ""])
}
