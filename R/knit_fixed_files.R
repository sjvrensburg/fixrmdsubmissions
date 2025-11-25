#' Knit all fixed R Markdown files in a folder
#'
#' @description
#' Batch knits all fixed R Markdown files (files ending in `_FIXED.Rmd`) in a
#' directory. Each file is knitted according to its YAML header output format,
#' which means custom templates and output formats are automatically respected.
#'
#' This is typically used after running `fix_folder()` to generate final output
#' documents (HTML, PDF, Word, etc.) for all student submissions.
#'
#' @param path Character string. Path to the folder containing fixed R Markdown files.
#'   Default is current directory (".").
#' @param pattern Character string. Pattern to match fixed files. Default is
#'   "_FIXED\\\\.Rmd$" to match all files ending in _FIXED.Rmd.
#' @param recursive Logical. If TRUE (default), searches subdirectories recursively.
#' @param output_dir Character string or NULL. Directory where output files should
#'   be saved. If NULL (default), output files are saved in the same directory as
#'   the source .Rmd file. Use this to collect all outputs in one location.
#' @param quiet Logical. If TRUE, suppresses individual file progress messages
#'   from rmarkdown::render(). Summary is still printed. Default is FALSE.
#' @param clean Logical. If TRUE (default), intermediate files generated during
#'   knitting are removed after successful render.
#'
#' @return Invisibly returns a data frame with columns:
#'   \itemize{
#'     \item file: Input file path
#'     \item output: Output file path (or NA if failed)
#'     \item success: Logical indicating if knitting succeeded
#'     \item error: Error message (or NA if succeeded)
#'   }
#'
#' @examples
#' \dontrun{
#' # After fixing submissions, knit them all
#' fix_folder("submissions")
#' knit_fixed_files("submissions")
#'
#' # Collect all outputs in one folder
#' knit_fixed_files("submissions", output_dir = "knitted_submissions")
#'
#' # Quiet mode (only show summary)
#' knit_fixed_files("submissions", quiet = TRUE)
#'
#' # Complete workflow
#' fix_folder("submissions", add_student_info = TRUE)
#' results <- knit_fixed_files("submissions")
#' View(results)  # See which files succeeded/failed
#' }
#'
#' @export
knit_fixed_files <- function(path = ".",
                              pattern = "_FIXED\\.Rmd$",
                              recursive = TRUE,
                              output_dir = NULL,
                              quiet = FALSE,
                              clean = TRUE) {

  # Validate folder exists
  if (!dir.exists(path)) {
    stop("Directory does not exist: ", path, call. = FALSE)
  }

  # Validate output_dir if provided
  if (!is.null(output_dir) && !dir.exists(output_dir)) {
    message("Creating output directory: ", output_dir)
    dir.create(output_dir, recursive = TRUE)
  }

  # Check if rmarkdown is available
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop(
      "The 'rmarkdown' package is required for knitting but is not installed.\n",
      "Install it with: install.packages(\"rmarkdown\")",
      call. = FALSE
    )
  }

  # Find all fixed files
  files <- list.files(
    path = path,
    pattern = pattern,
    full.names = TRUE,
    recursive = recursive,
    ignore.case = TRUE
  )

  # Filter to only knit the first _FIXED version, not re-processed ones
  # (matches _FIXED.Rmd but not _FIXED_FIXED.Rmd, _FIXED_FIXED_FIXED.Rmd, etc.)
  files <- files[!grepl("_FIXED_FIXED", files, ignore.case = TRUE)]

  if (length(files) == 0) {
    message("No fixed R Markdown files found matching pattern: ", pattern)
    return(invisible(data.frame(
      file = character(0),
      output = character(0),
      success = logical(0),
      error = character(0),
      stringsAsFactors = FALSE
    )))
  }

  message("Found ", length(files), " fixed R Markdown file(s) to knit")
  message("Starting knitting process...\n")

  # Results tracking
  results <- data.frame(
    file = files,
    output = rep(NA_character_, length(files)),
    success = rep(FALSE, length(files)),
    error = rep(NA_character_, length(files)),
    stringsAsFactors = FALSE
  )

  success_count <- 0
  error_count <- 0

  # Process each file
  for (i in seq_along(files)) {
    file_path <- files[i]
    file_name <- basename(file_path)

    if (!quiet) {
      cat("\n")
      cat(strrep("=", 70), "\n")
      cat("Knitting [", i, "/", length(files), "]: ", file_name, "\n", sep = "")
      cat(strrep("=", 70), "\n")
    } else {
      cat("Knitting [", i, "/", length(files), "]: ", file_name, " ... ",
          sep = "", appendLF = FALSE)
    }

    # Determine output file location
    output_file <- NULL
    render_output_dir <- NULL
    if (!is.null(output_dir)) {
      # Extract base name without _FIXED.Rmd
      base_name <- sub("_FIXED\\.Rmd$", "", basename(file_path), ignore.case = TRUE)
      # Get parent folder name for disambiguation
      parent_folder <- basename(dirname(file_path))
      # Create unique output name (just the filename, not full path)
      output_file <- paste0(parent_folder, "_", base_name)
      render_output_dir <- output_dir
    }

    # Try to knit the file
    result <- tryCatch(
      {
        # Render using YAML settings (no output_format specified)
        output_path <- rmarkdown::render(
          input = file_path,
          output_file = output_file,
          output_dir = render_output_dir,
          quiet = quiet,
          clean = clean,
          envir = new.env()  # Fresh environment for each file
        )

        if (quiet) {
          cat("Done\n")
        } else {
          cat("\n\u2713 Success! Output: ", basename(output_path), "\n", sep = "")
        }

        list(success = TRUE, output = output_path, error = NULL)
      },
      error = function(e) {
        if (quiet) {
          cat("ERROR\n")
        } else {
          cat("\n\u2717 Error: ", e$message, "\n", sep = "")
        }

        list(success = FALSE, output = NULL, error = e$message)
      }
    )

    # Update results based on what was returned
    if (result$success) {
      success_count <- success_count + 1
      results$output[i] <- result$output
      results$success[i] <- TRUE
    } else {
      error_count <- error_count + 1
      results$error[i] <- result$error
    }
  }

  # Print summary
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("KNITTING SUMMARY\n")
  cat(strrep("=", 70), "\n")
  cat("Total files processed: ", length(files), "\n")
  cat("Successfully knitted: ", success_count, " (",
      round(success_count / length(files) * 100, 1), "%)\n", sep = "")
  cat("Errors: ", error_count, "\n")

  if (error_count > 0) {
    cat("\nFiles with errors:\n")
    failed_files <- results$file[!results$success]
    for (f in failed_files) {
      cat("  - ", basename(dirname(f)), "/", basename(f), "\n", sep = "")
    }
  }

  if (!is.null(output_dir) && success_count > 0) {
    cat("\nOutput files saved to: ", normalizePath(output_dir), "\n", sep = "")
  }

  invisible(results)
}
