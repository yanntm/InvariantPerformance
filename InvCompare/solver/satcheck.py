from typing import List, Dict, Tuple, Optional
from z3 import Solver, Int, Xor, And, Bool, Function, Not, sat, unsat, BoolSort
from invariants.varindex import VarIndex
from invariants.invariant import Invariant
import time

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
    """
    solver = Solver()
    z3Vars = [Int(f"v{i}") for i in range(vIndex.size())]
    domain_constraints = [v >= 0 for v in z3Vars]
    cA = buildZ3EqConjunction(invSetA, z3Vars, vIndex)
    cB = buildZ3EqConjunction(invSetB, z3Vars, vIndex)
    solver.add(domain_constraints)
    solver.add(Xor(cA, cB))

    if solver.check() == sat:
        model = solver.model()
        assignment: Dict[str, int] = {}
        for i in range(vIndex.size()):
            nm = vIndex.getName(i)
            val = model[z3Vars[i]]
            assignment[nm] = val.as_long() if val is not None else 0
        return (True, assignment)
    return (False, None)

def checkMinimality(
    invariants: List[Invariant],
    vIndex: VarIndex
) -> Tuple[List[int], float, int]:
    """
    Check if the set of invariants is minimal by testing each one for redundancy.
    Returns:
      - List of indices of invariants that are redundant (implied by the others).
      - Total time taken for the test in seconds.
      - Number of check-sat calls made.
    Defines each invariant as a Bool function and uses check-sat-assuming to test
    if all but one can be satisfied while violating that one; if UNSAT, it's redundant.
    """
    if len(invariants) <= 1:
        return ([], 0.0, 0)

    solver = Solver()
    start_time = time.time()

    # Define Z3 variables using public VarIndex methods
    z3Vars = {vIndex.getName(i): Int(vIndex.getName(i)) for i in range(vIndex.size())}

    # Domain constraints: all variables >= 0
    solver.add([v >= 0 for v in z3Vars.values()])

    # Define each invariant as a function a_i() : Bool
    assumption_funcs = []
    for i, inv in enumerate(invariants):
        lhs = 0
        for varName, coeff in inv.varCoeffs.items():
            lhs += coeff * z3Vars[varName]
        func = Function(f"a{i}", BoolSort())
        solver.add(func() == (lhs == inv.const))
        assumption_funcs.append(func)

    # Test each invariant for redundancy
    redundant_indices = []
    check_sat_calls = 0
    for i in range(len(invariants)):
        test_assumptions = [f() if j != i else Not(f())
                           for j, f in enumerate(assumption_funcs)]
        result = solver.check(test_assumptions)
        check_sat_calls += 1
        if result == unsat:
            redundant_indices.append(i)

    total_time = time.time() - start_time
    return (redundant_indices, total_time, check_sat_calls)