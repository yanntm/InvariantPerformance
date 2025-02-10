# satcheck.py

from typing import List, Dict, Tuple, Optional
from z3 import Solver, Int, Xor, And, sat
from invariants.varindex import VarIndex
from invariants.invariant import Invariant


def buildZ3EqConjunction(
    invariants: List[Invariant],
    z3Vars,
    vIndex: VarIndex
):
    """
    Given a list of Invariant objects, produce a Z3 Boolean for the conjunction
    of sum(coeff[var] * var) == const for each.
    """
    conj_list = []
    for inv in invariants:
        lhs = 0
        for varName, coeff in inv.varCoeffs.items():
            idx = vIndex.getIndex(varName)
            lhs += coeff * z3Vars[idx]
        conj_list.append(lhs == inv.const)

    if conj_list:
        return And(*conj_list)
    return True  # neutral element if no invariants


def checkXor(
    invSetA: List[Invariant],
    invSetB: List[Invariant],
    vIndex: VarIndex
) -> Tuple[bool, Optional[Dict[str, int]]]:
    """
    Build a formula for Xor(cA, cB) with domain constraints (all variables >=0),
    solve it, and return:
      (False, None)  if UNSAT => no discrepancy
      (True, assignment)  if SAT => we found a discrepancy assignment
    'assignment' is a dict {varName -> intValue}.
    """
    solver = Solver()

    # Create Z3 Int variables for each index
    z3Vars = [Int(f"v{i}") for i in range(vIndex.size())]

    # Domain constraints: all vars >= 0
    domain_constraints = [v >= 0 for v in z3Vars]

    # Build cA and cB
    cA = buildZ3EqConjunction(invSetA, z3Vars, vIndex)
    cB = buildZ3EqConjunction(invSetB, z3Vars, vIndex)

    # Add constraints
    solver.add(domain_constraints)
    # Xor => exactly one of cA, cB is satisfied
    solver.add(Xor(cA, cB))

    if solver.check() == sat:
        model = solver.model()

        # Convert model to python dict
        assignment: Dict[str,int] = {}
        for i in range(vIndex.size()):
            nm = vIndex.getName(i)
            val = model[z3Vars[i]]
            assignment[nm] = val.as_long() if val is not None else 0

        return (True, assignment)
    else:
        return (False, None)
