# parser_petrispot.py

import re
from typing import List, Dict
from invariants.invariant import Invariant

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
    Parse the string after "inv : " into an Invariant object.
    Example input: "capacity_c0 + capacity_c1 + 4*resource_c0 = 10"
                   or "a + 3*b - c = -2"
    The general form is: <left side> = <right side>
    The left side is an expression with + and - terms:
      e.g. "capacity_c0 + 4*resource_c0 - capacity_c2"
    The right side is an integer constant.

    Return: Invariant with varCoeffs, const.
    """
    varCoeffs: Dict[str,int] = {}
    const_val = 0

    # Split around '='
    parts = expr.split('=')
    if len(parts) == 2:
        lhs = parts[0].strip()
        rhs = parts[1].strip()
        try:
            const_val = int(rhs)
        except ValueError:
            # If there's an unexpected format or no integer on RHS
            # We could either raise an error or default to 0
            const_val = 0
    else:
        # If there's no "=", assume const=0
        lhs = expr
        const_val = 0

    # Parse the LHS expression (which can contain +, -).
    # A simple approach: replace '-' with '+-' to split easily on '+'
    # But be careful if there's already a " + -"? We'll do a safe replacement:
    lhs_mod = lhs.replace('-', '+-')
    # Now split by '+'
    tokens = lhs_mod.split('+')
    # Example:
    #   "capacity_c0 + capacity_c1 - 3*resource_c0"
    # => lhs_mod = "capacity_c0 + capacity_c1 +- 3*resource_c0"
    # => tokens = ["capacity_c0 ", " capacity_c1 ", "- 3*resource_c0"]

    for token in tokens:
        t = token.strip()
        if not t:
            continue
        # t might look like "capacity_c0", "-3*resource_c0", "4*xxx", "-xxx"
        # We'll parse sign and factor
        match = re.match(r'^([+-])?(\d*)\*?(\S+)$', t)
        if match:
            sign_str = match.group(1)  # '+', '-', or None
            coeff_str = match.group(2) # e.g. '3' or ''
            var_name  = match.group(3) # e.g. 'resource_c0'

            sign = 1
            if sign_str == '-':
                sign = -1
            # If no sign_str, sign=+1 by default

            if coeff_str == '':
                # no explicit number => 1
                coeff_val = 1
            else:
                coeff_val = int(coeff_str)

            final_coeff = sign * coeff_val
            varCoeffs[var_name] = varCoeffs.get(var_name, 0) + final_coeff
        else:
            # If we cannot parse the token, ignore or raise an error
            pass

    return Invariant(varCoeffs, const_val)
