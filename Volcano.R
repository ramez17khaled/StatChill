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
required_packages <- c("dplyr", "tidyr", "readxl", "ggplot2", "ggrepel")

# Print process start message
cat("Process started.\n")

# Install and load required packages
install_and_load(required_packages)

# Load required libraries
library(dplyr)
library(tidyr)
library(readxl)
library(ggplot2)
library(ggrepel)

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
    print (data) 
    data <- t(data)  
    colnames(data) <- as.character(unlist(data[1, ]))
    data <- data[-1, ]
  } else {
    stop("Unsupported file format. Only CSV and XLSX/XLS files are supported.")
  }
  
  # Debugging statements
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

# Load metadata
cat("Loading metadata...\n")
meta_data <- read_file(meta_file_path)

# Load main data with specific sheet
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

# Print message on data filtering completion
cat("Data filtered successfully.\n")

# Function to generate volcano plot
generate_volcano_plot <- function(data, condition1_col, condition1_val, condition2_col, condition2_val) {
  # Filter metabolite data
  metabolite_data <- colnames(data)[!colnames(data) %in% c(condition1_col, condition2_col)]
  
  # Extract condition 1 data
  condition1_data <- data %>% filter(!!sym(condition1_col) == condition1_val)
  condition1_data <- condition1_data %>%
    select(-one_of(condition1_col))
  condition1_data <- lapply(condition1_data, function(col) {
    as.numeric(col)
  })
  
  # Extract condition 2 data
  condition2_data <- data %>%
    filter(!!sym(condition2_col) == condition2_val)
  condition2_data <- condition2_data %>%
    select(-one_of(condition2_col))
  condition2_data <- lapply(condition2_data, function(col) {
    as.numeric(col)
  })
  
  # Calculate fold change
  fold_change <- sapply(metabolite_data, function(col) {
    mean_condition1 <- mean(condition1_data[[col]], na.rm = TRUE)
    mean_condition2 <- mean(condition2_data[[col]], na.rm = TRUE)
    fold_change <- mean_condition2 / mean_condition1
    return(fold_change)
  })
  
  fold_change_df <- data.frame(Metabolite = names(fold_change), Fold_Change = fold_change)
  
  # Calculate p-values
  p_values <- sapply(metabolite_data, function(col) {
    if (length(unique(condition1_data[[col]])) < 2 || length(unique(condition2_data[[col]])) < 2) {
      return(NA)  # Not enough variation for t-test
    }
    t_test_result <- tryCatch({
      t.test(condition1_data[[col]], condition2_data[[col]])$p.value
    }, error = function(e) {
      return(NA)  # Handle any errors during t-test
    })
    return(t_test_result)
  })
  
  p_values_df <- data.frame(Metabolite = names(p_values), P_Value = p_values)
  
  # Merge fold change and p-value data frames
  volcano_df <- merge(p_values_df, fold_change_df, by = "Metabolite")
  volcano_df$log2FoldChange <- log2(volcano_df$Fold_Change)
  
  # Determine differentially expressed metabolites
  volcano_df$diffexpressed <- "NO"
  volcano_df$diffexpressed[volcano_df$log2FoldChange > 0.6 & volcano_df$P_Value < 0.05] <- "UP"
  volcano_df$diffexpressed[volcano_df$log2FoldChange < -0.6 & volcano_df$P_Value < 0.05] <- "DOWN"
  
  # Generate volcano plot
  cat("Generating volcano plot...\n")
  volcano_plot <- ggplot(volcano_df, aes(x = log2FoldChange, y = -log10(P_Value), col = diffexpressed, label = Metabolite)) +
    geom_vline(xintercept = c(-0.6, 0.6), col = "gray", linetype = 'dashed') +
    geom_hline(yintercept = -log10(0.05), col = "gray", linetype = 'dashed') +
    geom_point(size = 1) +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "orange") + # Add significance threshold line
    labs(color = 'Severe', x = "log2(FC)", y = "-log10(P-Value)") +
    theme_minimal() +
    theme(panel.background = element_rect(fill = "white", color = NA)) +
    scale_color_manual(values = c("blue", "gray", "red"),
                       labels = c("Downregulated", "Not significant", "Upregulated"))
  
  return(list(volcano_plot = volcano_plot, volcano_data = volcano_df))
}

# Generate volcano plot using user-defined conditions
volcano_results <- generate_volcano_plot(filtered_data, column, config_conditions[1], column, config_conditions[2])
# Extract the volcano plot and volcano data
volcano_plot <- volcano_results$volcano_plot
volcano_data <- volcano_results$volcano_data

# Save volcano data to CSV
output_file <- paste0(output_path, "/volcano.csv")
write.csv(volcano_data, file = output_file, row.names = FALSE)

# Save volcano plot as PNG
output_plot <- paste0(output_path, "/volcano_plot.png")
ggsave(output_plot, plot = volcano_plot, device = "png")

# Print message on completion with conditions
cat("Volcano plot generated successfully for conditions:", conditions, "\n")
