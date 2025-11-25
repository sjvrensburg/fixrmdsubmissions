# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

`fixrmdsubmissions` is a fully-developed R package for instructors to automatically fix common issues in student R Markdown submissions so they can knit successfully. The package addresses typical student errors: broken file paths that only work on the student's computer, code chunks with typos or undefined functions, and massive data dumps. It's designed to batch-process hundreds of submissions efficiently.

**Status**: Mature. Core functions complete, fully tested (54 tests), roxygen2 documented, and deployed to GitHub.

## Core Functions

The package exports four main user functions and one internal utility:

### `fix_rmd()` — Fix a single R Markdown file
**Location**: `R/fix_rmd.R`

Processes one .Rmd file by:
1. Sequentially evaluating all code chunks in a shared environment
2. Adding `eval = FALSE` only to chunks that fail execution
3. Replacing bare file paths with absolute paths using filename-to-path mapping (optional)
4. Adding student folder name as heading (optional, useful when students forget their names)
5. Injecting global output-limiting code to prevent massive data dumps
6. Creating backups before any modifications
7. Adding transparency comments explaining all changes

Key parameters:
- `input_rmd`: Path to the .Rmd file to fix
- `output_rmd`: Output path (defaults to `*_FIXED.Rmd` in same directory)
- `backup`: Create `.bak` backup file (default TRUE)
- `fix_paths`: Replace bare filenames with absolute paths (default TRUE)
- `data_folder`: Which directories to search for data files (default "auto" = both parent and current directory)
- `add_student_info`: Add parent folder name as numbered heading (default TRUE)
- `limit_output`: Inject global setup code to limit console output (default TRUE)
- `quiet`: Suppress progress messages (default FALSE)

### `fix_folder()` — Batch fix all .Rmd files in a directory
**Location**: `R/fix_folder.R`

Recursively or non-recursively processes all .Rmd files in a folder using `fix_rmd()`. Each fixed file is saved as `*_FIXED.Rmd` in its original location.

Key parameters:
- `path`: Directory containing .Rmd files
- `pattern`: Regex to match files (default `"\\.Rmd$"`)
- `recursive`: Search subdirectories (default TRUE)
- Other parameters passed to `fix_rmd()`: `fix_paths`, `data_folder`, `add_student_info`, `limit_output`, `quiet`

Returns invisibly: Character vector of output file paths.

### `knit_fixed_files()` — Batch knit all fixed files
**Location**: `R/knit_fixed_files.R`

After running `fix_folder()`, this knits all `*_FIXED.Rmd` files according to their YAML headers. Respects custom templates and output formats (HTML, PDF, Word, etc.). Can collect all outputs in a single directory.

Key parameters:
- `path`: Directory containing fixed files
- `pattern`: Regex to match files (default `"_FIXED\\.Rmd$"`)
- `recursive`: Search subdirectories (default TRUE)
- `output_dir`: Directory to collect outputs (NULL means same directory as source)
- `quiet`: Suppress progress from rmarkdown::render() (default FALSE)
- `clean`: Remove intermediate files after successful render (default TRUE)

Returns invisibly: Data frame with columns `file`, `output`, `success`, `error`.

### `run_demo()` — Comprehensive feature demonstration
**Location**: `R/run_demo.R`

Runs a realistic demo showing all package features: path fixing, chunk evaluation, output limiting, cascading failures, and batch processing. Creates temporary demo files for testing.

## Technical Architecture

### Path Fixing Strategy (`R/utils-paths.R`)
**Functions**: `build_path_map()`, `replace_paths_with_map()` (internal helpers, not exported)

Uses a simple filename-to-absolute-path mapping approach for maximum reliability:

**How it works:**

1. **Build Path Map** (`build_path_map()`):
   - Scans specified directories for common data files (.csv, .rds, .xlsx, etc.)
   - Creates a named list mapping filename → absolute path
   - Example: `list("fraud_transactions.csv" = "/full/path/to/fraud_transactions.csv")`

2. **Replace Paths** (`replace_paths_with_map()`):
   - Simple string replacement: any quoted occurrence of a filename gets replaced with its absolute path
   - `"fraud_transactions.csv"` → `"/full/path/to/fraud_transactions.csv"`
   - Works with paths too: `"data/fraud_transactions.csv"` → `"/full/path/to/fraud_transactions.csv"`

**Advantages of this approach:**
- **Reliable**: Absolute paths always work, regardless of working directory
- **Simple**: No complex path resolution or `here::here()` context issues
- **Transparent**: Easy to see what happened in the fixed file
- **Flexible**: Works with any directory structure

**The `data_folder` parameter** controls which directories to search:
- `"auto"` (default): Searches both parent directory and current directory
- `".."`: Only parent directory
- `"."`: Only current directory
- `"data"`: Specific subfolder relative to .Rmd file

**Recognized data file extensions:**
csv, tsv, txt, rds, RDS, rda, RData, xlsx, xls, json, xml, feather, parquet, sav, dta, sas7bdat, qs

### Chunk Evaluation Strategy
Code in `fix_rmd()` (lines 120-190 approximately):

1. **Sequential Processing**: Chunks evaluated in order with a shared `eval_env` environment. This preserves context—later chunks can use variables from earlier successful chunks.

2. **Selective Disabling**: Only chunks that fail get `eval = FALSE` added. Working code is preserved exactly as written.

3. **Error Handling**: Errors are caught, not raised. Failed chunk is marked but processing continues.

4. **Output Limiting**: If `limit_output = TRUE`, the function injects global setup code that:
   - Sets pander options to limit table output
   - Overrides `print()` and `summary()` to limit lines
   - Sets `max.print` options to prevent massive console output

Chunk pattern matching (regex): `^\\s*```\\s*\\{r[^}]*\\}` — handles variations in spacing and chunk options.

## Testing Infrastructure

**Framework**: testthat (3rd edition)
**Location**: `tests/testthat/`
**Coverage**: 54 comprehensive tests

Test organization:
- `test-fix_rmd.R`: Single-file processing (13 tests)
- `test-fix_folder.R`: Batch processing (7 tests)
- `test-paths.R`: Path fixing logic (9 tests)
- `test-realistic.R`: Complete grading workflows (6 tests)
- Other test files: Setup, utilities, edge cases

To run tests:
```r
devtools::test()        # Run all tests
devtools::test(filter = "paths")  # Run specific test file
```

## Development Commands

```r
# Load package into development environment
devtools::load_all()

# Generate documentation from roxygen2 comments
devtools::document()

# Run package checks (this includes tests)
devtools::check()

# Run only tests
devtools::test()

# Install locally
devtools::install()

# Build source package
devtools::build()

# Build binary package
devtools::build(binary = TRUE)
```

## R Package Structure

```
fixrmdsubmissions/
├── R/
│   ├── fix_rmd.R              # Single-file fixer (main function)
│   ├── fix_folder.R           # Batch fixer
│   ├── knit_fixed_files.R     # Batch knitter
│   ├── run_demo.R             # Demo/testing function
│   └── utils-paths.R          # Internal path fixing helpers
├── man/                        # Auto-generated roxygen2 documentation
├── tests/
│   └── testthat/
│       ├── test-fix_rmd.R
│       ├── test-fix_folder.R
│       ├── test-paths.R
│       ├── test-realistic.R
│       └── ...
├── inst/
│   └── extdata/               # Demo files used by run_demo()
├── DESCRIPTION                # Package metadata
├── NAMESPACE                  # Auto-generated by roxygen2
├── LICENSE.md                 # MIT license
└── README.md                  # User-facing documentation
```

## Key Design Decisions

1. **Sequential Chunk Evaluation**: Preserves context between chunks. If chunk 1 loads data, chunk 2 can use it. If chunk 3 fails, chunk 4 still has access to variables from chunks 1-2.

2. **Transparency Comments**: All automatic modifications include comments explaining what was changed and why. This maintains academic integrity—graders can see exactly what the original code was.

3. **Simple Path Fixing**: Uses filename-to-absolute-path mapping with simple string replacement. Scans specified directories for data files, creates a mapping, and replaces any quoted occurrence of those filenames with their absolute paths. This approach is reliable and transparent.

4. **Global Output Limiting**: Instead of trying to limit output per-chunk, a single global setup chunk (with pander, print, and max.print overrides) handles all output limiting. This is more reliable than chunk-specific options.

5. **Separation of Concerns**:
   - `fix_rmd()`: Low-level file processing
   - `fix_folder()`: High-level batch processing wrapper
   - `knit_fixed_files()`: Separate kitting step (intentionally decoupled from fixing)

## Dependencies

**Imports** (required):
- `here` ≥ 1.0.0 — Legacy dependency (may be removed in future version; currently unused)
- `pander` — Table formatting options when limiting output
- `rmarkdown` — Chunk parsing and knitting

**Suggests** (development only):
- `testthat` ≥ 3.0.0 — Unit testing framework
- `devtools` — Development utilities (implied)
- `roxygen2` — Documentation generation (implied)

## Privacy and Data Protection

- `real_examples/` — Contains actual student submissions with PII. **Never commit this directory.**
- `inst/extdata/` — Contains synthetic demo files (no real student data).
- Both directories are in `.gitignore`.

When testing with real submissions, use `real_examples/` locally. Use only `inst/extdata/` demo files in version control.

## Important Notes for Development

1. **Documentation**: All exported functions have roxygen2 comments (`@export`, `@param`, etc.). Run `devtools::document()` after editing these comments.

2. **Parameter Naming Consistency**:
   - `input_rmd` / `output_rmd` in `fix_rmd()`
   - `path` / `pattern` / `recursive` in batch functions
   - Keep these consistent across functions

3. **Error Messages**: Use `stop(..., call. = FALSE)` to provide cleaner error output (no function call printed).

4. **Return Values**: Use `invisible()` to return paths without printing. This allows chaining: `output <- fix_folder(...)`

5. **Testing Real Student Files**: Use `real_examples/` directory during development. These files demonstrate the real issues the package solves (broken paths, cascading errors, massive output).

6. **Path Discovery**: The package automatically scans parent and current directories (with `data_folder = "auto"`) to find data files. This works reliably without requiring any special project setup or `.here` files.
