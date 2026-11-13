#!/usr/bin/env bash
# Runs every tests/headless/test_*.gd plus a boot smoke test of main.tscn.
# Exits non-zero if any test fails or the boot prints an error.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Tests get their own user data dir, so anything that saves (e.g. prestige)
# never touches the player's save.
TEST_DATA="$ROOT/.vdisplay/test-data"
mkdir -p "$TEST_DATA"
if command -v godot >/dev/null 2>&1; then
    GODOT=(env XDG_DATA_HOME="$TEST_DATA" godot)
else
    GODOT=(flatpak run --filesystem="$ROOT" --env=XDG_DATA_HOME="$TEST_DATA" org.godotengine.Godot)
fi

failed=0

for test in tests/headless/test_*.gd; do
    [ "$test" = "tests/headless/test_base.gd" ] && continue
    echo "== $test"
    output="$("${GODOT[@]}" --headless --path "$ROOT" --script "res://$test" 2>&1)"
    status=$?
    echo "$output" | grep -E "^(PASS|FAIL|RESULT)|SCRIPT ERROR|Parse Error"
    if [ $status -ne 0 ] || echo "$output" | grep -qE "^FAIL|SCRIPT ERROR|Parse Error"; then
        echo "!! $test failed (exit $status)"
        failed=1
    fi
done

echo "== boot main.tscn"
boot="$("${GODOT[@]}" --headless --path "$ROOT" --quit-after 120 2>&1)"
# Leaked-instance warnings at exit are engine noise, not boot errors.
boot_errors="$(echo "$boot" | grep -E "ERROR|SCRIPT ERROR" | grep -v "resources still in use at exit")"
if [ -n "$boot_errors" ]; then
    echo "$boot_errors"
    echo "!! boot printed errors"
    failed=1
else
    echo "PASS boot is clean"
fi

if [ $failed -ne 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi
echo "ALL TESTS PASSED"
