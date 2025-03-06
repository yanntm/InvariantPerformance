from typing import List
from .invariant_parser import parse_invariant_line
from invariants.invariant import Invariant

def parseSolFile(solPath: str) -> List[Invariant]:
    """
    Parse a .sol file containing invariants in PetriSpot equation format.
    Each line is an equation like "p1 + 2*p2 - p3 = 1".
    """
    invariants: List[Invariant] = []

    with open(solPath, "r", encoding="utf-8") as f:
        for line in f:
            line_stripped = line.strip()
            if not line_stripped:  # Skip empty lines
                continue
            inv_obj = parse_invariant_line(line_stripped)
            if inv_obj:
                invariants.append(inv_obj)

    return invariants