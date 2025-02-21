# parser_tina.py

import re
from typing import List
from invariants.invariant import Invariant

# Regex for an entire line describing a flow:
# - One or more variable terms, each possibly with "*coefficient"
# - Followed by space, then "(someInteger)"
# Examples:
#   "p0 p72 p73 p74 (1)"
#   "capacity_c0*-1 resource_c0*-4 (10)"
FLOW_LINE_PATTERN = re.compile(r'^(.*?)\s*\((\-?\d+)\)\s*$')

# Regex to match a "variable*coeff" or "variable" chunk
#   e.g. "capacity_c0*-1", "resource_c1*-4", "capacity_c1", "p72"
VAR_PATTERN = re.compile(r'^([^()]+?)(?:\*(\-?\d+))?$')

def parseLogTina(logPath: str, isPlaceFlow: bool = True) -> List[Invariant]:
    """
    A more robust parser for Tina logs:
      - Skips blank lines within the relevant section.
      - Only parses lines that match e.g. "... (integer)" at the end.
    """

    invariants: List[Invariant] = []
    relevant_lines: List[str] = []

    # Define possible section headers
    if isPlaceFlow:
        possible_headers = [
            "P-FLOWS BASIS",
            "P-SEMI-FLOWS GENERATING SET"
        ]
    else:
        possible_headers = [
            "T-FLOWS BASIS",
            "T-SEMI-FLOWS GENERATING SET"
        ]

    inside_relevant_section = False

    with open(logPath, "r", encoding="utf-8") as f:
        for line in f:
            line_stripped = line.strip()

            # If the line contains the relevant header, we start a new section
            if any(hdr in line_stripped for hdr in possible_headers):
                inside_relevant_section = True
                relevant_lines = []
                continue

            if inside_relevant_section:
                # End conditions
                if (
                    line_stripped.startswith("0.000s")
                    or line_stripped.startswith("not invariant")
                    or line_stripped.startswith("not consistent")
                    or "FLOWS BASIS" in line_stripped
                    or "SEMI-FLOWS" in line_stripped
                    or "ANALYSIS COMPLETED" in line_stripped
                ):
                    # End of relevant block
                    invariants.extend(_parseFlowLines(relevant_lines, isPlaceFlow))
                    inside_relevant_section = False
                else:
                    # Accumulate lines (including blank lines)
                    relevant_lines.append(line_stripped)

    # If we ended the file while still in the relevant section
    if inside_relevant_section and relevant_lines:
        invariants.extend(_parseFlowLines(relevant_lines, isPlaceFlow))

    return invariants

# Replace the _parseFlowLines function and add _parseLineTina before it in parsing/parser_tina.py

def _parseLineTina(line: str, isPlaceFlow: bool) -> Invariant:
    """
    Parse a single Tina invariant line ending with '(integer)'.
    
    Examples:
        "AltitudePossibleVal_9 (1)"
        "P1*-1 P2*-1 P3*-1 P4*-1 P5*-1 Plane_On_Ground_Signal_no_F*-1 Plane_On_Ground_Signal_no_T*-1 (-1)"
    
    Args:
        line: The raw line from the log.
        isPlaceFlow: If False, sets the constant to 0 for transition flows.
    
    Returns:
        An Invariant object, or raises ValueError if parsing fails.
    """
    flow_match = FLOW_LINE_PATTERN.match(line.strip())
    if not flow_match:
        raise ValueError(f"Line does not match invariant pattern: {line}")
    
    var_part = flow_match.group(1)  # Everything before (const)
    const_str = flow_match.group(2)
    const_val = int(const_str)
    
    # For transition flows, ignore the constant and set to 0
    if not isPlaceFlow:
        const_val = 0
    
    var_chunks = var_part.split()
    var_coeffs = {}
    for vc in var_chunks:
        m = VAR_PATTERN.match(vc)
        if not m:
            continue
        var_name = m.group(1).strip()
        coeff_str = m.group(2)
        coeff = 1 if coeff_str is None else int(coeff_str)
        var_coeffs[var_name] = var_coeffs.get(var_name, 0) + coeff
    
    return Invariant(var_coeffs, const_val)

def _parseFlowLines(lines: List[str], isPlaceFlow: bool) -> List[Invariant]:
    """
    Parse each line in 'lines' as a single flow if it matches the pattern:
       varName varName... (const)
    ignoring lines that are empty or do not match.
    For transition flows (isPlaceFlow == False), the constant is discarded (set to 0).
    """
    result: List[Invariant] = []
    for ln in lines:
        ln_stripped = ln.strip()
        if not ln_stripped:
            # Skip blank lines
            continue
        
        try:
            inv = _parseLineTina(ln_stripped, isPlaceFlow)
            result.append(inv)
        except ValueError:
            # Not a valid flow line (could be '0.073s' or other noise)
            continue
    
    return result