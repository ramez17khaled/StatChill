# StatChill

StatChill is a simple, easy-to-use, and free statistical software for Windows. It accepts datasets in CSV or XLSX format and requires a metadata CSV file.

## RUN Steps

1. If you have Git installed, ignor this step :
    ```sh
    git clone git clone https://github.com/git/git 
    ```
2. Clone the GitHub repository:
Open Command Prompt or PowerShell and run:
    ```sh
    git clone https://github.com/ramez17khaled/StatChill.git
    ```
3. Execute the `installation.bat` for requirment installataion
4. Execute the `StatChill.bat`  to run the software

## Input

### 1. Metadata File Path:

- Path to the metadata CSV file, separated by `;`.
- The metadata file must start with a column named `SAMPLE`, containing the sample names matching the dataset's intensity columns.
- Case sensitivity (uppercase or lowercase) is not important.
- Users can add and name additional columns as desired.

**Example Metadata:**

| SAMPLE | Class  | Condition | Batch | Type | Injection Order |
|--------|--------|-----------|-------|------|-----------------|
| S1     | QC     |           | b2    | QC1  | 1               |
| S2     | Sample | C1        | b1    | B25  | 2               |
| S3     | BLC    | C2        | b1    | BLC  | 3               |

### 2. Data File Path:

- Path to the dataset file in CSV (separated by `;`) or XLSX format.
- The dataset format should follow specific column positions:
  - Metabolite column in the third position.
  - Sample intensities start from the sixth column.

**Example Dataset:**

| Family | ISTD | Metabolite | MZ  | RT  | Samples       |
|--------|------|------------|-----|-----|---------------|
| f1     | istd | met1       | MZ1 | RT1 | Intensities   |
| f1     | istd | met2       | MZ1 | RT2 | Intensities   |
| f2     | istd | met3       | MZ2 | RT1 | Intensities   |

StatChill will isolate the Metabolite column and sample intensities for statistical analysis.

### 3. Sheet/Page (Excel only):

- If the dataset is in XLSX format, specify the sheet name.
- Leave it empty if using a CSV file.

### 4. Output Path:

- Path to the directory where outputs will be saved.

### 5. Statistical Method:

Select one of the following methods:
- **3D PCA:** Default method for quality control to detect batch effects or errors in feature detection. It plots selected conditions of interest on three axes (PC1, PC2, PC3).
- **PLS-DA:** Supervised classification method. Provides a PLS-DA plot based on user-selected conditions and columns, along with a CSV and plot of the top 20 metabolites causing differences.
- **Volcano Plot:** Suitable for a large number of detected features. It plots features showing significant differences between two conditions based on p-value and fold change.
- **Correlation Heatmap:** Studies the correlation between metabolites in two conditions. Returns a heatmap and a CSV containing the correlation matrix.
- **ANOVA:** Analyzes differences between selected conditions and features. Returns a CSV with p-values and a TXT file with p-values and f-values for each feature and condition.
- **batchCorrect:** comming Soon!

### 6. Select Column of Interest:

- Column name of interest in the metadata.

### 7. Select Label Column (Optional):

- Used in the 3D PCA method for plot annotation.

### 8. Enter Conditions (comma-separated):

- Conditions of interest in the selected column, separated by commas.

## Requirements

1. Python
https://www.python.org/ftp/python/3.9.5/python-3.9.5-amd64.exe
2. R
https://cran.r-project.org/bin/windows/base/

