#!/usr/bin/env Rscript

# Comprehensive Demo Script for fixrmdsubmissions Package
# 
# This script demonstrates all package features by processing example problematic files
# and showing before/after comparisons.

suppressPackageStartupMessages({
  library(fixrmdsubmissions)
  library(dplyr)
  library(readr)
})

# Create demo directory
demo_dir <- "comprehensive_demo"
if (!dir.exists(demo_dir)) {
  dir.create(demo_dir)
}

cat("🚀 COMPREHENSIVE DEMO: fixrmdsubmissions Package Features\n")
cat(strrep("=", 60), "\n\n")

# Step 1: Copy example files to demo directory
cat("📁 STEP 1: Setting up demo files...\n")
example_files <- list.files(
  system.file("extdata", package = "fixrmdsubmissions"),
  pattern = "^demo_.*\\.Rmd$",
  full.names = TRUE
)

# Copy files to demo directory and data files
demo_files <- c()
for (file in example_files) {
  dest_file <- file.path(demo_dir, basename(file))
  file.copy(file, dest_file, overwrite = TRUE)
  demo_files <- c(demo_files, dest_file)
  cat("   ✅ Copied:", basename(file), "\n")
}

# Also copy data files
data_files <- list.files(
  system.file("extdata", package = "fixrmdsubmissions"),
  pattern = "\\.csv$",
  full.names = TRUE
)

for (data_file in data_files) {
  dest_file <- file.path(demo_dir, basename(data_file))
  file.copy(data_file, dest_file, overwrite = TRUE)
  cat("   ✅ Copied data:", basename(data_file), "\n")
}

# Create .here file
writeLines("here root", file.path(demo_dir, ".here"))
cat("   ✅ Created .here file for path fixing\n\n")

# Step 2: Analyze original files
cat("📊 STEP 2: Analyzing original files...\n")

original_stats <- data.frame(
  file = character(),
  chunks = integer(),
  r_chunks = integer(),
  lines = integer(),
  stringsAsFactors = FALSE
)

for (file in demo_files) {
  content <- readLines(file, warn = FALSE)
  chunk_count <- sum(grepl("```", content))
  r_chunk_count <- sum(grepl("```\\{r", content, ignore.case = TRUE))
  
  original_stats <- rbind(original_stats, data.frame(
    file = basename(file),
    chunks = chunk_count,
    r_chunks = r_chunk_count,
    lines = length(content),
    stringsAsFactors = FALSE
  ))
}

cat("📈 Original file analysis:\n")
for (i in 1:nrow(original_stats)) {
  cat(sprintf("   %-30s | %3d chunks | %3d R chunks | %4d lines\n",
              original_stats$file[i],
              original_stats$chunks[i],
              original_stats$r_chunks[i],
              original_stats$lines[i]))
}
cat("\n")

# Step 3: Fix all files with all features enabled
cat("🔧 STEP 3: Fixing files with all features enabled...\n")
cat("   Features: Path fixing + Output limiting + Backups + Transparency\n\n")

setwd(demo_dir)
results <- fix_folder(
  path = ".",
  pattern = "demo_.*\\.Rmd$",
  recursive = FALSE,
  fix_paths = TRUE,
  data_folder = ".",
  add_student_info = FALSE,  # Don't add folder names for demo
  limit_output = TRUE,
  quiet = FALSE
)

# Step 4: Analyze fixed files
cat("\n📊 STEP 4: Analyzing fixed files...\n")

fixed_stats <- data.frame(
  file = character(),
  chunks = integer(),
  r_chunks = integer(),
  lines = integer(),
  eval_false_chunks = integer(),
  here_calls = integer(),
  setup_code = integer(),
  stringsAsFactors = FALSE
)

for (file in results) {
  content <- readLines(file, warn = FALSE)
  chunk_count <- sum(grepl("```", content))
  r_chunk_count <- sum(grepl("```\\{r", content, ignore.case = TRUE))
  eval_false_count <- sum(grepl("eval\\s*=\\s*FALSE", content, ignore.case = TRUE))
  here_call_count <- sum(grepl("here::here", content))
  setup_code_count <- sum(grepl("Global options to prevent massive data dumps", content))
  
  fixed_stats <- rbind(fixed_stats, data.frame(
    file = basename(file),
    chunks = chunk_count,
    r_chunks = r_chunk_count,
    lines = length(content),
    eval_false_chunks = eval_false_count,
    here_calls = here_call_count,
    setup_code = setup_code_count,
    stringsAsFactors = FALSE
  ))
}

cat("📈 Fixed file analysis:\n")
for (i in 1:nrow(fixed_stats)) {
  cat(sprintf("   %-30s | %3d chunks | %3d eval=FALSE | %2d here calls | %s\n",
              fixed_stats$file[i],
              fixed_stats$chunks[i],
              fixed_stats$eval_false_chunks[i],
              fixed_stats$here_calls[i],
              if (fixed_stats$setup_code[i] > 0) "✅ setup" else "❌ no setup"))
}

# Step 5: Show specific examples of fixes
cat("\n🔍 STEP 5: Showing examples of fixes...\n")

# Show path fixing examples
cat("\n📍 PATH FIXING EXAMPLES:\n")
for (file in results) {
  content <- readLines(file)
  here_lines <- content[grepl("here::here", content)]
  if (length(here_lines) > 0) {
    cat("\nFile:", basename(file), "\n")
    for (i in 1:min(3, length(here_lines))) {
      # Remove transparent comments to show just the fix
      fixed_line <- sub("#.*fixrmdsubmissions.*", "", here_lines[i])
      cat("   Fixed:", trimws(fixed_line), "\n")
    }
  }
}

# Show eval=FALSE examples
cat("\n❌ CHUNK DISABLED EXAMPLES:\n")
for (file in results) {
  content <- readLines(file)
  chunk_headers <- content[grepl("```\\{r.*eval\\s*=\\s*FALSE", content, ignore.case = TRUE)]
  if (length(chunk_headers) > 0) {
    cat("\nFile:", basename(file), "\n")
    for (i in 1:min(2, length(chunk_headers))) {
      cat("   Disabled:", trimws(chunk_headers[i]), "\n")
    }
  }
}

# Show setup code injection
cat("\n⚙️  OUTPUT LIMITING SETUP CODE:\n")
setup_files <- results[grepl("demo_broken_submission_FIXED.Rmd|demo_more_issues_FIXED.Rmd", basename(results))]
for (file in setup_files) {
  if (file.exists(file)) {
    content <- readLines(file)
    setup_start <- grep("Global options to prevent massive data dumps", content)
    if (length(setup_start) > 0) {
      cat("\nFile:", basename(file), "\n")
      # Show a few lines of setup code
      start_line <- setup_start[1]
      for (i in start_line:min(start_line + 3, length(content))) {
        cat("   ", content[i], "\n")
      }
    }
  }
}

# Step 6: Summary
cat("\n📋 STEP 6: Comprehensive Summary\n")
cat(strrep("-", 60), "\n")

total_original_chunks <- sum(original_stats$chunks)
total_fixed_chunks <- sum(fixed_stats$chunks)
total_eval_disabled <- sum(fixed_stats$eval_false_chunks)
total_here_calls <- sum(fixed_stats$here_calls)
files_with_setup <- sum(fixed_stats$setup_code > 0)

cat("📊 PROCESSING SUMMARY:\n")
cat(sprintf("   Files processed: %d\n", length(results)))
cat(sprintf("   Original chunks: %d → Fixed chunks: %d\n", total_original_chunks, total_fixed_chunks))
cat(sprintf("   Chunks disabled: %d (%.1f%%)\n", total_eval_disabled, 
            100 * total_eval_disabled / total_fixed_chunks))
cat(sprintf("   Path fixes: %d here::here() calls added\n", total_here_calls))
cat(sprintf("   Output limiting: %d files received setup code\n", files_with_setup))
cat(sprintf("   Backups created: %d .bak files\n", sum(file.exists(paste0(demo_files, ".bak")))))

cat("\n🎯 FEATURES DEMONSTRATED:\n")
cat("   ✅ Sequential chunk evaluation with error detection\n")
cat("   ✅ Automatic eval = FALSE for failing chunks\n") 
cat("   ✅ Intelligent path fixing with here::here() conversion\n")
cat("   ✅ Global output limiting with setup code injection\n")
cat("   ✅ Academic transparency with modification comments\n")
cat("   ✅ Backup creation for original file preservation\n")
cat("   ✅ Batch processing with detailed progress reporting\n")

cat("\n📂 FILES CREATED IN '", demo_dir, "/':\n")
cat("   📝 Original R Markdown files with various issues\n")
cat("   🔧 Fixed R Markdown files with '_FIXED' suffix\n")
cat("   💾 Backup files with '.bak' extension\n")
cat("   📊 Sample data files for path fixing demonstration\n")
cat("   📍 .here file for project root marking\n")

cat("\n🚀 NEXT STEPS:\n")
cat("   1. Review the fixed files to see modifications\n")
cat("   2. Try knitting the fixed files (if you have R Markdown)\n")
cat("   3. Compare .bak and _FIXED files to understand changes\n")
cat("   4. Use the package on your own student submissions!\n")

cat(strrep("=", 60), "\n")
cat("🎉 Demo completed successfully! All package features demonstrated.\n")
cat("📚 For more info, see: help(fix_rmd) and help(fix_folder)\n")