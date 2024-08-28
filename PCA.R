# pca_analysis.R

# Function to install and load required packages
options(repos = c(CRAN = "https://cloud.r-project.org"))
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
required_packages <- c("dplyr", "tidyr", "readxl", "ggplot2", "ggrepel")

# Install and load required packages
install_and_load(required_packages)

# Load required libraries
library(dplyr)
library(tidyr)
library(readxl)
library(ggplot2)
library(ggrepel)

cat("PCA Analysis: Start\n")

# Function to read file based on type
read_file <- function(file_path, sheet_name = NULL) {
  if (!file.exists(file_path)) {
    stop("File not found.")
  }
  
  file_ext <- tools::file_ext(file_path)
  
  if (file_ext == "csv") {
    data <- read.csv(file_path, stringsAsFactors = FALSE, sep = ';')
    colnames(data) <- tolower(gsub(" ", "_", colnames(data)))
    row.names(data) <- data$sample_id 
  } else if (file_ext %in% c("xlsx", "xls")) {
    if (is.null(sheet_name)) {
      stop("Sheet name must be specified for Excel files.")
    }
    data <- readxl::read_excel(file_path, sheet = sheet_name)
    data <- data[, -c(1, 3, 4)]  
    data <- t(data) 
    colnames(data) <- as.character(unlist(data[1, ]))
    data <- data[-1, ] 
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
label_column <- trimws(config[grepl("^label_column", config$V1), "V2"])
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

# Check if all columns have zero variance
if (length(zero_variance_columns) == ncol(filtered_data_df)) {
  cat("Warning: All columns have zero variance. PCA cannot be performed.\n")
  cat("PCA Analysis: Aborted due to zero variance in all columns.\n")
  quit(status = 0)
}

# Remove zero variance columns
filtered_data_df_cleaned <- filtered_data_df[, variances != 0]

# Perform PCA
pca_result <- prcomp(filtered_data_df_cleaned, scale. = TRUE)

# Extract scores for the first two principal components
pc_scores <- as.data.frame(pca_result$x[, 1:2])
pc_scores$condition <- filtered_meta[[column]]

# Save PCA results to CSV
pca_output_path <- file.path(output_path, "pca_results.csv")
write.csv(pc_scores, pca_output_path, row.names = TRUE)

cat("PCA results saved to:", pca_output_path, "\n")

# Check if the label column exists in the metadata
if (label_column %in% colnames(filtered_meta)) {
  pc_scores$label <- filtered_meta[[label_column]]
} else {
  cat("Warning: Label column '", label_column, "' not found in metadata. No labels will be added to the plot.\n")
  pc_scores$label <- NULL
}

# Create a 2D PCA plot
pca_plot <- ggplot(pc_scores, aes(x = PC1, y = PC2, color = condition)) +
  geom_point(size = 3) +
  theme_minimal() +
  labs(title = "PCA Plot", x = "PC1", y = "PC2") +
  scale_color_manual(values = rainbow(length(unique(pc_scores$condition)))) +
  theme(legend.position = "right")

# Add labels if they exist
if (!is.null(pc_scores$label)) {
  pca_plot <- pca_plot + geom_text_repel(aes(label = label), size = 3)
}

# Save the PCA plot as a PNG file
pca_plot_path <- file.path(output_path, "PCA_plot.png")
ggsave(pca_plot_path, plot = pca_plot, width = 10, height = 8)

cat("PCA plot saved to:", pca_plot_path, "\n")

cat("PCA Analysis: Complete\n")
