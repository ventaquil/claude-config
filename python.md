# Python

Idiomatic Python + PEP 8. Correctness > any rule here; comment deviations.

## Tooling: uv for everything

- Use **uv** for everything: `uv venv`, `uv pip install` / `uv add`, `uvx <tool>`, `uv run script.py`, `uv run --with <pkg>` for one-offs.
- Never bare `pip` or `python -m venv` — system Python is uv-managed, externally-managed (PEP 668); `ensurepip` venvs are broken.
- CI: install uv (`astral-sh/setup-uv` or install script), run tools via `uvx` with pinned versions (e.g. `uvx ruff@0.15.20 check .`).

## Lint + Format: ruff

- ruff replaces black/flake8/isort — one tool, lint + format.
- Pin via uvx: `uvx ruff@<version> check .`, `uvx ruff@<version> format .`. CI job runs both, fails on diff/violation.
- Config lives in `pyproject.toml` `[tool.ruff]` — no `.flake8`/`setup.cfg`/separate `black`/`isort` config.

## Typing

- Public functions/methods: full type hints (params + return). Private helpers: hints where non-obvious.
- CI type-checks with mypy or pyright (pick one per repo, don't run both). Pinned via uvx, e.g. `uvx mypy@<version> .`.
- `Any` = escape hatch, not default; justify in comment when used.

## pytest conventions

- Plain `assert` — no `self.assertEqual` / unittest-style asserts.
- Repeated case shape → `@pytest.mark.parametrize`, not copy-pasted test functions.
- Shared setup → fixtures (`conftest.py`), not `setUp`/`tearDown` methods.
- Layout: `tests/` mirrors `src/` package structure; test files `test_*.py`; test fns `test_*`, name states scenario (`test_parse_empty_input`).
- Fixtures scoped as narrow as correct (`function` default); widen (`module`/`session`) only for expensive shared state.

## pyproject.toml: single config source

- All tool config in `pyproject.toml`: `[tool.ruff]`, `[tool.pytest.ini_options]`, `[tool.mypy]` (or `[tool.pyright]`). No scattered `.flake8`, `pytest.ini`, `mypy.ini`, `setup.cfg`.
- `[project]` table: name, version, deps, `requires-python`.

## Dependencies: uv groups + lockfile

- Split deps into uv dependency groups: `[dependency-groups]` `dev` (ruff, mypy/pyright, tooling), `test` (pytest, plugins). Runtime deps in `[project.dependencies]`.
- Install a group: `uv sync --group dev`.
- Commit `uv.lock` for applications (reproducible envs). Libraries: lockfile optional, `pyproject.toml` constraints are the contract.

## Checklist

- [ ] ruff check + format clean
- [ ] mypy/pyright clean
- [ ] `pytest` passes; new cases parametrized not copy-pasted
- [ ] Public fns typed
- [ ] No config outside `pyproject.toml`
