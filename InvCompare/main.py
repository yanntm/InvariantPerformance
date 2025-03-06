#!/usr/bin/env python3

"""
Entry point of the Petri net invariant comparison tool.
- With --compareSolutions (default): Compares invariants from multiple .sol files pairwise for consistency.
- With --testMinimality: Tests each .sol file for minimality and reports redundant invariants.
Use --keepDup to disable deduplication (applies only to --compareSolutions).
"""

import sys
import os
from typing import List, Dict, Tuple
from parsing.parser_solution import parseSolFile
from invariants.varindex import VarIndex
from invariants.invariant import Invariant
from invariants.deduplicate import deduplicateInvariants
from solver.satcheck import checkXor, checkMinimality
from invariants.report import (
    reportSparseAssignment,
    findViolations,
    reportViolations,
    formatInvariantAsEquation
)

def get_base_name(file_path: str) -> str:
    """Extract the filename without folder or .sol extension."""
    return os.path.splitext(os.path.basename(file_path))[0]

def compare_invariants(solA: str, solB: str, keep_duplicates: bool = False) -> bool:
    """
    Compare invariants from two .sol files for consistency.
    Returns True if consistent (UNSAT), False if discrepant (SAT).
    """
    nameA = get_base_name(solA)
    nameB = get_base_name(solB)
    print(f"=== Comparing {nameA} vs {nameB} ===")

    invSetA: List[Invariant] = parseSolFile(solA)
    invSetB: List[Invariant] = parseSolFile(solB)
    print(f"Parsed {len(invSetA)} invariants from {nameA}")
    print(f"Parsed {len(invSetB)} invariants from {nameB}")

    allVarsA = set().union(*(inv.getUsedVarNames() for inv in invSetA))
    allVarsB = set().union(*(inv.getUsedVarNames() for inv in invSetB))
    idxA = VarIndex(sorted(allVarsA))
    idxB = VarIndex(sorted(allVarsB))
    fusedIndex = idxA.fuse(idxB)

    if keep_duplicates:
        uniqueA, uniqueB = invSetA, invSetB
        print("Deduplication skipped due to --keepDup flag.")
    else:
        uniqueA, uniqueB = deduplicateInvariants(invSetA, invSetB, fusedIndex)
        print(f"After deduplication, {nameA} has {len(uniqueA)} unique invariants, {nameB} has {len(uniqueB)} unique invariants.")
        print(f"Unique invariants in {nameA}:")
        for idx, inv in enumerate(uniqueA):
            print(f"  {idx}: {formatInvariantAsEquation(inv)}")
        print(f"\nUnique invariants in {nameB}:")
        for idx, inv in enumerate(uniqueB):
            print(f"  {idx}: {formatInvariantAsEquation(inv)}")

    usedVarsAll = set().union(*(inv.getUsedVarNames() for inv in uniqueA + uniqueB))
    finalIndex = fusedIndex.restrict(usedVarsAll)

    sat, assignment = checkXor(uniqueA, uniqueB, finalIndex)
    if not sat:
        print(f"No discrepancy found (UNSAT). {nameA} and {nameB} are consistent.\n")
        return True

    print("DISCREPANCY FOUND: XOR is satisfiable.")
    reportSparseAssignment(assignment)

    violatedA = findViolations(uniqueA, assignment)
    violatedB = findViolations(uniqueB, assignment)
    satisfiesA = (len(violatedA) == 0)
    satisfiesB = (len(violatedB) == 0)

    if satisfiesA and not satisfiesB:
        print(f"=> Satisfies invariants of {nameA}, violates {nameB}.")
        reportViolations(nameB, uniqueB, violatedB, assignment)
    elif satisfiesB and not satisfiesA:
        print(f"=> Satisfies invariants of {nameB}, violates {nameA}.")
        reportViolations(nameA, uniqueA, violatedA, assignment)
    else:
        print("=> Unexpected: Possibly both sets are partially satisfied.")
        reportViolations(nameA, uniqueA, violatedA, assignment)
        reportViolations(nameB, uniqueB, violatedB, assignment)

    print()
    return False

def test_minimality(sol_files: List[str]) -> None:
    """
    Test each .sol file for minimality and report redundant invariants.
    """
    print("=== Testing Minimality of Invariant Sets ===")
    for sol_file in sol_files:
        name = get_base_name(sol_file)
        invs = parseSolFile(sol_file)
        if not invs:
            print(f"{name}: No invariants found.")
            continue
        
        print(f"Parsed {len(invs)} invariants from {name}")
        vIndex = VarIndex(sorted(set().union(*(inv.getUsedVarNames() for inv in invs))))
        redundant, total_time, check_sat_calls = checkMinimality(invs, vIndex)
        
        print(f"Minimality test took {total_time:.3f} seconds with {check_sat_calls} check-sat calls")
        if redundant:
            print(f"{name}: Found redundant invariants at indices {redundant}")
            for idx in redundant:
                print(f"  {idx}: {formatInvariantAsEquation(invs[idx])}")
        else:
            print(f"{name}: No redundant invariants found (appears minimal)")
        print()
        

def generate_summary(results: Dict[Tuple[str, str], bool], file_names: List[str]) -> None:
    """
    Generate a synthetic report of which files agree with which.
    """
    print("=== Consistency Summary ===")
    consistent_pairs = [(a, b) for (a, b), consistent in results.items() if consistent]
    discrepant_pairs = [(a, b) for (a, b), consistent in results.items() if not consistent]

    if not discrepant_pairs:
        print("All invariant sets are consistent with each other.")
        return

    agreement_groups: Dict[frozenset, List[str]] = {}
    for name in file_names:
        consistent_with = {b for a, b in consistent_pairs if a == name} | \
                         {a for a, b in consistent_pairs if b == name}
        consistent_with.add(name)
        key = frozenset(consistent_with)
        if key not in agreement_groups:
            agreement_groups[key] = []
        agreement_groups[key].append(name)

    if len(agreement_groups) == 1:
        print("All invariant sets are consistent with each other.")
    else:
        print("Invariant sets form the following consistency groups:")
        for idx, group in enumerate(agreement_groups.values(), 1):
            print(f"Group {idx}: {', '.join(sorted(group))}")
        print("\nFiles within each group are consistent with each other but discrepant with files in other groups.")

def main() -> None:
    # Parse arguments
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [--keepDup] [--compareSolutions | --testMinimality] <sol1> <sol2> [<sol3> ...]")
        print("  --compareSolutions: Pairwise compare solutions (default if no mode specified)")
        print("  --testMinimality: Test each solution for minimality")
        print("  --keepDup: Skip deduplication (only with --compareSolutions)")
        sys.exit(1)

    keep_duplicates = False
    compare_mode = False
    minimality_mode = False
    sol_files = sys.argv[1:]

    # Process flags
    if "--keepDup" in sys.argv:
        keep_duplicates = True
        sol_files = [f for f in sol_files if f != "--keepDup"]
    if "--compareSolutions" in sys.argv:
        compare_mode = True
        sol_files = [f for f in sol_files if f != "--compareSolutions"]
    if "--testMinimality" in sys.argv:
        minimality_mode = True
        sol_files = [f for f in sol_files if f != "--testMinimality"]

    # Validate mode selection
    if compare_mode and minimality_mode:
        print("Error: Cannot specify both --compareSolutions and --testMinimality")
        sys.exit(1)
    if not compare_mode and not minimality_mode:
        compare_mode = True  # Default to compare mode if no mode specified
    if len(sol_files) < 2 and compare_mode:
        print("Error: --compareSolutions requires at least 2 solution files")
        sys.exit(1)
    if len(sol_files) < 1:
        print("Error: At least 1 solution file required")
        sys.exit(1)

    file_names = [get_base_name(f) for f in sol_files]

    # Execute selected mode
    if compare_mode:
        results: Dict[Tuple[str, str], bool] = {}
        for i in range(len(sol_files)):
            for j in range(i + 1, len(sol_files)):
                nameA, nameB = file_names[i], file_names[j]
                consistent = compare_invariants(sol_files[i], sol_files[j], keep_duplicates)
                results[(nameA, nameB)] = consistent
        generate_summary(results, file_names)
    elif minimality_mode:
        test_minimality(sol_files)

if __name__ == "__main__":
    main()