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
required_packages <- c("dplyr", "tidyr", "readxl", "ggplot2", "ggrepel", "rgl", "limma", "reshape2")

# Install and load required packages
install_and_load(required_packages)

# Load required libraries
library(dplyr)
library(tidyr)
library(readxl)
library(ggplot2)
library(ggrepel)
library(rgl)
library(limma)
library(reshape2)

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
conditions <- trimws(config[grepl("^conditions", config$V1), "V2"])
label_column <- trimws(config[grepl("^label_column", config$V1), "V2"])

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

# Check if the label column exists in the metadata
if (!(label_column %in% colnames(meta_data))) {
  stop(sprintf("Label column '%s' not found in metadata.", label_column))
}

# Filter main_data and meta_data based on conditions in 'column'
filtered_meta <- meta_data[meta_data[[label_column]] %in% conditions, , drop = FALSE]
filtered_data <- main_data[row.names(main_data) %in% row.names(filtered_meta), ]

# Ensure all columns in filtered_data are numeric
filtered_data <- apply(filtered_data, 2, as.numeric)

# Perform PCA
pca_result <- prcomp(filtered_data, scale. = TRUE)

# Extract scores for the first three principal components
pc_scores <- as.data.frame(pca_result$x[, 1:3])
pc_scores$batch <- filtered_meta$batch  # Add batch information
pc_scores$label <- filtered_meta[[label_column]]  # Add label information

# Save PCA results to CSV
pca_output_path <- file.path(output_path, "pca_results.csv")
write.csv(pc_scores, pca_output_path, row.names = TRUE)

# PCA plot with batch colors and labels
pca_plot <- ggplot(pc_scores, aes(x = PC1, y = PC2, color = batch, label = label)) +
  geom_point(size = 3) +
  geom_text_repel() +
  labs(title = "PCA Plot Colored by Batch", x = "PC1", y = "PC2") +
  theme_minimal() +
  theme(legend.position = "right")

# Save PCA plot
pca_plot_file <- file.path(output_path, "pca_plot_batch.png")
ggsave(pca_plot_file, plot = pca_plot, width = 7, height = 7)

cat("PCA plot with batch colors is done.\n")

# Boxplot of batch effects
melted_data <- melt(filtered_data)
melted_data$batch <- rep(filtered_meta$batch, each = ncol(filtered_data))

boxplot_plot <- ggplot(melted_data, aes(x = batch, y = value, fill = batch)) +
  geom_boxplot() +
  labs(title = "Boxplot of Batch Effects", x = "Batch", y = "Expression Value") +
  theme_minimal() +
  theme(legend.position = "none")

# Save boxplot
boxplot_file <- file.path(output_path, "boxplot_batch_effects.png")
ggsave(boxplot_file, plot = boxplot_plot, width = 7, height = 7)

cat("Boxplot of batch effects is done.\n")

# Batch correction using limma
batch <- as.factor(filtered_meta$batch)
design <- model.matrix(~0 + batch)
colnames(design) <- levels(batch)

# Check dimensions before correction
cat("Dimensions of filtered_data: ", dim(filtered_data), "\n")
cat("Dimensions of design matrix: ", dim(design), "\n")
cat("Batch levels: ", levels(batch), "\n")

# Transpose filtered_data for limma
filtered_data_t <- t(filtered_data)

# Apply batch correction
corrected_data <- removeBatchEffect(filtered_data_t, batch = batch, design = design)

# Transpose corrected_data back
corrected_data_t <- t(corrected_data)

# Perform PCA on corrected data
pca_corrected <- prcomp(corrected_data_t, scale. = TRUE)

# Extract scores for the first three principal components of corrected data
pc_scores_corrected <- as.data.frame(pca_corrected$x[, 1:3])
pc_scores_corrected$batch <- filtered_meta$batch  # Add batch information
pc_scores_corrected$label <- filtered_meta[[label_column]]  # Add label information

# Save corrected PCA results to CSV
pca_corrected_output_path <- file.path(output_path, "pca_results_corrected.csv")
write.csv(pc_scores_corrected, pca_corrected_output_path, row.names = TRUE)

# PCA plot with batch colors and labels after correction
pca_plot_corrected <- ggplot(pc_scores_corrected, aes(x = PC1, y = PC2, color = batch, label = label)) +
  geom_point(size = 3) +
  geom_text_repel() +
  labs(title = "PCA Plot After Batch Correction", x = "PC1", y = "PC2") +
  theme_minimal() +
  theme(legend.position = "right")

# Save corrected PCA plot
pca_plot_corrected_file <- file.path(output_path, "pca_plot_batch_corrected.png")
ggsave(pca_plot_corrected_file, plot = pca_plot_corrected, width = 7, height = 7)

cat("PCA plot after batch correction is done.\n")

# Boxplot of corrected batch effects
melted_corrected_data <- melt(corrected_data_t)
melted_corrected_data$batch <- rep(filtered_meta$batch, each = ncol(corrected_data_t))

boxplot_plot_corrected <- ggplot(melted_corrected_data, aes(x = batch, y = value, fill = batch)) +
  geom_boxplot() +
  labs(title = "Boxplot of Corrected Batch Effects", x = "Batch", y = "Expression Value") +
  theme_minimal() +
  theme(legend.position = "none")

# Save corrected boxplot
boxplot_file_corrected <- file.path(output_path, "boxplot_batch_effects_corrected.png")
ggsave(boxplot_file_corrected, plot = boxplot_plot_corrected, width = 7, height = 7)

cat("Boxplot of corrected batch effects is done.\n")
