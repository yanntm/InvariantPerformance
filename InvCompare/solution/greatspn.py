# solution/greatspn.py
import os
from typing import List
from invariants.invariant import Invariant
from invariants.report import formatInvariantAsEquation
from parsing.parser_greatspn import parse_greatspn_net, parse_greatspn_invariants

def create_solution_for_greatspn(log_path: str, model_path: str, mode: str) -> None:
    """
    Create a .sol file from GreatSPN invariant files (.pba, .tba, .pin, .tin).
    
    Args:
        log_path: Path to the GreatSPN log file (e.g., logs/model.gspn, unused).
        model_path: Path to the model folder (contains model.net and invariant files).
        mode: Calculation mode (e.g., "pflows", "tsemiflows").
    """
    # Map mode to invariant file extension
    mode_to_ext = {
        "PFLOWS": "pba",
        "TFLOWS": "tba",
        "PSEMIFLOWS": "pin",
        "TSEMIFLOWS": "tin"
    }
    ext = mode_to_ext.get(mode)
    if not ext:
        raise ValueError(f"Unsupported mode for GreatSPN: {mode}")
    
    inv_file = os.path.join(model_path, f"model.{ext}")
    net_file = os.path.join(model_path, "model.net")
    sol_file = f"{log_path}.sol"
    
    if not os.path.exists(inv_file) or not os.path.exists(net_file):
        raise FileNotFoundError(f"Missing required files: {inv_file} or {net_file}")
    
    # Parse names from .net
    place_names, transition_names = parse_greatspn_net(net_file)
    names = place_names if mode in ("PFLOWS", "PSEMIFLOWS") else transition_names
    is_place_flow = mode in ("PFLOWS", "PSEMIFLOWS")
    
    # Parse invariants
    invariants: List[Invariant] = parse_greatspn_invariants(inv_file, names, is_place_flow)
    
    # Write to .sol file
    with open(sol_file, "w", encoding="utf-8") as f:
        for inv in invariants:
            # Hack: Handle '?' constant for place flows
            line = formatInvariantAsEquation(inv)
            if is_place_flow and inv.const == "?":
                line = line.replace(" = ?", " = ?")
            f.write(line + "\n")
            
     