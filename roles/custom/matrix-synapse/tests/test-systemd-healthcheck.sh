#!/bin/sh

# SPDX-FileCopyrightText: 2026 MDAD project contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
helper="${script_dir}/../files/synapse/bin/systemd-healthcheck"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_bin="${tmp_dir}/bin"
legacy_bin="${tmp_dir}/legacy-bin"
busybox_modern_bin="${tmp_dir}/busybox-modern-bin"
busybox_applet_bin="${tmp_dir}/busybox-applet-bin"
integer_sleep_bin="${tmp_dir}/integer-sleep-bin"
no_sleep_bin="${tmp_dir}/no-sleep-bin"
mkdir -p "$fake_bin"
mkdir -p "$legacy_bin"
mkdir -p "$busybox_modern_bin"
mkdir -p "$busybox_applet_bin"
mkdir -p "$integer_sleep_bin"
mkdir -p "$no_sleep_bin"

real_timeout=$(command -v timeout)
real_cat=$(command -v cat)
real_sed=$(command -v sed)

cat > "${fake_bin}/docker" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FAKE_DOCKER_ARGS_LOG"
count=$("$REAL_CAT" "$FAKE_DOCKER_COUNT_FILE")
count=$((count + 1))
printf '%s\n' "$count" > "$FAKE_DOCKER_COUNT_FILE"
if [ "${FAKE_DOCKER_HANG:-0}" = 1 ]; then
	exec /bin/sleep 10
fi
if [ -n "${FAKE_DOCKER_DELAY_SECONDS:-}" ]; then
	/bin/sleep "$FAKE_DOCKER_DELAY_SECONDS"
fi
"$REAL_SED" -n "${count}p" "$FAKE_DOCKER_STATES_FILE"
EOF

cat > "${fake_bin}/sleep" <<'EOF'
#!/bin/sh
set -eu
if [ "${1:-}" = --version ]; then
	printf 'sleep (GNU coreutils) test double\n'
	exit 0
fi
if [ "${1:-}" = 0 ]; then
	exit 0
fi
if [ "${FAKE_SLEEP_FAIL:-0}" = 1 ]; then
	exit 1
fi
printf '%s\n' "$1" >> "$FAKE_SLEEP_LOG"
EOF

cat > "${integer_sleep_bin}/sleep" <<'EOF'
#!/bin/sh
set -eu
if [ "${1:-}" = --version ]; then
	printf 'portable integer sleep test double\n'
	exit 0
fi
case "${1:-}" in
	'' | *[!0-9]*) exit 1 ;;
esac
if [ "$1" -gt 0 ]; then
	printf '%s\n' "$1" >> "$FAKE_SLEEP_LOG"
fi
EOF

cat > "${legacy_bin}/timeout" <<'EOF'
#!/bin/sh
set -eu
if [ "${1:-}" != -t ]; then
	exit 125
fi
shift
duration=$1
shift
if [ "${1:-}" != -s ]; then
	exit 125
fi
shift
signal=$1
shift
exec "$REAL_TIMEOUT" -s "$signal" "${duration}s" "$@"
EOF

cat > "${busybox_modern_bin}/timeout" <<'EOF'
#!/bin/sh
set -eu
if [ "${1:-}" = --help ]; then
	printf 'BusyBox test double\n'
	exit 0
fi
if [ "${1:-}" != -s ]; then
	exit 125
fi
shift
signal=$1
shift
duration=$1
shift
case "$duration" in
	'' | *[!0-9]*) exit 125 ;;
esac
exec "$REAL_TIMEOUT" -s "$signal" "${duration}s" "$@"
EOF

cat > "${busybox_applet_bin}/busybox" <<'EOF'
#!/bin/sh
set -eu
applet=${1:-}
shift
case "$applet" in
	timeout)
		if [ "${1:-}" = --help ]; then
			printf 'BusyBox timeout test double\n'
			exit 0
		fi
		if [ "${1:-}" != -s ]; then
			exit 125
		fi
		shift
		signal=$1
		shift
		duration=$1
		shift
		case "$duration" in
			'' | *[!0-9]*) exit 125 ;;
		esac
		exec "$REAL_TIMEOUT" -s "$signal" "${duration}s" "$@"
		;;
	sleep)
		case "${1:-}" in
			'' | *[!0-9]*) exit 1 ;;
		esac
		if [ "$1" -gt 0 ]; then
			printf '%s\n' "$1" >> "$FAKE_SLEEP_LOG"
			if [ "${FAKE_BUSYBOX_SLEEP_REAL:-0}" = 1 ]; then
				/bin/sleep "$1"
			fi
		fi
		;;
	*) exit 125 ;;
esac
EOF

ln -s "$real_timeout" "${no_sleep_bin}/timeout"

chmod +x "${fake_bin}/docker" "${fake_bin}/sleep" "${integer_sleep_bin}/sleep" "${legacy_bin}/timeout" "${busybox_modern_bin}/timeout" "${busybox_applet_bin}/busybox"

export FAKE_DOCKER_COUNT_FILE="${tmp_dir}/docker-count"
export FAKE_DOCKER_STATES_FILE="${tmp_dir}/docker-states"
export FAKE_SLEEP_LOG="${tmp_dir}/sleep-log"
export FAKE_DOCKER_ARGS_LOG="${tmp_dir}/docker-args-log"
export REAL_TIMEOUT="$real_timeout"
export REAL_CAT="$real_cat"
export REAL_SED="$real_sed"

reset_fakes() {
	printf '0\n' > "$FAKE_DOCKER_COUNT_FILE"
	: > "$FAKE_SLEEP_LOG"
	: > "$FAKE_DOCKER_ARGS_LOG"
	printf '%b' "$1" > "$FAKE_DOCKER_STATES_FILE"
}

fail() {
	printf 'systemd-healthcheck test failed: %s\n' "$1" >&2
	exit 1
}

reset_fakes 'healthy\n'
output=$(PATH="${fake_bin}:$PATH" "$helper" matrix-synapse 3 1 3 30 /usr/bin/env "${fake_bin}/docker") || fail 'immediate health success returned non-zero'
[ "$(cat "$FAKE_DOCKER_COUNT_FILE")" -eq 1 ] || fail 'immediate success did not use exactly one probe'
[ ! -s "$FAKE_SLEEP_LOG" ] || fail 'immediate success slept unexpectedly'
printf '%s\n' "$output" | grep -q 'passed after .*final status: healthy' || fail 'immediate success log lacks elapsed/final state'
grep -Fxq 'inspect --format={{.State.Health.Status}} matrix-synapse' "$FAKE_DOCKER_ARGS_LOG" || fail 'probe used unexpected docker inspect arguments'

reset_fakes 'healthy\n'
output=$(PATH="${fake_bin}:$PATH" "$helper" matrix-synapse 03 01 03 030 "${fake_bin}/docker") || fail 'leading-zero numeric inputs returned non-zero'
printf '%s\n' "$output" | grep -q 'attempt 1/3' || fail 'leading-zero numeric inputs were not canonicalized'

reset_fakes 'healthy\n'
output=$(PATH="${legacy_bin}:${fake_bin}:$PATH" "$helper" matrix-synapse 1 1 1 30 "${fake_bin}/docker") || fail 'legacy timeout interface returned non-zero'
printf '%s\n' "$output" | grep -q 'final status: healthy' || fail 'legacy timeout interface did not execute the probe'

reset_fakes 'healthy\n'
output=$(PATH="${busybox_modern_bin}:${fake_bin}:$PATH" "$helper" matrix-synapse 1 1 1 30 "${fake_bin}/docker") || fail 'modern BusyBox timeout interface returned non-zero'
printf '%s\n' "$output" | grep -q 'final status: healthy' || fail 'modern BusyBox timeout interface did not execute the probe'

output=$(PATH="$busybox_applet_bin" "$helper" matrix-synapse 1 1 1 30 /bin/sh -c 'printf healthy') || fail 'BusyBox applet fallback returned non-zero'
printf '%s\n' "$output" | grep -q 'final status: healthy' || fail 'BusyBox applet fallback did not execute the probe'

reset_fakes 'starting\nhealthy\n'
output=$(FAKE_BUSYBOX_SLEEP_REAL=1 PATH="$busybox_applet_bin" "$helper" matrix-synapse 2 1 2 30 "${fake_bin}/docker") || fail 'BusyBox applet sleep fallback returned non-zero'
[ "$(cat "$FAKE_DOCKER_COUNT_FILE")" -eq 2 ] || fail 'BusyBox applet sleep fallback did not reach the second probe'
[ "$(cat "$FAKE_SLEEP_LOG")" = 1 ] || fail 'BusyBox applet sleep fallback did not use an integer ceiling'
printf '%s\n' "$output" | grep -q 'attempt 2/2' || fail 'BusyBox applet sleep fallback did not report second-attempt success'

reset_fakes 'starting\nhealthy\n'
output=$(PATH="${integer_sleep_bin}:${fake_bin}:$PATH" "$helper" matrix-synapse 2 1 2 30 "${fake_bin}/docker") || fail 'integer-only direct sleep returned non-zero'
[ "$(cat "$FAKE_SLEEP_LOG")" = 1 ] || fail 'integer-only direct sleep did not use an integer ceiling'

reset_fakes 'starting\nstarting\nhealthy\n'
output=$(PATH="${fake_bin}:$PATH" "$helper" matrix-synapse 3 1 3 30 "${fake_bin}/docker") || fail 'final-attempt health success returned non-zero'
[ "$(cat "$FAKE_DOCKER_COUNT_FILE")" -eq 3 ] || fail 'final-attempt success did not use all probes'
[ "$(wc -l < "$FAKE_SLEEP_LOG")" -eq 2 ] || fail 'final-attempt success did not sleep exactly N-1 times'
grep -Eq '^[0-9]+\.[0-9]{3}$' "$FAKE_SLEEP_LOG" || fail 'GNU sleep did not receive fractional fixed-cadence durations'
printf '%s\n' "$output" | grep -q 'attempt 3/3' || fail 'final-attempt success log has the wrong attempt'

reset_fakes 'starting\nstarting\nunhealthy\n'
set +e
output=$(PATH="${fake_bin}:$PATH" "$helper" matrix-synapse 3 1 3 30 "${fake_bin}/docker" 2>&1)
exit_code=$?
set -e
[ "$exit_code" -eq 1 ] || fail 'exhausted readiness did not return 1'
[ "$(cat "$FAKE_DOCKER_COUNT_FILE")" -eq 3 ] || fail 'exhausted readiness did not use all probes'
[ "$(wc -l < "$FAKE_SLEEP_LOG")" -eq 2 ] || fail 'exhausted readiness slept after the final attempt'
printf '%s\n' "$output" | grep -q 'failed after .*3 attempts.*final status: unhealthy' || fail 'exhaustion log lacks elapsed/final state'
if printf '%s\n' "$output" | grep -q 'waiting after .*attempt 3/3'; then
	fail 'exhaustion falsely logged a wait after the final attempt'
fi
[ "$(printf '%s\n' "$output" | grep -c 'waiting after')" -eq 1 ] || fail 'unchanged-state progress was not throttled'

reset_fakes 'starting\nhealthy\n'
set +e
output=$(FAKE_SLEEP_FAIL=1 PATH="${fake_bin}:$PATH" "$helper" matrix-synapse 2 1 2 30 "${fake_bin}/docker" 2>&1)
exit_code=$?
set -e
[ "$exit_code" -eq 2 ] || fail 'failed sleep did not return 2'
[ "$(cat "$FAKE_DOCKER_COUNT_FILE")" -eq 1 ] || fail 'failed sleep allowed another probe'
printf '%s\n' "$output" | grep -q 'sleep command failed before attempt 2/2' || fail 'failed sleep diagnostic is missing'

set +e
output=$(PATH="$no_sleep_bin" "$helper" matrix-synapse 1 1 1 30 /bin/true 2>&1)
exit_code=$?
set -e
[ "$exit_code" -eq 2 ] || fail 'missing sleep provider did not return 2'
printf '%s\n' "$output" | grep -q 'host command `sleep`' || fail 'missing sleep provider diagnostic is missing'

set +e
output=$("$helper" matrix-synapse 3 0 3 30 /usr/bin/env docker 2>&1)
exit_code=$?
set -e
[ "$exit_code" -eq 2 ] || fail 'invalid interval did not return 2'
printf '%s\n' "$output" | grep -q 'INTERVAL_SECONDS must be a positive integer' || fail 'invalid interval diagnostic is missing'

reset_fakes 'starting\n'
start_nanoseconds=$(date +%s%N)
set +e
output=$(FAKE_DOCKER_HANG=1 PATH="${fake_bin}:$PATH" "$helper" matrix-synapse 1 1 1 30 "${fake_bin}/docker" 2>&1)
exit_code=$?
set -e
elapsed_milliseconds=$((( $(date +%s%N) - start_nanoseconds ) / 1000000))
[ "$exit_code" -eq 1 ] || fail 'bounded hanging probe did not return 1'
printf '%s\n' "$output" | grep -q 'unavailable(docker-inspect-exit-' || fail 'bounded hanging probe did not report the inspect failure'
[ "$elapsed_milliseconds" -lt 4000 ] || fail "bounded hanging probe exceeded its budget (${elapsed_milliseconds}ms)"

printf 'systemd-healthcheck tests passed\n'
