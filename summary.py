#!/usr/bin/env python3
import sys
import pandas as pd

def summary(csv_file):
    # Read CSV into DataFrame
    df = pd.read_csv(csv_file)
    
    # Define flags for each status
    df['succ'] = (df['Status'] == 'OK').astype(int)
    df['time'] = (df['Status'] == 'TO').astype(int)
    df['ovf']  = (df['Status'] == 'OF').astype(int)
    # mem: statuses containing "MO" but not "OF"
    df['mem']  = df['Status'].apply(lambda x: 1 if ("MO" in str(x) and "OF" not in str(x)) else 0)
    df['unk']  = (df['Status'] == 'UNK').astype(int)
    
    # Group by Tool and compute counts
    g = df.groupby('Tool').agg(
        tot=('Status', 'count'),
        succ=('succ', 'sum'),
        time=('time', 'sum'),
        ovf=('ovf', 'sum'),
        mem=('mem', 'sum'),
        unk=('unk', 'sum')
    ).reset_index()
    g['fail'] = g['tot'] - g['succ']
    
    # Print markdown table
    print("summary\n")
    print("| Tool | Failure | time | ovf | mem | unk | Success | Total |")
    print("|---|---|---|---|---|---|---|---|")
    for _, row in g.sort_values('Tool').iterrows():
        print(f"| {row['Tool']} | {row['fail']} | {row['time']} | {row['ovf']} | {row['mem']} | {row['unk']} | {row['succ']} | {row['tot']} |")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <csv_file>")
        sys.exit(1)
    summary(sys.argv[1])

if __name__ == '__main__':
    main()
