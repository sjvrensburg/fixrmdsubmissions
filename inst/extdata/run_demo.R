#!/usr/bin/env Rscript

# Simple Demo Runner for fixrmdsubmissions Package
# 
# This is a lightweight version that just runs the comprehensive demo
# without requiring development setup.

# Try to install/load package
if (!requireNamespace("fixrmdsubmissions", quietly = TRUE)) {
  cat("⚠️ Package 'fixrmdsubmissions' not found.\n")
  cat("   Please install it with: devtools::install_local('path/to/fixrmdsubmissions')\n")
  cat("   Or run from package development directory.\n")
  quit(status = 1)
}

# Load package
library(fixrmdsubmissions)

# Run the demo
demo_script <- system.file("extdata", "demo_comprehensive_features.R", 
                          package = "fixrmdsubmissions")

if (file.exists(demo_script)) {
  cat("🚀 Starting fixrmdsubmissions comprehensive demo...\n")
  cat("📂 This demo will create a 'comprehensive_demo' folder\n")
  cat("   with example files showing all package features.\n\n")
  
  source(demo_script)
} else {
  cat("❌ Demo script not found. Make sure package is properly installed.\n")
  quit(status = 1)
}