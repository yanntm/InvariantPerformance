# solution/tina.py
from typing import List
import os
import subprocess
from invariants.invariant import Invariant
from invariants.report import formatInvariantAsEquation
from parsing.parser_tina import parseLogTina

def create_solution_for_tina(log_path: str, model_path: str, mode: str) -> None:
    """
    Create a .sol file from a Tina log, strip invariants from the log, and write them to a .sol file.
    
    Args:
        log_path: Path to the Tina log file (e.g., logs/model.tina).
        model_path: Path to the model folder (unused here but kept for consistency).
        mode: Calculation mode (e.g., "pflows", "tsemiflows").
    """
    # Determine if we're parsing place or transition flows
    is_place_flow = mode in ("pflows", "psemiflows", "flows", "semiflows")
    
    # Step 1: Parse invariants from the log
    invariants: List[Invariant] = parseLogTina(log_path, is_place_flow)
    
    # Step 2: Strip invariant lines from the log file in place
    # Tina logs use a format like "p0 p72 p73 (1)", so we match lines ending with "(number)"
    subprocess.run(["sed", "-i", r"/^.*\s*(\-?\d\+)\s*$/d", log_path], check=True)
    
    # Step 3: Write invariants to a .sol file
    sol_file = f"{log_path}.sol"
    with open(sol_file, "w", encoding="utf-8") as f:
        for inv in invariants:
            f.write(formatInvariantAsEquation(inv) + "\n")