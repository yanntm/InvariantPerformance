# parser_petrispot.py

import re
from typing import List, Dict
from invariants.invariant import Invariant

from invariants.report import formatInvariantAsEquation

def parseLogPetriSpot(logPath: str, isPlaceFlow: bool = True) -> List[Invariant]:
    """
    Parse the content of a PetriSpot (petri32/64/128) tool log file
    and return a list of Invariant objects for either place flows or transition flows.

    We look for blocks that say, for example:
      "Computed X P flows in 0 ms."
      or
      "Computed X P semiflows in 0 ms."
    if isPlaceFlow=True.

    For isPlaceFlow=False, we look for:
      "Computed X T flows in 0 ms."
      or
      "Computed X T semiflows in 0 ms."

    Then we gather all lines that start with "inv : " until we see another
    "Computed ..." line or "Total of ..." line, etc.

    Each "inv : " line is parsed into a single Invariant object.

    Example line:
      inv : capacity_c0 + capacity_c1 + 4*resource_c0 + resource_c1 = 10
    """
    invariants: List[Invariant] = []

    # We define regex patterns to detect the start and the "inv : ..." lines.
    # "Computed (\d+) P flows" or "Computed (\d+) P semiflows"
    # "Computed (\d+) T flows" or "Computed (\d+) T semiflows"
    if isPlaceFlow:
        start_block_pattern = re.compile(r'^Computed\s+\d+\s+P\s+(?:flows|semiflows)\s+in\b')
    else:
        start_block_pattern = re.compile(r'^Computed\s+\d+\s+T\s+(?:flows|semiflows)\s+in\b')

    # Once in the block, we capture lines that start with "inv :"
    inv_line_pattern = re.compile(r'^\s*inv\s*:\s*(.*)$')

    inside_block = False

    with open(logPath, "r", encoding="utf-8") as f:
        for line in f:
            line_stripped = line.strip()

            # Detect the start of a relevant block
            if start_block_pattern.search(line_stripped):
                # We have found a block that corresponds to the requested flows
                inside_block = True
                continue

            if inside_block:
                # If we encounter a line that starts with "Computed" again or "Total of" or is empty,
                # we end the current block
                if (not line_stripped or
                    line_stripped.startswith("Computed ") or
                    line_stripped.startswith("Total of ")):
                    inside_block = False
                    continue

                # Otherwise, try matching "inv :"
                m = inv_line_pattern.match(line_stripped)
                if m:
                    inv_expr = m.group(1)
                    inv_obj = _parse_inv_line_petrispot(inv_expr)
                    if inv_obj:
                        invariants.append(inv_obj)
                # If the line does not start with "inv :", we ignore it

    return invariants

def _parse_inv_line_petrispot(expr: str) -> Invariant:
    """
    Parse an invariant string of the form:
       <term> <term> ... = <constant>
    where each term is:
       optional whitespace, optional sign, optional whitespace, 
       optional integer, optional '*' and then an identifier (starting with a letter).
    
    Example input:
       "-p1003 + p1054 - p915 + p957 - p958 + p960 - p961 + p965 + p977 + p980 + p982 + p994 = 0"
    
    Returns an Invariant object.
    """
    # Split the expression at '='.
    if '=' in expr:
        lhs, rhs = expr.split('=', 1)
    else:
        lhs = expr
        rhs = "0"
    const_val = int(rhs.strip())
    
    varCoeffs: Dict[str, int] = {}
    
    # Regex pattern for one term:
    #  \s*           : any leading whitespace
    #  ([+-]?)       : an optional sign
    #  \s*           : optional whitespace
    #  (\d+)?        : an optional integer coefficient (one or more digits)
    #  \s*(?:\*\s*)? : an optional '*' with surrounding whitespace
    #  ([A-Za-z]\w*): a variable identifier (starts with a letter, then word characters)
    pattern = re.compile(r'\s*([+-]?)\s*(\d+)?\s*(?:\*\s*)?([A-Za-z]\w*)')
    
    pos = 0
    # Process the LHS until the end.
    while pos < len(lhs):
        match = pattern.match(lhs, pos)
        if not match:
            # If there's no match, break out (or optionally report an error).
            break
        
        sign_str = match.group(1)
        coeff_str = match.group(2)
        identifier = match.group(3)
        
        sign = -1 if sign_str == '-' else 1
        coeff = int(coeff_str) if coeff_str is not None else 1
        
        # Accumulate coefficient for the variable.
        varCoeffs[identifier] = varCoeffs.get(identifier, 0) + sign * coeff
        
        # Update position.
        pos = match.end()
    
    inv = Invariant(varCoeffs, const_val)
    # print(f"parsed {formatInvariantAsEquation(inv)} from line {expr}")
    return inv
