import re
from typing import Dict, Optional
from invariants.invariant import Invariant

def parse_invariant_line(expr: str) -> Optional[Invariant]:
    """
    Parse an invariant string of the form:
       <term> <term> ... = <constant> (NB)
    where each term is:
       optional whitespace, optional sign, optional whitespace, 
       optional integer, optional '*' and then an identifier (starting with a letter).
    
    Example inputs:
       "-p1003 + p1054 - p915 + p957 - p958 + p960 - p961 + p965 + p977 + p980 + p982 + p994 = 0 (1)"
       "capacity_c0 + capacity_c1 + 4*resource_c0 + resource_c1 = 10 (12)"
    
    Returns an Invariant object or None if parsing fails.
    """
    # Split the expression at '='.
    if '=' in expr:
        lhs, rhs = expr.split('=', 1)
    else:
        lhs = expr
        rhs = "0"
    
    try:
        rhs = rhs.strip()
        rhs = rhs.split(' ')[0]  # Ignore anything after '('
        const_val = int(rhs)
    except ValueError:
        return None
    
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
    while pos < len(lhs):
        match = pattern.match(lhs, pos)
        if not match:
            break
        
        sign_str = match.group(1)
        coeff_str = match.group(2)
        identifier = match.group(3)
        
        sign = -1 if sign_str == '-' else 1
        coeff = int(coeff_str) if coeff_str is not None else 1
        
        varCoeffs[identifier] = varCoeffs.get(identifier, 0) + sign * coeff
        pos = match.end()
    
    # If no terms were parsed and LHS isn’t "0", it’s invalid
    if pos == 0 and lhs.strip() != "0":
        return None
    
    return Invariant(varCoeffs, const_val)