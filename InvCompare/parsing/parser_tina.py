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
            # skip blank lines
            continue

        # Must match "... (integer)" at the end
        flow_match = FLOW_LINE_PATTERN.match(ln_stripped)
        if not flow_match:
            # Not a valid flow line (could be '0.073s' or other noise)
            continue

        var_part = flow_match.group(1)  # everything before (const)
        const_str = flow_match.group(2)
        try:
            const_val = int(const_str)
        except ValueError:
            # If we can't parse the constant, skip
            continue

        # For transition flows, ignore the parsed constant and set it to 0.
        if not isPlaceFlow:
            const_val = 0

        # Now parse the variable part, splitting on whitespace
        var_chunks = var_part.split()
        varCoeffs = {}
        for vc in var_chunks:
            m = VAR_PATTERN.match(vc)
            if not m:
                # chunk doesn't match "varName" or "varName*coeff"
                continue
            varName = m.group(1).strip()
            coeff_str = m.group(2)
            if coeff_str is None:
                # no "*xxx", means coefficient = +1
                varCoeffs[varName] = varCoeffs.get(varName, 0) + 1
            else:
                cval = int(coeff_str)
                varCoeffs[varName] = varCoeffs.get(varName, 0) + cval

        result.append(Invariant(varCoeffs, const_val))

    return result
