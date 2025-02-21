# solution/petrispot.py
from typing import List
import os
import subprocess
from invariants.invariant import Invariant
from invariants.report import formatInvariantAsEquation
from parsing.parser_petrispot import parseLogPetriSpot

def create_solution_for_petrispot(log_path: str, model_path: str, mode: str) -> None:
    """
    Create a .sol file from a PetriSpot log, strip invariants from the log, and write them to a .sol file.
    
    Args:
        log_path: Path to the PetriSpot log file (e.g., logs_pflows/model.petri64).
        model_path: Path to the model folder (unused here but kept for consistency).
        mode: Calculation mode (e.g., "pflows", "tsemiflows").
    """
    # Determine if we're parsing place or transition flows
    is_place_flow = mode in ("pflows", "psemiflows", "flows", "semiflows")
    
    # Step 1: Parse invariants from the log
    invariants: List[Invariant] = parseLogPetriSpot(log_path, is_place_flow)
    
    # Step 2: Strip invariant lines from the log file in place
    subprocess.run(["sed", "-i", "/^inv :.*$/d", log_path], check=True)
    
    # Step 3: Write invariants to a .sol file using report.py syntax
    sol_file = f"{log_path}.sol"
    with open(sol_file, "w", encoding="utf-8") as f:
        for inv in invariants:
            f.write(formatInvariantAsEquation(inv) + "\n")
