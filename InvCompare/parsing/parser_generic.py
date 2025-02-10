# parser_generic.py

from typing import List
from invariants.invariant import Invariant
from .parser_tina import parseLogTina
from .parser_petrispot import parseLogPetriSpot

def parseLogGeneric(logPath: str, isPlaceFlow: bool = True) -> List[Invariant]:
    """
    Dispatcher that looks at file extension (or eventually content).
    isPlaceFlow: if True, parse P-flows or P-semi-flows from the log;
                 if False, parse T-flows or T-semi-flows.
    """
    if logPath.endswith(".tina"):
        return parseLogTina(logPath, isPlaceFlow)
    elif logPath.endswith(".petri32"):
        return parseLogPetriSpot(logPath, isPlaceFlow)
    else:
        raise ValueError(f"Unknown or unsupported format for file '{logPath}'")
