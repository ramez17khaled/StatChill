# StatChill

StatChill is a simple, easy-to-use, and free statistical software for Windows. It accepts datasets in CSV or XLSX format and requires a metadata CSV file.

## RUN Steps

1. If you have Git installed, ignor this step :
    ```sh
    git clone git clone https://github.com/git/git 
    ```
2. Clone the GitHub repository or samply install the zip format for the GitHub:
Open Command Prompt or PowerShell and run:
    ```sh
    git clone https://github.com/ramez17khaled/StatChill.git
    ```
3. Execute the `installation.bat` for requirment installataion
4. update the `R_PATH` in `StatChill.bat`
5. Execute the `StatChill.bat`  to run the software

## Input

### 1. Metadata File Path:

- Path to the metadata CSV file, separated by `;`.
- The metadata file must start with a column named `SAMPLE`, containing the sample names matching the dataset's intensity columns.
- Case sensitivity (uppercase or lowercase) is not important.
- Users can add and name additional columns as desired.

**Example Metadata:**

| SAMPLE_ID | Class  | Condition | Batch | Type | Injection Order |
|-----------|--------|-----------|-------|------|-----------------|
| S1        | QC     |           | b2    | QC1  | 1               |
| S2        | Sample | C1        | b1    | B25  | 2               |
| S3        | BLC    | C2        | b1    | BLC  | 3               |

### 2. Data File Path:

- Path to the dataset file in CSV (separated by `;`) or XLSX format.
- The dataset format should follow specific column positions:
  - Metabolite column in the third position.
  - Sample intensities start from the sixth column.

**Example Dataset (generale):**

| Family | Metabolite name| MZ | RT | Samples       |
|--------|----------------|----|----|---------------|
| f1     | met1           |    |    | Intensities   |
| f1     | met2           |    |    | Intensities   |
| f2     | met3           |    |    | Intensities   |

**Example Dataset (for sum functions):**

| Family |ISTD| Metabolite name | Samples       |
|--------|----|-----------------|---------------|
| f1     | i1 | met1            | Intensities   |
| f1     | i1 | met2            | Intensities   |
|        | i2 |Sum OR Somme     | Values of sum |
| f2     | i3 | met3            | Intensities   |

**Example Dataset (for venn functions):**

SKIPE THE FIRST 3 ROWS

| Intital Database |Species detected|
|------------------|----------------|
| metabolite 1     | metabolite 1   |
| metabolite 2     | metabolite 2   |
| metabolite 3     | metabolite 3   |
| metabolite 4     | metabolite 4   |

StatChill will isolate the Metabolite column and sample intensities for statistical analysis.

### 3. Sheet/Page (Excel only):

- If the dataset is in XLSX format, specify the sheet name.
- Leave it empty if using a CSV file.

### 4. Output Path:

- Path to the directory where outputs will be saved.

### 5. Statistical Method:

Select one of the following methods:
- **PCA:** Default method for quality control to detect batch effects or errors in feature detection. It plots selected conditions of interest on two axes (PC1, PC2).
- **PLS-DA:** Supervised classification method. Provides a PLS-DA plot based on user-selected conditions and columns, along with a CSV and plot of the top 20 metabolites causing differences.
- **Volcano Plot:** Suitable for a large number of detected features. It plots features showing significant differences between two conditions based on p-value and fold change.
- **Correlation Heatmap:** Studies the correlation between metabolites in two conditions. Returns a heatmap and a CSV containing the correlation matrix.
- **sigDiff:** Analyzes differences between selected conditions (two conditions) and features. Returns a two PDF (one for lipids and onther for lipids group) with boxplot and a "*" for significant differance. 
- **batchCorrect:** use Limma library in R for batch correction and return the PCA and boxplot for the correction. A label column is required.
- **repartition:** to visualise the repartition of metabolite and group metabolite between conditions. Results are shown as heatmaps for each groups and bar and pie plot for metabolites.
- **Boxplot sum:** to visualise the repartition of family AND metabolite's sum a between conditions. Results are shown as boxplot for each groups in case of many samples for the same condition, and bar plot if ther only on sample for each condition.
- **venn sum:** to visualise the detection capacity between DB and experiment detection. Results are shown as venn diagram and between DB and Experiment, and an histogram for the items in each group. DATA HAS A SPECIAL REPARTITION: tow column named ('Intital_Database' and 'Species_detected') AND MUST SKIPED THE FIRST 3 ROWS. 
- **QC boxplot:** to visualise repartition of metabolites with a boxplot AND/OR histogram for QCs or any conditions in chousing in the metadata by selection the column of interrest and your conditions in this column. DATA HAS A SPECIAL REPARTITION: tow column named ('Intital_Database' and 'Species_detected') AND MUST SKIPED THE FIRST 3 ROWS. 


### 6. Select Column of Interest:

- Column name of interest in the metadata.

### 7. Select Label Column:

- Used in the 3D PCA and batchCorrect methods for plot annotation.

### 8. Enter Conditions (comma-separated):

- Conditions of interest in the selected column, separated by commas (ex: M,C2,...).

## Requirements

1. Python-3.9.5
https://www.python.org/ftp/python/3.9.5/python-3.9.5-amd64.exe
2. R-4.1.3 (Adapt the path statchill in case of version changing)
https://cran.r-project.org/bin/windows/base/

