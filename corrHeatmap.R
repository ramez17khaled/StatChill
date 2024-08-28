# Function to install and load required packages
options(repos = c(CRAN = "https://cloud.r-project.org"))
install_and_load <- function(packages) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
    }
  }
}

# List of required packages
required_packages <- c("dplyr", "tidyr", "readxl", "ggplot2", "ggrepel", "reshape2")

cat("Process started.\n")

# Install and load required packages
install_and_load(required_packages)

# Load required libraries
library(dplyr)
library(tidyr)
library(readxl)
library(ggplot2)
library(ggrepel)
library(reshape2)

# Print message on package loading completion
cat("Packages loaded successfully.\n")

# Function to read file
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
    row.names(data) <- data$sample_id
  } else if (file_ext %in% c("xlsx", "xls")) {
    # Read XLSX or XLS file
    if (is.null(sheet_name)) {
      stop("Sheet name must be specified for Excel files.")
    }
    data <- readxl::read_excel(file_path, sheet = sheet_name)
    data <- data[ , -c(1, 3, 4)]  
    data <- t(data)  
    colnames(data) <- as.character(unlist(data[1, ]))
    data <- data[-1, ]
  } else {
    stop("Unsupported file format. Only CSV and XLSX/XLS files are supported.")
  }
  
  cat("File read successfully.\n")
  
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
method <- trimws(config[grepl("^method", config$V1), "V2"])
column <- trimws(config[grepl("^column", config$V1), "V2"])
conditions <- trimws(config[grepl("^conditions", config$V1), "V2"])

# Load and merge data as before
cat("Loading metadata...\n")
meta_data <- read_file(meta_file_path)

cat("Loading main data...\n")
ThermoData <- read_file(file_path, sheet_name = sheet)

# Check if the column exists in the metadata
if (!(column %in% colnames(meta_data))) {
  stop(sprintf("Column '%s' not found in metadata.", column))
}

# Merge metadata with main data based on 'sample' column
merged_data <- merge(ThermoData, meta_data[column], by = "row.names", all = TRUE)
rownames(merged_data) <- merged_data$Row.names
merged_data$Row.names <- NULL

# Filter merged data based on conditions
config_conditions <- unlist(strsplit(conditions, ","))
config_conditions <- trimws(config_conditions)
filtered_data <- merged_data[merged_data[[column]] %in% config_conditions, ]

cat("Data filtered successfully.\n")
cat("Number of rows in filtered_data:", nrow(filtered_data), "\n")
cat("Column names and types in filtered_data:\n")
print(sapply(filtered_data, class))

# Identify and handle conversion issues
conversion_issues <- sapply(filtered_data, function(x) any(is.na(as.numeric(x))))
filtered_data <- filtered_data[, !conversion_issues]
filtered_data[] <- lapply(filtered_data, function(x) {
  # Try to convert to numeric
  numeric_col <- as.numeric(as.character(x))
  
  # Return the converted column
  return(numeric_col)
})

# Check for columns with zero variance
zero_var_cols <- sapply(filtered_data, function(x) sd(x, na.rm = TRUE) == 0)
filtered_data <- filtered_data[, !zero_var_cols]

# Re-check numeric columns
numeric_cols <- sapply(filtered_data, is.numeric)
if (sum(numeric_cols) < 2) {
  stop("Insufficient numeric columns for correlation analysis.")
}

# Create a dataframe with only numeric columns
corr_df <- filtered_data[, numeric_cols, drop = FALSE]

# Compute correlation matrix
correlation <- cor(corr_df, use = "pairwise.complete.obs")

# Handle cases where correlation matrix might have NA/NaN values
if (any(is.na(correlation))) {
  cat("Warning: Correlation matrix contains NA/NaN values. These will be handled.\n")
  correlation[is.na(correlation)] <- 0
}

# Convert correlation matrix to data frame for plotting
correlation_df <- as.data.frame(as.table(correlation))
colnames(correlation_df) <- c("Condition1", "Condition2", "Correlation")

# Save correlation matrix to CSV in output directory
write.csv(correlation, file.path(output_path, "correlation_matrix.csv"), row.names = TRUE)

cat("Correlation matrix is generated and saved successfully.\n")

# Generate heatmap using base R's heatmap function
png(file = file.path(output_path, "corrHeatmap.png"))
heatmap(correlation, col = colorRampPalette(c("#eeff00", "white", "#fa6501"))(100), 
        xlab = "Conditions", ylab = "Conditions", 
        scale = "none", main = "Correlation Heatmap", symm = TRUE, margins = c(8, 8))
dev.off()

cat("Analysis completed.\n")
