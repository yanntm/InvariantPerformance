import pandas as pd
import numpy as np
from scipy.stats import gmean
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.backends.backend_pdf import PdfPages

# Load the CSV file
file_path = 'invar.csv'  # Replace with the path to your CSV file
data = pd.read_csv(file_path)

# Replace -1 in 'Time' with 120000 (timeout in ms)
data['Time'] = data['Time'].replace(-1, 120000)

# Add a column for success or failure
data['Status'] = data.apply(lambda row: 'Failure' if row['Status'] != 'OK' else 'Success', axis=1)

# Function to calculate summary statistics (mean and median)
def calculate_summary_statistics(df):
    summary = {
        'mean': df.mean(),
        'median': df.median()
    }
    return pd.Series(summary)

# Calculate summary statistics for each tool and each metric
tools = data['Tool'].unique()
metrics = ['Time', 'TotalTime', 'Mem']
summary_data = []

for tool in tools:
    tool_data = data[data['Tool'] == tool]
    for metric in metrics:
        stats = calculate_summary_statistics(tool_data[metric])
        stats['Tool'] = tool
        stats['Metric'] = metric
        summary_data.append(stats)

# Create a dataframe for the summary statistics
summary_stats_df = pd.DataFrame(summary_data)

# Pivot the dataframe to have a more readable format
summary_stats_pivot = summary_stats_df.pivot(index='Tool', columns='Metric').reset_index()
summary_stats_pivot.columns = ['Tool', 'Time_mean', 'Time_median', 'TotalTime_mean', 'TotalTime_median', 'Mem_mean', 'Mem_median']

# Limit precision to whole milliseconds
summary_stats_pivot = summary_stats_pivot.round(0)

# Qualitative results: Count successes and failures per tool
qualitative_results = data.groupby(['Tool', 'Status']).size().unstack(fill_value=0)
qualitative_results['Total'] = qualitative_results.sum(axis=1)

# Create a PDF report
pdf_path = 'analysis_report.pdf'
with PdfPages(pdf_path) as pdf:
    # Box plot for Time
    plt.figure(figsize=(12, 8))
    sns.boxplot(x='Tool', y='Time', data=data)
    plt.title('Distribution of Time by Tool')
    plt.ylabel('Time (ms)')
    pdf.savefig()
    plt.close()

    # Box plot for TotalTime
    plt.figure(figsize=(12, 8))
    sns.boxplot(x='Tool', y='TotalTime', data=data)
    plt.title('Distribution of TotalTime by Tool')
    plt.ylabel('TotalTime (ms)')
    pdf.savefig()
    plt.close()

    # Box plot for Memory
    plt.figure(figsize=(12, 8))
    sns.boxplot(x='Tool', y='Mem', data=data)
    plt.title('Distribution of Memory by Tool')
    plt.ylabel('Memory (kB)')
    pdf.savefig()
    plt.close()

    # Cactus plot for Time
    plt.figure(figsize=(12, 8))
    for tool in data['Tool'].unique():
        tool_data = data[data['Tool'] == tool]
        sorted_time = np.sort(tool_data['Time'].values)
        y_vals = np.arange(1, len(sorted_time) + 1)
        plt.step(y_vals, sorted_time, label=tool)
    plt.title('Cactus Plot for Time')
    plt.xlabel('Instances Solved')
    plt.ylabel('Time (ms)')
    plt.legend()
    pdf.savefig()
    plt.close()

    # Cactus plot for Memory
    plt.figure(figsize=(12, 8))
    for tool in data['Tool'].unique():
        tool_data = data[data['Tool'] == tool]
        sorted_mem = np.sort(tool_data['Mem'].values)
        y_vals = np.arange(1, len(sorted_mem) + 1)
        plt.step(y_vals, sorted_mem, label=tool)
    plt.title('Cactus Plot for Memory')
    plt.xlabel('Instances Solved')
    plt.ylabel('Memory (kB)')
    plt.legend()
    pdf.savefig()
    plt.close()

    # Qualitative results table
    plt.figure(figsize=(12, 8))
    plt.axis('off')
    plt.title('Qualitative Results')
    qualitative_results_table = plt.table(cellText=qualitative_results.values,
                                          colLabels=qualitative_results.columns,
                                          rowLabels=qualitative_results.index,
                                          cellLoc='center', loc='center')
    qualitative_results_table.auto_set_font_size(False)
    qualitative_results_table.set_fontsize(12)
    qualitative_results_table.scale(1.2, 1.2)
    pdf.savefig(bbox_inches='tight')
    plt.close()

    # Summary statistics table
    plt.figure(figsize=(12, 8))
    plt.axis('off')
    plt.title('Summary Statistics')
    summary_stats_table = plt.table(cellText=summary_stats_pivot.values,
                                    colLabels=summary_stats_pivot.columns,
                                    cellLoc='center', loc='center')
    summary_stats_table.auto_set_font_size(False)
    summary_stats_table.set_fontsize(12)
    summary_stats_table.scale(1.2, 1.2)
    pdf.savefig(bbox_inches='tight')
    plt.close()

print(f'Report saved to {pdf_path}')
