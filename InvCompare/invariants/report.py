# report.py

from typing import List, Dict
from invariants.invariant import Invariant


def evaluateInvariant(inv: Invariant, assignment: Dict[str,int]) -> int:
    """
    Evaluate: sum(coeff[varName] * assignment[varName]) - const
    Returns 0 if satisfied, else the difference.
    """
    lhs_val = 0
    for varName, coeff in inv.varCoeffs.items():
        lhs_val += coeff * assignment.get(varName, 0)
    return lhs_val - inv.const


def findViolations(
    invs: List[Invariant],
    assignment: Dict[str,int]
) -> List[int]:
    """
    Return the list of indices of invariants that are violated (nonzero difference).
    """
    violated = []
    for i, inv in enumerate(invs):
        diff = evaluateInvariant(inv, assignment)
        if diff != 0:
            violated.append(i)
    return violated


def reportSparseAssignment(assignment: Dict[str,int]) -> None:
    """
    Print the assignment in sparse form (hiding zero values).
    """
    sparse = {k: v for k, v in assignment.items() if v != 0}
    if not sparse:
        print("All variables are 0 in this solution.")
    else:
        print("Sparse solution (non-zero variables):", sparse)


def reportViolations(
    label: str,
    invariants: List[Invariant],
    violated_indices: List[int],
    assignment: Dict[str,int]
) -> None:
    """
    Print each violated invariant in a PetriSpot-like syntax, showing the difference.
    """
    if not violated_indices:
        print(f"{label}: No violations.")
        return

    print(f"{label}: The following invariants are violated:")
    for idx in violated_indices:
        inv = invariants[idx]
        diff = evaluateInvariant(inv, assignment)
        lhs_val = diff + inv.const  # sum of coeff*var
        eq_str = formatInvariantAsEquation(inv)

        print(
            f"  - Invariant : \"{eq_str}\" is contradicted, "
            f"evaluation is {lhs_val} (delta {diff})."
        )


def formatInvariantAsEquation(inv: Invariant) -> str:
    """
    Convert an invariant to a string like:
      p1 + 2*p2 - p3 = 1
    with each nonzero coefficient plus or minus.
    """
    # Sort by varName for stable output
    items = sorted(inv.varCoeffs.items(), key=lambda x: x[0])
    tokens = []
    first_term = True

    for var, coeff in items:
        if coeff == 0:
            continue
        if first_term:
            # First term: no leading '+' if coeff>0
            if coeff == 1:
                tokens.append(f"{var}")
            elif coeff == -1:
                tokens.append(f"-{var}")
            else:
                tokens.append(f"{coeff}*{var}")
            first_term = False
        else:
            sign_str = " + " if coeff > 0 else " - "
            c = abs(coeff)
            if c == 1:
                tokens.append(f"{sign_str}{var}")
            else:
                tokens.append(f"{sign_str}{c}*{var}")

    lhs_expr = "0" if not tokens else "".join(tokens)

    return f"{lhs_expr} = {inv.const}"
