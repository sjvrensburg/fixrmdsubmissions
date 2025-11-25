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
3. Converting bare file paths to `here::here()` format (optional)
4. Adding student folder name as heading (optional, useful when students forget their names)
5. Injecting global output-limiting code to prevent massive data dumps
6. Creating backups before any modifications
7. Adding transparency comments explaining all changes

Key parameters:
- `input_rmd`: Path to the .Rmd file to fix
- `output_rmd`: Output path (defaults to `*_FIXED.Rmd` in same directory)
- `backup`: Create `.bak` backup file (default TRUE)
- `fix_paths`: Wrap bare filenames with `here::here()` (default TRUE, requires `here` package)
- `data_folder`: Subfolder name for data files when fixing paths (default "data")
- `add_student_info`: Add parent folder name as numbered heading (default FALSE)
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
**Function**: `fix_paths_in_line()` (internal helper, not exported)

Uses regex to intelligently identify and wrap bare file paths in common data import functions with `here::here()`:

**Recognized import functions:**
- readr: `read_csv()`, `read_tsv()`, `read_delim()`, `read_table()`, `read_fwf()`
- base R: `read.csv()`, `read.csv2()`, `read.table()`, `read.delim()`, `read.delim2()`, `readRDS()`, `load()`, `source()`
- readxl: `read_excel()`, `read_xlsx()`, `read_xls()`
- data.table: `fread()`
- vroom: `vroom()`
- qs: `qread()`

**Never modifies** (by design):
- Full-line comments (`^\\s*#`)
- Lines already using `here::here()`
- Absolute paths (`/`, `C:/`, `~/`, `../`)
- URLs (`http://`, `https://`, `ftp://`)
- Network paths (`\\\\`)

**Modifies** (wraps with `here::here(data_folder, ...)`):
- Bare filenames: `"data.csv"` → `here::here("data", "data.csv")`
- Relative paths: `"data/scores.csv"` → `here::here("data", "scores.csv")`
- Nested paths: `"raw/2025/file.csv"` → `here::here("raw/2025", "file.csv")`

The `data_folder` parameter controls which subfolder to wrap. Example: with `data_folder = "."`, paths stay relative to project root. With `data_folder = "data"`, all paths become relative to a `data/` subfolder.

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

3. **Conservative Path Fixing**: Better to miss a path that should be fixed than to incorrectly modify something that shouldn't be. Absolute paths, URLs, and existing `here::here()` calls are never touched.

4. **Global Output Limiting**: Instead of trying to limit output per-chunk, a single global setup chunk (with pander, print, and max.print overrides) handles all output limiting. This is more reliable than chunk-specific options.

5. **Separation of Concerns**:
   - `fix_rmd()`: Low-level file processing
   - `fix_folder()`: High-level batch processing wrapper
   - `knit_fixed_files()`: Separate kitting step (intentionally decoupled from fixing)

## Dependencies

**Imports** (required):
- `here` ≥ 1.0.0 — Package root detection and portable paths
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

6. **The `.here` File**: Students/users should create a `.here` file in their project root. This tells the `here` package where the project root is. Without it, `here::here()` might find the wrong directory (e.g., git repo root instead of submissions folder).
