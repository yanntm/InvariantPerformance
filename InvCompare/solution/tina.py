import os
import re
from typing import Optional
from invariants.invariant import Invariant
from invariants.report import formatInvariantAsEquation
from parsing.parser_tina import _parseLineTina

def create_solution_for_tina(log_path: str, model_path: str, mode: str) -> None:
    """
    Create a .sol file from a Tina log, strip net and invariants from the log, 
    and reinsert a synthetic '(X) (semi)flow(s)' line at the start of the invariant section.
    
    Args:
        log_path: Path to the Tina log file (e.g., logs/model.tina).
        model_path: Path to the model folder (unused but kept for consistency).
        mode: Calculation mode (e.g., "PFLOWS", "PSEMIFLOWS").
    """
    sol_file = f"{log_path}.sol"
    tmp_file = f"{log_path}.tmp"
    net_start_pattern = re.compile(r'^net\s+.*$')
    net_line_pattern = re.compile(r'^(tr|pl)\s+.*$')
    inv_pattern = re.compile(r'^.*\(-?\d+\)$')
    
    is_place_flow = mode in ("PFLOWS", "PSEMIFLOWS", "FLOWS", "SEMIFLOWS")
    in_net_block = False
    in_invariants = False
    sol_count = 0  # Count lines added to .sol
    insert_line = -1  # Line number to insert count
    
    # First pass: process the log and collect invariants
    with open(log_path, "r", encoding="utf-8") as log_f, \
         open(sol_file, "w", encoding="utf-8") as sol_f, \
         open(tmp_file, "w", encoding="utf-8") as tmp_f:
        
        line_num = 0
        for line in log_f:
            line_stripped = line.rstrip()  # Preserve EOL for tmp
            
            # Handle net block
            if not in_net_block and not in_invariants and net_start_pattern.match(line_stripped):
                in_net_block = True
                continue
            if in_net_block:
                if not line_stripped:  # Empty line ends net block
                    in_net_block = False
                elif net_line_pattern.match(line_stripped):
                    continue  # Discard tr/pl lines
                else:
                    in_net_block = False  # Unexpected line, treat as post-net
            
            # Handle invariants
            if not in_invariants and inv_pattern.match(line_stripped):
                in_invariants = True
                insert_line = line_num  # Mark the start of the section
                try:
                    inv = _parseLineTina(line_stripped, is_place_flow)
                    sol_f.write(formatInvariantAsEquation(inv) + "\n")
                    sol_count += 1
                except ValueError:
                    tmp_f.write(line)
                line_num += 1
                continue
            if in_invariants:
                if not line_stripped:  # Empty line ends invariants
                    in_invariants = False
                    tmp_f.write(line)
                elif inv_pattern.match(line_stripped):
                    try:
                        inv = _parseLineTina(line_stripped, is_place_flow)
                        sol_f.write(formatInvariantAsEquation(inv) + "\n")
                        sol_count += 1
                    except ValueError:
                        tmp_f.write(line)
                else:
                    tmp_f.write(line)
                line_num += 1
                continue
            
            # Copy everything else to tmp
            tmp_f.write(line)
            line_num += 1
    
    # Second pass: reinsert the count line at the marked position
    final_tmp = f"{log_path}.tmp2"
    flow_type = "semiflow" if "SEMI" in mode else "flow"
    count_line = f"{sol_count} {flow_type}(s)\n"
    
    with open(tmp_file, "r", encoding="utf-8") as tmp_f, \
         open(final_tmp, "w", encoding="utf-8") as final_f:
        for i, line in enumerate(tmp_f):
            if i == insert_line:
                final_f.write(count_line)
            final_f.write(line)
    
    # Replace original log with final version
    os.replace(final_tmp, log_path)
    os.remove(tmp_file)
    
    # Ensure .sol exists (empty if no invariants)
    if sol_count == 0:
        open(sol_file, "w").close()
        
        
