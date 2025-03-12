# solution/petrisage.py
import os
from typing import List
from invariants.invariant import Invariant
from invariants.report import formatInvariantAsEquation

def create_solution_for_petrisage(log_path: str, model_path: str, mode: str) -> None:
    """
    Create a .sol file from PetriSage's .tba output, parsing into Invariant objects.

    Args:
        log_path: Path to the PetriSage log file (e.g., logs/model.petrisage).
        model_path: Path to the model folder (unused, kept for interface consistency).
        mode: Calculation mode (e.g., "PFLOWS", "TFLOWS").

    Raises:
        ValueError: If mode is unsupported.
        FileNotFoundError: If the .tba file is missing.
    """
    # PetriSage only supports PFLOWS and TFLOWS
    if mode not in ("PFLOWS", "TFLOWS"):
        raise ValueError(f"Unsupported mode for PetriSage: {mode}")

    # The .tba file is moved to $LOGS by run.sh
    tba_file = f"{log_path}.tba"
    sol_file = f"{log_path}.sol"

    if not os.path.exists(tba_file):
        raise FileNotFoundError(f"Missing PetriSage output file: {tba_file}")

    # Determine prefix and constant based on mode
    is_place_flow = (mode == "PFLOWS")
    prefix = "p" if is_place_flow else "t"
    const = "?" if is_place_flow else "0"  # ? for PFLOWS, 0 for TFLOWS

    # Parse .tba into Invariant objects
    invariants: List[Invariant] = []
    with open(tba_file, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]
        num_flows = int(lines[0])  # First line is number of flows
        for line in lines[1:num_flows + 1]:  # Skip num_flows line and stop at "0"
            parts = line.split()
            num_terms = int(parts[0])
            terms = parts[1:]  # coeff idx coeff idx ...
            if len(terms) != 2 * num_terms:
                raise ValueError(f"Malformed line in {tba_file}: {line}")

            # Build varCoeffs dictionary
            var_coeffs = {}
            for i in range(0, len(terms), 2):
                coeff = int(terms[i])
                idx = int(terms[i + 1]) - 1  # Convert 1-based to 0-based
                var_name = f"{prefix}{idx}"
                var_coeffs[var_name] = coeff

            # Create Invariant (const is a placeholder, adjusted below)
            inv = Invariant(var_coeffs, 0 if mode == "TFLOWS" else -1)  # -1 as a temp flag for ?

            # Adjust constant for PFLOWS (Invariant expects int, so we hack it later)
            invariants.append(inv)

    # Write to .sol file
    with open(sol_file, "w", encoding="utf-8") as f:
        for inv in invariants:
            # Hack for PFLOWS: override const to "?"
            if mode == "PFLOWS":
                inv.const = 0  # Temporary int value
                line = formatInvariantAsEquation(inv).replace(" = 0", " = ?")
            else:
                line = formatInvariantAsEquation(inv)
            f.write(line + "\n")

    # Clean up the temporary .tba file
    os.remove(tba_file)