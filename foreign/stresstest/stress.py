#!/usr/bin/env python3
"""Stress test / verification for the ELA 16-bit LFSR probe.

Repeatedly invokes fcapz with a random trigger value, decodes the
resulting capture.json, and checks that every captured sample is the
expected LFSR step of the previous one. Runs for a wall-clock budget;
only failing captures are kept on disk.

LFSR recurrence (Fibonacci, taps 15, 14, 12, 3):
    lfsr_next[0]    = lfsr_in[15] ^ lfsr_in[14] ^ lfsr_in[12] ^ lfsr_in[3]
    lfsr_next[1:15] = lfsr_in[0:14]
"""

from __future__ import annotations

import argparse
import json
import random
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

LFSR_MASK = 0xFFFF


def lfsr_next(state: int) -> int:
    state &= LFSR_MASK
    fb = ((state >> 15) ^ (state >> 14) ^ (state >> 12) ^ (state >> 3)) & 1
    return ((state << 1) & LFSR_MASK) | fb


def parse_duration(s: str) -> float:
    """Parse '90', '90s', '30m', '1h30m', '8h', etc. into seconds."""
    s = s.strip().lower()
    if not s:
        raise argparse.ArgumentTypeError("empty duration")
    if re.fullmatch(r"\d+(?:\.\d+)?", s):
        return float(s)
    units = {"s": 1, "m": 60, "h": 3600, "d": 86400}
    total = 0.0
    pos = 0
    for m in re.finditer(r"(\d+(?:\.\d+)?)([smhd])", s):
        if m.start() != pos:
            raise argparse.ArgumentTypeError(f"bad duration: {s!r}")
        total += float(m.group(1)) * units[m.group(2)]
        pos = m.end()
    if pos != len(s) or total == 0.0:
        raise argparse.ArgumentTypeError(f"bad duration: {s!r}")
    return total


def fmt_secs(s: float) -> str:
    if s < 60:
        return f"{s:.1f}s"
    m, s = divmod(int(s), 60)
    if m < 60:
        return f"{m}m{s:02d}s"
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m{s:02d}s"


def coerce_sample(x) -> int:
    if isinstance(x, bool):
        raise TypeError("bool")
    if isinstance(x, int):
        return x & LFSR_MASK
    if isinstance(x, str):
        t = x.strip().lower()
        base = 16 if t.startswith("0x") else 2 if t.startswith("0b") else 10
        return int(t, base) & LFSR_MASK
    raise TypeError(type(x).__name__)


def _samples_from_record_list(lst) -> list[int] | None:
    """Decode the documented shape: [{"index": N, "value": V}, ...].

    Sorts by "index" so out-of-order records still verify correctly.
    """
    if not lst or not all(isinstance(x, dict) and "value" in x for x in lst):
        return None
    try:
        if all("index" in x for x in lst):
            ordered = sorted(lst, key=lambda x: x["index"])
        else:
            ordered = lst
        return [coerce_sample(x["value"]) for x in ordered]
    except (ValueError, TypeError):
        return None


def extract_samples(payload, expected_depth: int) -> list[int] | None:
    """Locate the sample sequence in a capture.json payload.

    Primary shape (per fcapz):  {"samples": [{"index": N, "value": V}, ...], ...}
    Falls back to a best-effort walk for any flat list of ints/hex-strings.
    """
    if isinstance(payload, dict) and isinstance(payload.get("samples"), list):
        decoded = _samples_from_record_list(payload["samples"])
        if decoded is not None:
            return decoded

    candidates: list[list] = []

    def walk(node):
        if isinstance(node, list):
            decoded = _samples_from_record_list(node)
            if decoded is not None:
                candidates.append(decoded)
                return
            if node and all(isinstance(x, (int, str)) and not isinstance(x, bool) for x in node):
                candidates.append(node)
            else:
                for x in node:
                    walk(x)
        elif isinstance(node, dict):
            for v in node.values():
                walk(v)

    walk(payload)
    candidates.sort(key=lambda c: (abs(len(c) - expected_depth), -len(c)))
    for c in candidates:
        try:
            return [coerce_sample(x) for x in c]
        except (ValueError, TypeError):
            continue
    return None


def verify_lfsr(samples: list[int]) -> tuple[bool, str]:
    if len(samples) < 2:
        return False, f"too few samples: {len(samples)}"
    for i in range(1, len(samples)):
        expected = lfsr_next(samples[i - 1])
        if samples[i] != expected:
            return False, (
                f"LFSR mismatch at index {i}: "
                f"prev=0x{samples[i-1]:04x} expected=0x{expected:04x} "
                f"got=0x{samples[i]:04x}"
            )
    return True, "ok"


def build_fcapz_cmd(args, trigger_value: int) -> list[str]:
    return [
        "fcapz",
        "--backend", args.backend,
        "--port", str(args.port),
        "--tap", args.tap,
        "capture",
        "--pretrigger", str(args.pretrigger),
        "--posttrigger", str(args.posttrigger),
        "--trigger-mode", "value_match",
        "--trigger-mask", f"0x{args.trigger_mask:04X}",
        "--trigger-value", f"{trigger_value}",
        "--sample-width", str(args.sample_width),
        "--depth", str(args.depth),
        "--out", str(args.capture_file),
        "--channel", str(args.channel),
    ]


def save_failure(run_dir: Path, tag: str, reason: str, capture_file: Path,
                 stderr: str, samples: list[int] | None, summary_log) -> None:
    if capture_file.exists():
        try:
            shutil.copy2(capture_file, run_dir / f"{tag}.json")
        except OSError as e:
            print(f"  [warn] could not copy {capture_file}: {e}", file=sys.stderr)

    with (run_dir / f"{tag}.log").open("w") as f:
        f.write(f"tag: {tag}\nreason: {reason}\n")
        if samples is not None and samples:
            head = " ".join(f"0x{s:04x}" for s in samples[:8])
            f.write(f"first samples: {head}\n")
        if stderr:
            f.write("--- fcapz stderr (tail) ---\n")
            f.write(stderr)
            if not stderr.endswith("\n"):
                f.write("\n")

    summary_log.write(f"{tag}\t{reason}\n")
    summary_log.flush()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--duration", type=parse_duration, default=parse_duration("1h"),
                   help="wall-clock budget, e.g. 90s, 30m, 1h, 8h (default: 1h)")
    p.add_argument("--backend", default="openocd")
    p.add_argument("--port", type=int, default=6666)
    p.add_argument("--tap", default="GW1NR-9C.tap")
    p.add_argument("--pretrigger", type=int, default=0)
    p.add_argument("--posttrigger", type=int, default=2047)
    p.add_argument("--trigger-mask", type=lambda s: int(s, 0), default=0xFFFF)
    p.add_argument("--sample-width", type=int, default=16)
    p.add_argument("--depth", type=int, default=2048)
    p.add_argument("--channel", type=int, default=0)
    p.add_argument("--capture-timeout", type=float, default=60.0,
                   help="per-capture timeout in seconds (default: 60)")
    p.add_argument("--capture-file", type=Path, default=Path("capture.json"),
                   help="path passed to fcapz --out (default: ./capture.json)")
    p.add_argument("--failure-dir", type=Path, default=Path("failures"),
                   help="directory to store failing captures (default: ./failures)")
    p.add_argument("--seed", type=int, default=None,
                   help="RNG seed for a reproducible trigger sequence")
    p.add_argument("--heartbeat", type=float, default=10.0,
                   help="seconds between pass-progress heartbeats (default: 10)")
    p.add_argument("--max-failures", type=int, default=100,
                   help="abort after this many failures (default: 100; 0 = no cap)")
    args = p.parse_args()

    if shutil.which("fcapz") is None:
        print("error: fcapz not found in PATH", file=sys.stderr)
        return 2

    if args.seed is not None:
        random.seed(args.seed)

    run_id = time.strftime("%Y%m%d_%H%M%S")
    run_dir = args.failure_dir / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    stop = False

    def handle_sigint(_signum, _frame):
        nonlocal stop
        if not stop:
            stop = True
            print("\n[interrupt] finishing current capture, then exiting...", flush=True)
        else:
            print("\n[interrupt] hard exit", flush=True)
            sys.exit(130)

    signal.signal(signal.SIGINT, handle_sigint)

    start = time.monotonic()
    deadline = start + args.duration
    last_heartbeat = start
    iteration = 0
    passed = 0
    failed = 0

    print(f"[start] duration={fmt_secs(args.duration)} "
          f"depth={args.depth} failures->{run_dir}/", flush=True)

    with (run_dir / "summary.log").open("a") as summary_log:
        summary_log.write(f"# run {run_id} duration={args.duration}s\n")
        summary_log.flush()

        while not stop and time.monotonic() < deadline:
            iteration += 1
            trigger_value = random.randint(1, LFSR_MASK)  # skip 0: LFSR fixed point
            tag = f"iter{iteration:06d}_trig{trigger_value:04x}"
            reason: str | None = None
            samples: list[int] | None = None
            stderr_tail = ""

            # Avoid verifying a stale capture if fcapz fails to write.
            try:
                args.capture_file.unlink()
            except FileNotFoundError:
                pass

            try:
                cmd = build_fcapz_cmd(args, trigger_value)
                cp = subprocess.run(
                    cmd,
                    capture_output=True, text=True,
                    timeout=args.capture_timeout,
                )
                stderr_tail = (cp.stderr or "")[-2000:]
                if cp.returncode != 0:
                    reason = f"fcapz exit {cp.returncode}"
                else:
                    try:
                        payload = json.loads(args.capture_file.read_text())
                    except FileNotFoundError:
                        reason = "capture.json missing after fcapz returned 0"
                    except json.JSONDecodeError as e:
                        reason = f"capture.json parse error: {e}"
                    else:
                        samples = extract_samples(payload, args.depth)
                        if samples is None:
                            reason = "could not locate a sample list in capture.json"
                        elif len(samples) != args.depth:
                            reason = f"sample count {len(samples)} != depth {args.depth}"
                        else:
                            ok, detail = verify_lfsr(samples)
                            if not ok:
                                reason = detail
            except subprocess.TimeoutExpired:
                reason = f"fcapz timed out after {args.capture_timeout}s"

            now = time.monotonic()
            elapsed = now - start

            if reason is None:
                passed += 1
                if now - last_heartbeat >= args.heartbeat:
                    rate = iteration / elapsed if elapsed > 0 else 0.0
                    eta = max(0.0, deadline - now)
                    print(f"[{fmt_secs(elapsed):>10}] iter={iteration} "
                          f"pass={passed} fail={failed} "
                          f"rate={rate:.2f}/s eta={fmt_secs(eta)}", flush=True)
                    last_heartbeat = now
            else:
                failed += 1
                save_failure(run_dir, tag, reason, args.capture_file,
                             stderr_tail, samples, summary_log)
                print(f"[{fmt_secs(elapsed):>10}] iter={iteration} "
                      f"trig=0x{trigger_value:04x} FAIL  pass={passed} fail={failed}",
                      flush=True)
                print(f"           reason: {reason}", flush=True)
                if args.max_failures > 0 and failed >= args.max_failures:
                    print(f"[abort] failure cap reached ({failed}/{args.max_failures})",
                          flush=True)
                    stop = True

    elapsed = time.monotonic() - start
    print(f"[done] iterations={iteration} pass={passed} fail={failed} "
          f"elapsed={fmt_secs(elapsed)} -> {run_dir}/", flush=True)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
