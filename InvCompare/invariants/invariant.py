from typing import Dict, Set, List
from .varindex import VarIndex

class Invariant:
    """
    Represents a linear invariant of the form:
        sum( coeff[varName] * varName ) = const
    with a sparse representation in self.varCoeffs (dict) and an integer constant.
    """

    def __init__(self, varCoeffs: Dict[str, int], const: int) -> None:
        """
        varCoeffs: a mapping from varName -> nonzero integer coefficient
        const: an integer constant on the right-hand side
        """
        # Filter out zero coefficients, if any
        filtered = {v: c for v, c in varCoeffs.items() if c != 0}
        self.varCoeffs: Dict[str, int] = filtered
        self.const: int = const

    def getUsedVarNames(self) -> Set[str]:
        """Return the set of variable names used by this invariant."""
        return set(self.varCoeffs.keys())

    def getCoefficientVector(self, varIndex: VarIndex) -> List[int]:
        """
        Build a dense list of coefficients in the order of varIndex,
        followed by the constant. e.g. [coeff_for_v0, coeff_for_v1, ..., const].
        """
        size = varIndex.size()
        dense = [0] * size
        for varName, coeff in self.varCoeffs.items():
            idx = varIndex.getIndex(varName)
            dense[idx] = coeff
        dense.append(self.const)
        return dense

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Invariant):
            return False
        if self.const != other.const:
            return False
        if len(self.varCoeffs) != len(other.varCoeffs):
            return False
        for k, v in self.varCoeffs.items():
            if other.varCoeffs.get(k, 0) != v:
                return False
        return True

    def __hash__(self) -> int:
        items = tuple(sorted(self.varCoeffs.items()))
        return hash((items, self.const))
