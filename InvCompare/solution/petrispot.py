from typing import List
import os
import re
from invariants.invariant import Invariant
from invariants.report import formatInvariantAsEquation
from parsing.invariant_parser import parse_invariant_line

def create_solution_for_petrispot(log_path: str, model_path: str, mode: str) -> None:
    """
    Create a .sol file from a PetriSpot log, strip invariants from the log, and write them to a .sol file.
    """
    sol_file = f"{log_path}.sol"
    tmp_file = f"{log_path}.tmp"
    inv_line_pattern = re.compile(r'^\s*inv\s*:\s*(.*)$')
    
    with open(log_path, "r", encoding="utf-8") as log_f, \
         open(sol_file, "w", encoding="utf-8") as sol_f, \
         open(tmp_file, "w", encoding="utf-8") as tmp_f:
        
        for line in log_f:
            line_stripped = line.rstrip()
            match = inv_line_pattern.match(line_stripped)
            if match:
                inv_expr = match.group(1)
                inv = parse_invariant_line(inv_expr)
                if inv:
                    sol_f.write(formatInvariantAsEquation(inv) + "\n")
            else:
                tmp_f.write(line)
    
    os.replace(tmp_file, log_path)