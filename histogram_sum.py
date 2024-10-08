import importlib.util
import subprocess
import sys
import os

# List of required libraries
required_libraries = ['pandas', 'scipy', 'seaborn', 'matplotlib', 'statsmodels','datetime', 'openpyxl']

# Check if each library is installed
for lib in required_libraries:
    spec = importlib.util.find_spec(lib)
    if spec is None:
        print(f"{lib} is not installed. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", lib])

# Now import the required libraries
import pandas as pd
import openpyxl
import scipy.stats as stats
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from datetime import datetime


def main(meta_file_path, file_path, sheet, output_path, column, conditions, hue_column):
    # Load the MetaData
    print("Loading metadata...")
    if meta_file_path.endswith(('.xlsx', '.xls')):
        meta_data = pd.read_excel(meta_file_path)
        meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        meta_data.set_index('sample_id', inplace=True)
    elif meta_file_path.endswith('.csv'):
        meta_data = pd.read_csv(meta_file_path, sep=';')
        meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        meta_data.set_index('sample_id', inplace=True)
    else:
        raise ValueError("Unsupported file format")
    print("MetaData loaded successfully:")
    print(meta_data.head())

    if not conditions or conditions == ['']:
        conditions = meta_data[column].unique().tolist()
        print(f'condition is:\n{conditions}')
    else:
        conditions = conditions
    print(f'condition is:\n{conditions}')

    # Load the main data
    print("Loading main data...")
    if file_path.endswith(('.xlsx', '.xls')):
        ThermoData = pd.read_excel(file_path, sheet_name=sheet)
        index = ThermoData.loc[ThermoData.iloc[:, 0] == 'Family'].index[0]
        ThermoData.columns = ThermoData.iloc[index]
        ThermoData = ThermoData.drop(ThermoData.index[index])
        for i, col in enumerate(ThermoData.columns):
            if ' ' in col:
                ThermoData.columns.values[i] = col.replace(' ', '_')
            else:
                continue
        for index, row in ThermoData.iterrows():
            if isinstance(row['Metabolite_name'], str) and row['Metabolite_name'].startswith(('Sum', 'Somme')):
                ThermoData.loc[index, 'Family'] = row['Metabolite_name']
        ThermoData['Family'] = ThermoData['Family'].fillna(method='ffill')
        ThermoData = ThermoData[ThermoData['Family'].str.len().between(1, 7, inclusive=True) & ThermoData['Family'].notna()]
        ThermoData_Sum = ThermoData.drop(ThermoData.columns[[1]], axis=1)
        ThermoData_Sum = pd.melt(ThermoData_Sum, id_vars=['Family', 'Metabolite_name'], var_name='sample_id', value_name='intensity')
        print("Reshaped data:")
        print(ThermoData_Sum.head())

    elif file_path.endswith('.csv'):
        ThermoData = pd.read_csv(file_path, sep=';')
        ThermoData = ThermoData.iloc[4:]
        ThermoData.columns = ThermoData.iloc[0]
        ThermoData = ThermoData.drop(ThermoData.index[0])
        for i, col in enumerate(ThermoData.columns):
            if ' ' in col:
                ThermoData.columns.values[i] = col.replace(' ', '_')
            else:
                continue
        ThermoData['Family'] = ThermoData['Family'].fillna(method='ffill')
        ThermoData = ThermoData.drop(ThermoData.columns[[1, 2]], axis=1)
        ThermoData_Sum = ThermoData_Sum.T
        ThermoData_Sum.columns = ThermoData_Sum.iloc[0]
        ThermoData_Sum = ThermoData_Sum.iloc[1:]
        ThermoData_Sum.index.name = 'sample_id'
    else:
        raise ValueError("Unsupported file format")
    print("Main data loaded successfully:")
    print(ThermoData_Sum.head())
    
    # Check if the column exists in the metadata
    if column not in meta_data.columns:
        print("Available columns in metadata:", meta_data.columns)
        raise KeyError(f"Column '{column}' not found in metadata")
    
    # Merging data-metadata
    print("Merging data...")
    selected_meta_data = meta_data[[column]]
    merged_data = ThermoData_Sum.merge(selected_meta_data, left_on='sample_id', right_index=True, how='left')
    filtered_meta_data = merged_data[merged_data[column].isin(conditions)]
    print("Merged data:")
    print(merged_data.head())
    print("Filtered data:")
    print(filtered_meta_data.head())

    # Ensure the output directory exists
    if not os.path.exists(output_path):
        os.makedirs(output_path)

    def barplotGenerating(df, output_path):
        sns.set(style="whitegrid")
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'barplots_{timestamp}.pdf'
        output_path = os.path.join(output_path, filename)

        with PdfPages(output_path) as pdf:
            families = df['Family'].unique()
            
            for family in families:
                df_family = df[df['Family'] == family]
                df_summary = df_family.groupby(['Metabolite_name', column]).agg(
                    mean_intensity=('intensity', 'mean'),
                    std_intensity=('intensity', 'std')
                ).reset_index()
                plt.figure(figsize=(16, 10))
                sns.barplot(data=df_summary, x='Metabolite_name', y='mean_intensity', hue=column, ci=None,
                            palette='husl', capsize=.2)

                plt.title(f'Bar Plot for Family: {family}')
                plt.xlabel('Metabolite')
                plt.ylabel('Intensity')
                plt.xticks(rotation=45, ha='right')
                plt.legend(title=column)
                plt.tight_layout()

                pdf.savefig()
                plt.close()

        print(f'PDF saved to {output_path}')

    # Generate the barplots
    barplotGenerating(filtered_meta_data, output_path)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python histogram_sum.py <config_file>")
        sys.exit(1)

    config_file = sys.argv[1]

    # Read config file to get inputs
    with open(config_file, 'r') as f:
        lines = f.readlines()
        config = {line.split('=')[0].strip(): line.split('=')[1].strip() for line in lines}

    # Extract variables from config
    meta_file_path = config.get('meta_file_path', '')
    file_path = config.get('file_path', '')
    sheet = config.get('sheet', '')
    output_path = config.get('output_path', '')
    column = config.get('column', '')
    conditions_str = config.get('conditions', '')
    conditions = conditions_str.split(',')
    hue_column = column  # Set the dynamic hue column from 'column' parameter

    # Call main function
    main(meta_file_path, file_path, sheet, output_path, column, conditions, hue_column)
