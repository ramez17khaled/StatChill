import importlib.util
import subprocess
import sys
import os

required_libraries = ['pandas', 'scipy', 'matplotlib', 'numpy','datetime']

for lib in required_libraries:
    spec = importlib.util.find_spec(lib)
    if spec is None:
        print(f"{lib} is not installed. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", lib])

import pandas as pd
import scipy.stats as stats
import numpy as np
import matplotlib.pyplot as plt
from matplotlib_venn import venn2
from datetime import datetime


def main(file_path, sheet, output_path):
    # Load the MetaData
    #print("Loading metadata...")
    #if meta_file_path.endswith(('.xlsx', '.xls')):
        #meta_data = pd.read_excel(meta_file_path)
        #meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        #meta_data.set_index('sample_id', inplace=True)
    #elif meta_file_path.endswith('.csv'):
        #meta_data = pd.read_csv(meta_file_path, sep=';')
        #meta_data.columns = [col.lower().replace(' ', '_') for col in meta_data.columns]
        #meta_data.set_index('sample_id', inplace=True)
    #else:
        #raise ValueError("Unsupported file format")
    #print("MetaData loaded successfully:")
    #print(meta_data.head())

    #if not conditions or conditions == ['']:
        #conditions = meta_data[column].unique().tolist()
        #print (f'condition is:\n{conditions}')
    #else:
        #conditions = conditions
    #print (f'condition is:\n{conditions}')

    # Load the main data
    print("Loading main data...")
    if file_path.endswith(('.xlsx', '.xls')):
        ThermoData = pd.read_excel(file_path, sheet_name=sheet)
        ThermoData.columns = ThermoData.iloc[2]
        ThermoData = ThermoData.iloc[3:]
        #ThermoData = ThermoData.drop(ThermoData.tail(4).index)
        #ThermoData = ThermoData.drop(ThermoData.index[0])
        for i, col in enumerate(ThermoData.columns):
            if ' ' in col:
                ThermoData.columns.values[i] = col.replace(' ', '_')
            else:
                continue
        #for index, row in ThermoData.iterrows():
            #if isinstance(row['Metabolite_name'], str) and row['Metabolite_name'].startswith(('Sum', 'Somme')):
                #ThermoData.loc[index, 'Family'] = row['Metabolite_name']
        #ThermoData['Family'] = ThermoData['Family'].fillna(method='ffill')
        #ThermoData = ThermoData.drop(ThermoData.columns[[1, 2]], axis=1)
        #ThermoData_Sum = ThermoData[ThermoData['Family'].str.startswith(('Somme', 'Sum'))]
        #ThermoData = ThermoData.groupby(ThermoData.columns[0]).mean()
        #ThermoData_Sum = ThermoData_Sum.T
        #ThermoData_Sum.columns = ThermoData_Sum.iloc[0]
        #ThermoData_Sum = ThermoData_Sum.iloc[1:]
        #ThermoData_Sum.dropna(axis=1, how='any', inplace=True)
        #ThermoData_Sum.index.name = 'sample_id'
    elif file_path.endswith('.csv'):
        ThermoData = pd.read_csv(file_path, sep=';')
        #ThermoData = ThermoData.iloc[4:]
        #ThermoData = ThermoData.drop(ThermoData.tail(4).index)
        #ThermoData.columns = ThermoData.iloc[0]
        #ThermoData = ThermoData.drop(ThermoData.index[0])
        for i, col in enumerate(ThermoData.columns):
            if ' ' in col:
                ThermoData.columns.values[i] = col.replace(' ', '_')
            else:
                continue
        #for index, row in ThermoData.iterrows():
            #if isinstance(row['Metabolite_name'], str) and row['Metabolite_name'].startswith(('Sum', 'Somme')):
                #ThermoData.loc[index, 'Family'] = row['Metabolite_name']
        #ThermoData['Family'] = ThermoData['Family'].fillna(method='ffill')
        #ThermoData = ThermoData.drop(ThermoData.columns[[1, 2]], axis=1)
        #ThermoData = ThermoData.groupby(ThermoData.columns[0]).mean()
        #ThermoData_Sum = ThermoData_Sum.T
        #ThermoData_Sum.columns = ThermoData_Sum.iloc[0]
        #ThermoData_Sum = ThermoData_Sum.iloc[1:]
        #ThermoData_Sum.index.name = 'sample_id'
    else:
        raise ValueError("Unsupported file format")
    print("Main data loaded successfully:")
    print(ThermoData.head())
    
    # Check if the column exists in the metadata
    #if column not in meta_data.columns:
        #print("Available columns in metadata:", meta_data.columns)
        #raise KeyError(f"Column '{column}' not found in metadata")
    
    # Merging data-metadata
    #print("Merging data...")
    #selected_meta_data = meta_data[[column]]
    #merged_data = ThermoData_Sum.merge(selected_meta_data, left_index=True, right_index=True, how='left')
    #filtered_meta_data = merged_data[merged_data[column].isin(conditions)]
    #print("Merged data:")
    #print(merged_data.head())
    #print("Filtered data:")
    #print(filtered_meta_data.head())

    # Ensure the output directory exists
    if not os.path.exists(output_path):
        os.makedirs(output_path)
    set1 = set(ThermoData['Intital_Database'])
    set2 = set(ThermoData['Species_detected'])
    set1 = {x for x in set1 if not (x is None or (isinstance(x, float) and np.isnan(x)))}
    set2 = {x for x in set2 if not (x is None or (isinstance(x, float) and np.isnan(x)))}
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8), gridspec_kw={'width_ratios': [2, 1]})

    venn2([set1, set2], set_labels=('Intital DB', 'Detected'),
          set_colors=('lightgreen', 'skyblue'),
          alpha=0.6, ax=ax1)

    bars = ax2.bar(['Intital DB', 'Detected'], [len(set1), len(set2)], color=['lightgreen', 'skyblue'])

    for bar in bars:
        height = bar.get_height()
        ax2.annotate(f'{height}',
                     xy=(bar.get_x() + bar.get_width() / 2, height),
                     xytext=(0, 3),  
                     textcoords="offset points",
                     ha='center', va='bottom')

    ax2.set_ylabel('Count')
    
    filename = 'venn_histogram_plot.png'
    filepath = os.path.join(output_path, filename)
    plt.savefig(filepath, dpi=300, bbox_inches='tight')
    plt.show()

    print(f"Venn diagram and histogram saved to {output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python ANOVA.py <config_file>")
        sys.exit(1)

    config_file = sys.argv[1]

    with open(config_file, 'r') as f:
        lines = f.readlines()
        config = {line.split('=')[0].strip(): line.split('=')[1].strip() for line in lines}

    meta_file_path = config.get('meta_file_path', '')
    file_path = config.get('file_path', '')
    sheet = config.get('sheet', '')
    output_path = config.get('output_path', '')
    column = config.get('column', '')
    conditions_str = config.get('conditions', '')
    conditions = conditions_str.split(',')
    hue_column = column 

    main(file_path, sheet, output_path)