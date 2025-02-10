from typing import List, Tuple, Dict
from .varindex import VarIndex
from .invariant import Invariant

def deduplicateInvariants(
    setA: List[Invariant],
    setB: List[Invariant],
    fusedIndex: VarIndex
) -> Tuple[List[Invariant], List[Invariant]]:
    """
    Remove invariants that are exactly the same in both sets.
    Uses a dense signature (coefficient vector + const) for comparison.
    Return (uniqueA, uniqueB).
    """
    # Build a map: signature -> Invariant for A
    A_signatures: Dict[Tuple[int, ...], Invariant] = {}

    for invA in setA:
        sigA = tuple(invA.getCoefficientVector(fusedIndex))
        A_signatures[sigA] = invA

    usedA_signs = set()
    newB = []
    for invB in setB:
        sigB = tuple(invB.getCoefficientVector(fusedIndex))
        if sigB in A_signatures:
            usedA_signs.add(sigB)
        else:
            newB.append(invB)

    # Rebuild A excluding matched signatures
    newA = []
    for sigA, invA in A_signatures.items():
        if sigA not in usedA_signs:
            newA.append(invA)

    return (newA, newB)
