# solution/generic.py
from typing import List
from solution.tina import create_solution_for_tina
from solution.petrispot import create_solution_for_petrispot
from solution.greatspn import create_solution_for_greatspn

def create_solution(tool: str, log_path: str, model_path: str, mode: str) -> None:
    """
    Dispatch to the appropriate tool-specific solution creator.
    """
    if tool == "tina":
        create_solution_for_tina(log_path, model_path, mode)
    elif tool == "petrispot" or tool == "itstools" :
        create_solution_for_petrispot(log_path, model_path, mode)
    elif tool == "greatspn":
        create_solution_for_greatspn(log_path, model_path, mode)
    else:
        raise ValueError(f"Unknown tool: {tool}")