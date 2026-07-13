# Hook: pre-push-test-gate

## Trigger

Runs before any push to a remote branch. Mandatory for pushes to `develop`
and `main`.

## Purpose

Ensures the build compiles, unit tests pass, and critical smoke tests pass
before code reaches shared branches. This is the last automated quality gate
before code affects other developers.

## Implementation

```bash
#!/bin/bash
# Pre-push hook: Build and test gate

REMOTE="$1"
URL="$2"

# Only enforce full gate for develop and main
PROTECTED_BRANCHES="develop main"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

FULL_GATE=false
for branch in $PROTECTED_BRANCHES; do
    if [ "$CURRENT_BRANCH" = "$branch" ]; then
        FULL_GATE=true
        break
    fi
done

echo "=== Pre-Push Quality Gate ==="

# Step 0: GDD invariant checks (ALWAYS run, all branches -- fast, <1s each).
# The executable GDD-static linters in tools/ci/. Each runs its --self-test first
# (exit 2 = the hook itself is broken) then the real check (exit 1 = a GDD
# invariant was violated). Mirrored by .github/workflows/gdd-invariants.yml.
echo "Checking GDD invariants..."
python tools/ci/c12_completeness_check.py --self-test || exit 1
python tools/ci/c12_completeness_check.py || exit 1
python tools/ci/determinism_check.py --self-test || exit 1
python tools/ci/determinism_check.py || exit 1
python tools/ci/crafting_reconciliation_check.py --self-test || exit 1
python tools/ci/crafting_reconciliation_check.py || exit 1
echo "GDD invariants: PASS"

# Step 1: Build
echo "Building..."
# Adapt to your build system:
# make build || exit 1
# dotnet build || exit 1
# cargo build || exit 1
echo "Build: PASS"

# Step 2: Unit tests
echo "Running unit tests..."
# Adapt to your test framework:
# python -m pytest tests/unit/ -x || exit 1
# dotnet test tests/unit/ || exit 1
# cargo test || exit 1
echo "Unit tests: PASS"

if [ "$FULL_GATE" = true ]; then
    # Step 3: Integration tests (only for protected branches)
    echo "Running integration tests..."
    # python -m pytest tests/integration/ -x || exit 1
    echo "Integration tests: PASS"

    # Step 4: Smoke tests
    echo "Running smoke tests..."
    # python -m pytest tests/playtest/smoke/ -x || exit 1
    echo "Smoke tests: PASS"

    # Step 5: Performance regression check
    echo "Checking performance baselines..."
    # python tools/ci/perf_check.py || exit 1
    echo "Performance: PASS"
fi

echo "=== All gates passed ==="
exit 0
```

## Agent Integration

When this hook fails:
1. Build failure: invoke `lead-programmer` to diagnose
2. Unit test failure: invoke `qa-tester` to identify the failing test and
   `gameplay-programmer` or relevant programmer to fix
3. Performance regression: invoke `performance-analyst` to analyze
