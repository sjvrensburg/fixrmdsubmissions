#' Fix and knit all R Markdown files in a folder (combined workflow)
#'
#' @description
#' Convenience function that combines fixing and knitting into a single step.
#' This is the recommended workflow for batch processing student submissions:
#'
#' 1. **Fix phase**: Repairs broken file paths, disables failing code chunks, and
#'    limits output (via `fix_folder()`)
#' 2. **Knit phase**: Converts fixed `.Rmd` files to their final output format
#'    (via `knit_fixed_files()`)
#'
#' This is equivalent to running `fix_folder()` followed by `knit_fixed_files()`,
#' but with a cleaner interface and unified progress reporting.
#'
#' @param path Character string. Path to the folder containing R Markdown files.
#'   Default is current directory (".").
#' @param pattern Character string. Pattern to match source files. Default is
#'   "\\\\.Rmd$" to match all R Markdown files.
#' @param recursive Logical. If TRUE (default), searches subdirectories recursively.
#' @param fix_paths Logical. Replace bare file paths with absolute paths using
#'   filename-to-path mapping (default TRUE).
#' @param data_folder Character string. Which directories to search for data files.
#'   Default is "auto" which searches both parent directory and current directory.
#'   Use "." to search only current directory, ".." for only parent directory,
#'   or "data" (or other name) for a specific subdirectory.
#' @param add_student_info Logical. Add parent folder name as numbered heading
#'   (default TRUE). Useful when students forget to include their names.
#' @param limit_output Logical. Inject global setup code to limit console output
#'   (default TRUE). Prevents massive data dumps from making documents unreadable.
#' @param output_dir Character string or NULL. Directory where final knitted output
#'   files should be saved. Default is "fixed". If NULL, output files are saved in
#'   the same directory as the source .Rmd file. Use this to collect all outputs in
#'   one location for easier grading.
#' @param knit_quiet Logical. If TRUE, suppresses individual file progress messages
#'   from rmarkdown::render(). Summary is still printed. Default is FALSE.
#' @param clean Logical. If TRUE (default), intermediate files generated during
#'   knitting are removed after successful render.
#' @param quiet Logical. If TRUE, suppresses progress messages during fixing phase.
#'   Default is FALSE.
#'
#' @return Invisibly returns a list with two data frames:
#'   \itemize{
#'     \item `fix_results`: Results from `fix_folder()` with columns:
#'       \itemize{
#'         \item file: Input file path
#'         \item success: Logical indicating if fixing succeeded
#'         \item n_fixed_chunks: Number of chunks with eval = FALSE
#'         \item n_path_fixes: Number of file paths converted
#'       }
#'     \item `knit_results`: Results from `knit_fixed_files()` with columns:
#'       \itemize{
#'         \item file: Input file path
#'         \item output: Output file path (or NA if failed)
#'         \item success: Logical indicating if knitting succeeded
#'         \item error: Error message (or NA if succeeded)
#'       }
#'   }
#'
#' @seealso
#' - `fix_folder()` for fixing without knitting
#' - `knit_fixed_files()` for knitting already-fixed files
#' - `fix_rmd()` for fixing a single file
#'
#' @examples
#' \dontrun{
#' # Complete workflow: Fix and knit all submissions in one call
#' fix_and_knit_folder("~/submissions")
#'
#' # With all options
#' results <- fix_and_knit_folder(
#'   path = "submissions",
#'   recursive = TRUE,
#'   fix_paths = TRUE,
#'   data_folder = ".",
#'   add_student_info = TRUE,
#'   limit_output = TRUE,
#'   output_dir = "graded_submissions",
#'   quiet = FALSE
#' )
#'
#' # Collect all outputs in one folder for easier distribution
#' fix_and_knit_folder(
#'   path = "submissions",
#'   output_dir = "final_graded_work"
#' )
#'
#' # Quiet mode for less verbose output
#' results <- fix_and_knit_folder("submissions", quiet = TRUE, knit_quiet = TRUE)
#'
#' # See which files failed
#' View(results$knit_results[!results$knit_results$success, ])
#'
#' # See how many chunks were disabled per file
#' View(results$fix_results)
#' }
#'
#' @export
fix_and_knit_folder <- function(path = ".",
                                pattern = "\\.Rmd$",
                                recursive = TRUE,
                                fix_paths = TRUE,
                                data_folder = "auto",
                                add_student_info = TRUE,
                                limit_output = TRUE,
                                output_dir = "fixed",
                                knit_quiet = FALSE,
                                clean = TRUE,
                                quiet = FALSE) {

  # Validate path exists
  if (!dir.exists(path)) {
    stop("Directory does not exist: ", path, call. = FALSE)
  }

  # Create output directory if specified and doesn't exist
  if (!is.null(output_dir) && !dir.exists(output_dir)) {
    if (!quiet) {
      message("Creating output directory: ", output_dir)
    }
    dir.create(output_dir, recursive = TRUE)
  }

  # Phase 1: Fix all files
  if (!quiet) {
    cat("\n")
    cat(strrep("=", 70), "\n")
    cat("PHASE 1: FIXING R MARKDOWN FILES\n")
    cat(strrep("=", 70), "\n\n")
  }

  fix_results <- fix_folder(
    path = path,
    pattern = pattern,
    recursive = recursive,
    fix_paths = fix_paths,
    data_folder = data_folder,
    add_student_info = add_student_info,
    limit_output = limit_output,
    quiet = quiet
  )

  if (!quiet) {
    cat("\n")
  }

  # Phase 2: Knit all fixed files
  if (!quiet) {
    cat(strrep("=", 70), "\n")
    cat("PHASE 2: KNITTING FIXED R MARKDOWN FILES\n")
    cat(strrep("=", 70), "\n\n")
  }

  knit_results <- knit_fixed_files(
    path = path,
    pattern = "_FIXED\\.Rmd$",
    recursive = recursive,
    output_dir = output_dir,
    quiet = knit_quiet,
    clean = clean
  )

  # Combined summary
  if (!quiet) {
    cat("\n")
    cat(strrep("=", 70), "\n")
    cat("COMBINED WORKFLOW SUMMARY\n")
    cat(strrep("=", 70), "\n")
    cat("Fixing phase:  ", nrow(fix_results), " files processed\n")
    cat("Knitting phase: ", nrow(knit_results), " files processed\n")

    if (nrow(knit_results) > 0) {
      success_count <- sum(knit_results$success)
      error_count <- nrow(knit_results) - success_count
      cat("\nFinal Results:\n")
      cat("  Successfully knitted: ", success_count, " (",
          round(success_count / nrow(knit_results) * 100, 1), "%)\n", sep = "")
      cat("  Errors: ", error_count, "\n")

      if (!is.null(output_dir) && success_count > 0) {
        cat("\nAll outputs saved to: ", normalizePath(output_dir), "\n", sep = "")
      }
    }

    cat(strrep("=", 70), "\n")
  }

  # Return both results invisibly
  invisible(list(
    fix_results = fix_results,
    knit_results = knit_results
  ))
}
