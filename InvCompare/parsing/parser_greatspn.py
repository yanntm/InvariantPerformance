# parsing/parser_greatspn.py
from typing import List, Dict
import os
from invariants.invariant import Invariant

def parse_greatspn_net(net_path: str) -> tuple[List[str], List[str]]:
    """
    Parse a GreatSPN .net file to extract place and transition names.
    
    Args:
        net_path: Path to the .net file (e.g., $MODELDIR/model.net).
    
    Returns:
        Tuple of (place_names, transition_names), indexed from 0 but matching 1-based file indices.
    """
    place_names: List[str] = []
    transition_names: List[str] = []
    
    with open(net_path, "r", encoding="utf-8") as f:
        # Skip first two lines
        next(f)  # |0|
        next(f)  # |
        
        # Read counts from 'f' line
        f_line = next(f).split()
        if f_line[0] != "f":
            raise ValueError("Expected 'f' line")
        num_places = int(f_line[2])
        num_transitions = int(f_line[4])
        
        # Parse place names (next num_places lines)
        for _ in range(num_places):
            line = next(f)
            place_name = line.split()[0]  # First token is the name
            place_names.append(place_name)
        
        # Parse transition names (accumulate until EOF)
        for line in f:
            if line[0].isspace():
                continue  # Skip lines starting with whitespace (arcs)
            transition_name = line.split()[0]
            transition_names.append(transition_name)
        
        # Check counts at EOF
        if len(place_names) != num_places:
            raise ValueError(f"Expected {num_places} places, got {len(place_names)}")
        if len(transition_names) != num_transitions:
            raise ValueError(f"Expected {num_transitions} transitions, got {len(transition_names)}")
    
    # Debug trace (comment out when working)
    # print(f"{len(place_names)} places")
    # for i, name in enumerate(place_names, 1):
    #     print(f"{i}:{name}")
    # print(f"{len(transition_names)} transitions")
    # for i, name in enumerate(transition_names, 1):
    #     print(f"{i}:{name}")
    
    return place_names, transition_names
  

# Replace parse_greatspn_invariants in parsing/parser_greatspn.py
def parse_greatspn_invariants(inv_file: str, names: List[str], is_place_flow: bool) -> List[Invariant]:
    """
    Parse a GreatSPN invariant file (.pba, .tba, .pin, .tin) into Invariants.
    
    Args:
        inv_file: Path to the invariant file (e.g., model.pba).
        names: List of place or transition names (indexed from 0, file uses 1-based).
        is_place_flow: True for place flows/semiflows, False for transition flows/semiflows.
    
    Returns:
        List of Invariant objects.
    """
    invariants: List[Invariant] = []
    
    with open(inv_file, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
        # First line is the number of invariants
        try:
            num_invariants = int(lines[0].strip())
        except (IndexError, ValueError):
            raise ValueError("Invalid invariant count in first line")
        
        # Parse each invariant line
        for i, line in enumerate(lines[1:], start=1):
            parts = line.strip().split()
            if not parts:  # Skip empty lines
                continue
            if parts[0] == "0" and i == num_invariants + 1:
                break  # Final '0' line
            
            try:
                num_terms = int(parts[0])
                if len(parts) != 1 + 2 * num_terms:
                    raise ValueError(f"Invalid term count in line {i}")
                
                var_coeffs: Dict[str, int] = {}
                for j in range(1, len(parts), 2):
                    coeff = int(parts[j])
                    index = int(parts[j + 1]) - 1  # Convert 1-based to 0-based
                    if index < 0 or index >= len(names):
                        print(f"Warning: Index {index + 1} out of range for {inv_file}, using 'unknown_{index + 1}'")
                        var_name = f"unknown_{index + 1}"
                    else:
                        var_name = names[index]
                    var_coeffs[var_name] = coeff
                
                # Constant is unknown for place flows, 0 for transition flows
                const = "?" if is_place_flow else 0
                invariants.append(Invariant(var_coeffs, const))
            except ValueError as e:
                raise ValueError(f"Error parsing invariant at line {i}: {e}")
        
        if len(invariants) != num_invariants:
            raise ValueError(f"Expected {num_invariants} invariants, got {len(invariants)}")
    
    return invariants