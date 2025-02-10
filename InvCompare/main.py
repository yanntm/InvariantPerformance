#!/usr/bin/env python3

"""
Entry point of the Petri net invariant comparison tool.

This version processes both P-flows and T-flows in a single run:
1. Parse and compare P-flows of logA vs logB.
2. Parse and compare T-flows of logA vs logB.
"""

# main.py (excerpt)

import sys
from typing import List

from parsing.parser_generic import parseLogGeneric
from invariants.varindex import VarIndex
from invariants.invariant import Invariant
from invariants.deduplicate import deduplicateInvariants

# Our new modules:
from solver.satcheck import checkXor
from report import (
    reportSparseAssignment,
    findViolations,
    reportViolations,
    formatInvariantAsEquation
)

def compare_flows(logA: str, logB: str, isPlaceFlow: bool, label: str) -> None:
    print(f"=== Comparing {label} ===")

    # 1) Parse logs
    invSetA: List[Invariant] = parseLogGeneric(logA, isPlaceFlow)
    invSetB: List[Invariant] = parseLogGeneric(logB, isPlaceFlow)

    # ---- DEBUG PRINTS: Show parsed invariants ----
    print("Parsed invariants from A:")
    for idx, inv in enumerate(invSetA):
        print(f"  A#{idx}: {formatInvariantAsEquation(inv)}")

    print("Parsed invariants from B:")
    for idx, inv in enumerate(invSetB):
        print(f"  B#{idx}: {formatInvariantAsEquation(inv)}")

    # 2) Build fused VarIndex
    allVarsA = set()
    for inv in invSetA:
        allVarsA.update(inv.getUsedVarNames())

    allVarsB = set()
    for inv in invSetB:
        allVarsB.update(inv.getUsedVarNames())

    idxA = VarIndex(sorted(allVarsA))
    idxB = VarIndex(sorted(allVarsB))
    fusedIndex = idxA.fuse(idxB)

    # 3) Deduplicate
    uniqueA, uniqueB = deduplicateInvariants(invSetA, invSetB, fusedIndex)

    # ---- DEBUG PRINTS: Show invariants after deduplication ----
    print(f"After deduplication, uniqueA has {len(uniqueA)} invariants, uniqueB has {len(uniqueB)} invariants.")
    for idx, inv in enumerate(uniqueA):
        print(f"  uniqueA#{idx}: {formatInvariantAsEquation(inv)}")
    for idx, inv in enumerate(uniqueB):
        print(f"  uniqueB#{idx}: {formatInvariantAsEquation(inv)}")

    # 4) Restrict
    usedVarsAll = set()
    for inv in uniqueA:
        usedVarsAll.update(inv.getUsedVarNames())
    for inv in uniqueB:
        usedVarsAll.update(inv.getUsedVarNames())
    finalIndex = fusedIndex.restrict(usedVarsAll)

    # 5) Check XOR (using satcheck and reporting)
    sat, assignment = checkXor(uniqueA, uniqueB, finalIndex)
    if not sat:
        print("No discrepancy found (UNSAT). The sets of invariants appear consistent.\n")
        return

    print("DISCREPANCY FOUND: XOR is satisfiable.")
    reportSparseAssignment(assignment)

    violatedA = findViolations(uniqueA, assignment)
    violatedB = findViolations(uniqueB, assignment)
    satisfiesA = (len(violatedA) == 0)
    satisfiesB = (len(violatedB) == 0)

    if satisfiesA and not satisfiesB:
        print("=> Satisfies invariants of set A, violates set B.")
        reportViolations("Set B", uniqueB, violatedB, assignment)
    elif satisfiesB and not satisfiesA:
        print("=> Satisfies invariants of set B, violates set A.")
        reportViolations("Set A", uniqueA, violatedA, assignment)
    else:
        print("=> Unexpected: Possibly both sets are partially satisfied.")
        reportViolations("Set A", uniqueA, violatedA, assignment)
        reportViolations("Set B", uniqueB, violatedB, assignment)

    print()  # extra newline

def main() -> None:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <logA> <logB>")
        sys.exit(1)

    logA = sys.argv[1]
    logB = sys.argv[2]

    # First, compare P-flows
    compare_flows(logA, logB, isPlaceFlow=True, label="Place Flows")

    # Then, compare T-flows
    compare_flows(logA, logB, isPlaceFlow=False, label="Transition Flows")


if __name__ == "__main__":
    main()
