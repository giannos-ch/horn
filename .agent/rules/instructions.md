# System Instructions for HORN AI Agent

## Project Overview
This repository contains the implementation of **HORN**, a higher-order logic programming language.

### Core Concepts
- **Language**: HORN (a higher-order logic programming language).
- **Semantics**: Based on the stable model semantics. Refer to:
  - [The Stable Model Semantics for Higher-Order Logic Programming](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/7CF694C23820C18DA68F185B09CB0598/S1471068424000231a.pdf/the-stable-model-semantics-for-higher-order-logic-programming.pdf)
- **Syntax**: Defined in `tree-sitter-horn/grammar.js`.
  - Supports clauses (`:-`), facts, and queries (`?-`).
  - Supports typed declarations (e.g., `const :: type`).
  - Includes constructs like existential quantifiers, implication, and logical connectives (`\/`, `/\`, `~`).

## Tech Stack
- **Implementation Language**: Crystal (>= 1.13.2)
- **Parser Generator**: Tree-sitter (via `tree-sitter-horn`)
- **Build Tools**: Shards, Make

## Coding Standards
- **Wait**: Always verify Crystal code with `crystal tool format` for standard formatting.
- **Style**: follow idiomatic Crystal practices.
- **Structure**: Place logic in `src/horn/`, keeping modules focused (e.g., `values/`, `types/`, `strategies/`).

## Testing
- **Location**: All tests must be written in the `spec/` directory.
- **Execution**: Run tests using the `crystal spec` command.

## Build & Run
- **Build**: Compile the project using `shards build`.
- **Run**: Execute the binary with `./bin/horn -f <horn_file>`.

## Key Files
- `src/horn.cr`: Main entry point.
- `shard.yml`: Project dependencies and configuration.
- `tree-sitter-horn/grammar.js`: The authoritative grammar definition.
