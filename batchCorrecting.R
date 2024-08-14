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
    row.names(data) <- data$sample_id  
  } else if (file_ext %in% c("xlsx", "xls")) {
    # Read XLSX or XLS file
    if (is.null(sheet_name)) {
      stop("Sheet name must be specified for Excel files.")
    }
    data <- readxl::read_excel(file_path, sheet = sheet_name)
    data <- data[, -c(1, 2)]  
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
pc_scores <- as.data.frame(pca_result$x[, 1:3])
pc_scores$batch <- filtered_meta[[column]]  # Add batch information
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
cat("creating boxplot.\n")

# Boxplot of batch effects

# Log-transform the filtered data
log_filtered_data <- log(filtered_data + 1)  # Adding 1 to avoid log(0)

# Melt the log-transformed data for visualization
library(reshape2)
melted_log_data <- melt(log_filtered_data)
melted_log_data$batch <- rep(filtered_meta[[column]], each = ncol(log_filtered_data))

# Create a boxplot of the log-transformed filtered data
library(ggplot2)
boxplot_log_plot <- ggplot(melted_log_data, aes(x = batch, y = value, fill = batch)) +
  geom_boxplot() +
  labs(title = "Boxplot of Log-Transformed Batch Effects", x = "Batch", y = "Log(Expression Value)") +
  theme_minimal() +
  theme(legend.position = "none")

# Print the boxplot
print(boxplot_log_plot)

# Save boxplot
boxplot_file <- file.path(output_path, "boxplot_batch_effects.png")
ggsave(boxplot_file, plot = boxplot_log_plot, width = 7, height = 7)

cat("Boxplot of batch effects is done.\n")
cat("Start correction.\n")

# Batch correction using limma
batch <- factor(filtered_meta[[column]])

# Check the length of batch vector matches the number of rows in filtered_main_data
if (length(batch) != nrow(filtered_data)) {
  stop("Mismatch between length of batch vector and number of rows in filtered_main_data")
}

design <- model.matrix(~ batch - 1)

if (nrow(design) != nrow(filtered_data)) {
  stop("Mismatch between number of rows in design matrix and filtered_main_data")
}


# Transpose filtered_data for limma
filtered_data_t <- t(filtered_data)
filtered_data_t_numeric <- as.numeric(filtered_data_t)
filtered_data_t_numeric <- matrix(filtered_data_t_numeric, nrow = nrow(filtered_data_t), ncol = ncol(filtered_data_t))

# Apply batch correction
corrected_data <- removeBatchEffect(filtered_data_t_numeric, batch = batch, design = design)

# Transpose corrected_data back
corrected_data_t <- t(corrected_data)
corrected_data_t_df <- as.data.frame(corrected_data_t)
# Calculate variance for each column
variances_corr <- apply(corrected_data_t_df, 2, var)
# Identify and remove columns with zero variance
zero_variance_columns_corr <- names(variances_corr[variances_corr == 0])
filtered_data_df_cleaned_corr  <- corrected_data_t_df[, variances_corr != 0]

# Perform PCA on corrected data
pca_corrected <- prcomp(filtered_data_df_cleaned_corr, scale. = TRUE)

# Extract scores for the first three principal components of corrected data
pc_scores_corrected <- as.data.frame(pca_corrected$x[, 1:3])
pc_scores_corrected$batch <- filtered_meta[[column]]  # Add batch information
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

# Log-transform the corrected data
log_corrected_data <- log(corrected_data_t + 1)  # Adding 1 to avoid log(0)

# Melt the log-transformed data for visualization
library(reshape2)
melted_log_corrected_data <- melt(log_corrected_data)
melted_log_corrected_data$batch <- rep(filtered_meta$batch, each = ncol(log_corrected_data))

# Create a boxplot of the log-transformed corrected data
library(ggplot2)
boxplot_log_corrected <- ggplot(melted_log_corrected_data, aes(x = batch, y = value, fill = batch)) +
  geom_boxplot() +
  labs(title = "Boxplot of Log-Transformed Corrected Batch Effects", x = "Batch", y = "Log(Expression Value)") +
  theme_minimal() +
  theme(legend.position = "none")

# Print the boxplot
print(boxplot_log_corrected)

# Save corrected boxplot
boxplot_file_corrected <- file.path(output_path, "boxplot_batch_effects_corrected.png")
ggsave(boxplot_file_corrected, plot = boxplot_log_corrected, width = 7, height = 7)

cat("Boxplot of corrected batch effects is done.\n")
