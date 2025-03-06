import re
from typing import List
from .invariant_parser import parse_invariant_line
from invariants.invariant import Invariant

def parseLogPetriSpot(logPath: str, isPlaceFlow: bool = True) -> List[Invariant]:
    """
    Parse the content of a PetriSpot log file and return a list of Invariant objects
    for either place flows or transition flows.
    """
    invariants: List[Invariant] = []

    if isPlaceFlow:
        start_block_pattern = re.compile(r'^Computed\s+\d+\s+P\s+(?:flows|semiflows)\s+in\b')
    else:
        start_block_pattern = re.compile(r'^Computed\s+\d+\s+T\s+(?:flows|semiflows)\s+in\b')

    inv_line_pattern = re.compile(r'^\s*inv\s*:\s*(.*)$')
    inside_block = False

    with open(logPath, "r", encoding="utf-8") as f:
        for line in f:
            line_stripped = line.strip()

            if start_block_pattern.search(line_stripped):
                inside_block = True
                continue

            if inside_block:
                if (not line_stripped or
                    line_stripped.startswith("Computed ") or
                    line_stripped.startswith("Total of ")):
                    inside_block = False
                    continue

                m = inv_line_pattern.match(line_stripped)
                if m:
                    inv_expr = m.group(1)
                    inv_obj = parse_invariant_line(inv_expr)
                    if inv_obj:
                        invariants.append(inv_obj)

    return invariants