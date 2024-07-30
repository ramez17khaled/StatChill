# pca_analysis.R

# Function to install and load required packages
install_and_load <- function(packages) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
    }
  }
}

# List of required packages
required_packages <- c("dplyr", "tidyr", "readxl", "ggplot2", "ggrepel", "rgl", "htmlwidgets")

# Install and load required packages
install_and_load(required_packages)

# Load required libraries
library(dplyr)
library(tidyr)
library(readxl)
library(ggplot2)
library(ggrepel)
library(rgl)
library(htmlwidgets)

cat("PCA Analysis: Start\n")

# Function to read file based on type
read_file <- function(file_path, sheet_name = NULL) {
  # Check if file exists
  if (!file.exists(file_path)) {
    stop("File not found.")
  }
  
  # Extract file extension
  file_ext <- tools::file_ext(file_path)
  
  # Read file based on extension
  if (file_ext == "csv") {
    # Read CSV file
    data <- read.csv(file_path, stringsAsFactors = FALSE, sep = ';')
    colnames(data) <- tolower(gsub(" ", "_", colnames(data)))
    row.names(data) <- data$sample  # Assuming 'sample' is the row identifier
  } else if (file_ext %in% c("xlsx", "xls")) {
    # Read XLSX or XLS file
    if (is.null(sheet_name)) {
      stop("Sheet name must be specified for Excel files.")
    }
    data <- readxl::read_excel(file_path, sheet = sheet_name)
    data <- data[, -c(1, 2, 4, 5)]  # Drop specific columns
    data <- t(data)  # Transpose data
    colnames(data) <- as.character(unlist(data[1, ]))
    data <- data[-1, ]  # Remove header row
  } else {
    stop("Unsupported file format. Only CSV and XLSX/XLS files are supported.")
  }
  
  return(data)
}

# Read input file paths and conditions from config.txt
config_file <- "config.txt"
config <- read.table(config_file, sep = "=", stringsAsFactors = FALSE, strip.white = TRUE)

# Assign variables from config file
meta_file_path <- trimws(config[grepl("^meta_file_path", config$V1), "V2"])
file_path <- trimws(config[grepl("^file_path", config$V1), "V2"])
sheet <- trimws(config[grepl("^sheet", config$V1), "V2"])
output_path <- trimws(config[grepl("^output_path", config$V1), "V2"])
column <- trimws(config[grepl("^column", config$V1), "V2"])
label_column <- trimws(config[grepl("^label_column", config$V1), "V2"])  # Added label column
conditions <- trimws(config[grepl("^conditions", config$V1), "V2"])

# Parse conditions
conditions <- strsplit(conditions, ",")[[1]]

# Load metadata
meta_data <- read_file(meta_file_path)

# Load main data with specific sheet
main_data <- read_file(file_path, sheet)

# Check if the column exists in the metadata
if (!(column %in% colnames(meta_data))) {
  stop(sprintf("Column '%s' not found in metadata.", column))
}

# Filter main_data and meta_data based on conditions in 'column'
filtered_meta <- meta_data[meta_data[[column]] %in% conditions, , drop = FALSE]
filtered_data <- main_data[row.names(main_data) %in% row.names(filtered_meta), ]

# Ensure all columns in filtered_data are numeric
filtered_data <- apply(filtered_data, 2, as.numeric)
filtered_data_df <- as.data.frame(filtered_data)
# Calculate variance for each column
variances <- apply(filtered_data_df, 2, var)
# Identify and remove columns with zero variance
zero_variance_columns <- names(variances[variances == 0])
filtered_data_df_cleaned  <- filtered_data_df[, variances != 0]

# Perform PCA
pca_result <- prcomp(filtered_data_df_cleaned, scale. = TRUE)

# Extract scores for the first three principal components
pc_scores <- pca_result$x[, 1:3]

# Save PCA results to CSV
pca_output_path <- file.path(output_path, "pca_results.csv")
write.csv(pc_scores, pca_output_path, row.names = TRUE)

cat("PCA results saved to:", pca_output_path, "\n")

# Color points based on conditions in 'column'
filtered_conditions <- filtered_meta[[column]]

# 3D scatter plot using rgl
colors <- rainbow(length(unique(filtered_conditions)))[as.integer(factor(filtered_conditions))]

# If the label column is specified, use it for annotation
if (label_column %in% colnames(filtered_meta)) {
  labels <- filtered_meta[[label_column]]
} else {
  labels <- NULL
}

# Open a new rgl device
open3d()
plot3d(pc_scores[, 1], pc_scores[, 2], pc_scores[, 3], 
       col = colors, size = 8,  # Increase point size
       xlab = "PC1", ylab = "PC2", zlab = "PC3",
       main = "PCA Plot in 3D")

# Add legend
legend3d("topright", legend = levels(factor(filtered_conditions)), pch = 16, col = rainbow(length(unique(filtered_conditions))))

# Add annotations if labels are provided
if (!is.null(labels)) {
  text3d(pc_scores[, 1], pc_scores[, 2], pc_scores[, 3], texts = labels, adj = 1.5)
}

cat("PCA plot is done\n")

# Display the 3D plot in R session
rglwidget()  # Interactive plot window
while (TRUE) {
  Sys.sleep(60)  # Check every minute if the window is still open
}
