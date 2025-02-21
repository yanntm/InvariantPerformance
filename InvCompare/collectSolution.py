#!/usr/bin/env python3
import argparse
import sys

from solution.generic import create_solution

def main() -> None:
    parser = argparse.ArgumentParser(description="Collect solutions from tool logs into .sol files.")
    parser.add_argument("--tool", required=True, choices=["tina", "itstools", "petrispot", "greatspn"],
                        help="Tool name to process.")
    parser.add_argument("--log", required=True, help="Path to the tool's log file.")
    parser.add_argument("--model", required=True, help="Path to the model folder.")
    parser.add_argument("--mode", required=True, choices=["pflows", "psemiflows", "tflows", "tsemiflows", "flows", "semiflows"],
                        help="Mode of invariant calculation.")
    
    args = parser.parse_args()
    create_solution(args.tool, args.log, args.model, args.mode)

if __name__ == "__main__":
    main()