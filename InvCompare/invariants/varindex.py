from typing import List, Dict, Set


class VarIndex:
    """
    Bijection between variable names and consecutive integer indices [0..n-1].
    Provides fast name->index and index->name lookups.
    """

    def __init__(self, var_names: List[str]) -> None:
        """
        Build a VarIndex from a sorted list of unique variable names.
        The caller is responsible for ensuring uniqueness and sorting if desired.
        """
        self._name_to_index: Dict[str, int] = {}
        self._index_to_name: List[str] = []

        for i, nm in enumerate(var_names):
            self._name_to_index[nm] = i
            self._index_to_name.append(nm)

    def size(self) -> int:
        """Return the number of variables indexed."""
        return len(self._index_to_name)

    def getIndex(self, varName: str) -> int:
        """Return the integer index for a given variable name."""
        return self._name_to_index[varName]

    def getName(self, idx: int) -> str:
        """Return the variable name for a given index."""
        return self._index_to_name[idx]

    def fuse(self, other: 'VarIndex') -> 'VarIndex':
        """
        Create a new VarIndex that contains the union of this and the other VarIndex.
        The result is sorted lexicographically, with no duplication.
        Index assignments in the new object need not match self or other.
        """
        all_names = set(self._index_to_name).union(set(other._index_to_name))
        sorted_names = sorted(all_names)
        return VarIndex(sorted_names)

    def restrict(self, keep_vars: Set[str]) -> 'VarIndex':
        """
        Create a new VarIndex that only includes variables in `keep_vars`,
        discarding others. The result is sorted lexicographically.
        """
        filtered_names = [nm for nm in self._index_to_name if nm in keep_vars]
        filtered_names.sort()
        return VarIndex(filtered_names)
