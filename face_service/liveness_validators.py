"""
Liveness validation module — server-side challenge verification, timing analysis,
replay detection, telemetry integrity, cross-verification, and confidence scoring.

All validation uses telemetry sent from the Flutter client (ML Kit face data)
plus OpenCV frame analysis. No heavy ML models.
"""
import math
import statistics
import time as _time
import os
import cv2
import numpy as np


# ──────────────────────────────────────────────────────────────────────────────
# Configurable thresholds (override via environment for tuning)
# ──────────────────────────────────────────────────────────────────────────────

THRESHOLDS = {
    # Blink
    "blink_closed": float(os.environ.get("LV_BLINK_CLOSED", "0.4")),
    "blink_open": float(os.environ.get("LV_BLINK_OPEN", "0.6")),
    "blink_min_count": int(os.environ.get("LV_BLINK_MIN", "1")),
    "blink_min_closed_frames": int(os.environ.get("LV_BLINK_MIN_CLOSED", "1")),
    # Head turns
    "turn_angle": float(os.environ.get("LV_TURN_ANGLE", "12")),
    # Smile
    "smile_threshold": float(os.environ.get("LV_SMILE_THRESH", "0.5")),
    "smile_min_frames": int(os.environ.get("LV_SMILE_FRAMES", "1")),
    "smile_rise_delta": float(os.environ.get("LV_SMILE_RISE", "0.15")),
    "smile_window": int(os.environ.get("LV_SMILE_WINDOW", "4")),
    # Look up
    "look_up_angle": float(os.environ.get("LV_LOOKUP_ANGLE", "-3")),
    # Timing
    "min_duration_ms": int(os.environ.get("LV_MIN_DURATION", "2000")),
    "min_interval_ms": int(os.environ.get("LV_MIN_INTERVAL", "200")),
    "timing_cv_min": float(os.environ.get("LV_TIMING_CV", "0.02")),
    "transition_min_ms": int(os.environ.get("LV_TRANSITION_MIN", "400")),
    # Scoring
    "confidence_threshold": float(os.environ.get("LV_CONFIDENCE", "0.55")),
    "face_presence_min": float(os.environ.get("LV_FACE_PRESENCE", "0.5")),
    # Integrity
    "max_angle_jump": float(os.environ.get("LV_MAX_ANGLE_JUMP", "90")),
    "max_blink_freq_per_sec": float(os.environ.get("LV_MAX_BLINK_FREQ", "3.0")),
    # Timestamp trust
    "ts_drift_ratio_max": float(os.environ.get("LV_TS_DRIFT_RATIO", "3.0")),
}


# ──────────────────────────────────────────────────────────────────────────────
# Scoring log — for threshold calibration
# ──────────────────────────────────────────────────────────────────────────────

_score_log = []

def log_score(event_type, scores, is_live, confidence):
    """Append to in-memory log for calibration analysis."""
    entry = {
        "type": event_type,
        "scores": scores,
        "is_live": is_live,
        "confidence": confidence,
    }
    _score_log.append(entry)
    if len(_score_log) > 200:
        _score_log.pop(0)
    print(f"[ScoreLog] {event_type}: live={is_live} conf={confidence:.3f} scores={scores}")

def get_score_log():
    """Return recent score log for diagnostics."""
    return list(_score_log)


# ──────────────────────────────────────────────────────────────────────────────
# Failure explainability — accumulates per-module verdicts
# ──────────────────────────────────────────────────────────────────────────────

class FailureReport:
    """Collects per-module pass/fail + reason for transparent diagnostics."""

    def __init__(self):
        self._modules = {}

    def record(self, module, passed, score, reason):
        self._modules[module] = {
            "passed": passed,
            "score": round(score, 3) if isinstance(score, float) else score,
            "reason": reason,
        }

    def failed_modules(self):
        return [m for m, v in self._modules.items() if not v["passed"]]

    def to_dict(self):
        return dict(self._modules)

    def primary_failure(self):
        for m, v in self._modules.items():
            if not v["passed"]:
                return f"{m}: {v['reason']}"
        return None


# ──────────────────────────────────────────────────────────────────────────────
# YuNet face detector (stronger than Haar cascade)
# ──────────────────────────────────────────────────────────────────────────────

_yunet_detector = None

def get_face_detector():
    """
    Load YuNet face detector if model is available, otherwise fall back to Haar.
    YuNet is faster and more accurate than Haar for security-sensitive checks.
    """
    global _yunet_detector
    if _yunet_detector is not None:
        return _yunet_detector

    model_path = os.path.join(os.path.dirname(__file__), "face_detection_yunet_2023mar.onnx")
    if os.path.exists(model_path):
        try:
            _yunet_detector = cv2.FaceDetectorYN.create(
                model_path, "", (320, 320),
                score_threshold=0.7, nms_threshold=0.3, top_k=5
            )
            print("[FaceDetector] YuNet loaded successfully")
            return _yunet_detector
        except Exception as e:
            print(f"[FaceDetector] YuNet load failed: {e}, using Haar fallback")

    return None  # Caller uses Haar fallback


def detect_faces_yunet(gray, yunet):
    """Detect faces using YuNet. Returns list of (x,y,w,h) tuples."""
    h, w = gray.shape[:2]
    yunet.setInputSize((w, h))
    # YuNet needs BGR or grayscale input
    img_3ch = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR) if len(gray.shape) == 2 else gray
    _, faces = yunet.detect(img_3ch)
    if faces is None:
        return []
    results = []
    for face in faces:
        x, y, fw, fh = int(face[0]), int(face[1]), int(face[2]), int(face[3])
        results.append((x, y, fw, fh))
    return results


def detect_faces(gray, face_cascade):
    """Detect faces using YuNet if available, Haar otherwise."""
    yunet = get_face_detector()
    if yunet is not None:
        faces = detect_faces_yunet(gray, yunet)
        if faces:
            return faces
    # Haar fallback
    detections = face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(60, 60))
    return [(x, y, w, h) for (x, y, w, h) in detections] if len(detections) > 0 else []


# ──────────────────────────────────────────────────────────────────────────────
# Challenge validation — ordered event detection using timestamps
# ──────────────────────────────────────────────────────────────────────────────

def validate_blink(telemetry):
    """
    Blink detection: eyes open → closed → open.
    Uses hysteresis thresholds and minimum closed frame count.
    Designed for ~1s capture intervals where a blink may span 1-2 frames.
    """
    if len(telemetry) < 2:
        return False, "Not enough frames for blink detection"

    min_closed = THRESHOLDS["blink_min_closed_frames"]
    blink_count = 0
    closed_run = 0
    eyes_were_closed = False

    for t in telemetry:
        left = t.get("leftEyeOpenProbability", 1.0)
        right = t.get("rightEyeOpenProbability", 1.0)
        avg_eye = (left + right) / 2.0

        if avg_eye < THRESHOLDS["blink_closed"]:
            closed_run += 1
            if closed_run >= min_closed:
                eyes_were_closed = True
        elif avg_eye > THRESHOLDS["blink_open"]:
            if eyes_were_closed:
                blink_count += 1
                eyes_were_closed = False
            closed_run = 0

    passed = blink_count >= THRESHOLDS["blink_min_count"]
    return passed, f"Detected {blink_count}/{THRESHOLDS['blink_min_count']} blinks (min_closed={min_closed})"


def validate_turn_left(telemetry):
    """Head Y rotation positive beyond threshold (front camera)."""
    max_angle = max((t.get("headEulerAngleY", 0) for t in telemetry), default=0)
    passed = max_angle > THRESHOLDS["turn_angle"]
    return passed, f"Max left angle: {max_angle:.1f}° (need >{THRESHOLDS['turn_angle']}°)"


def validate_turn_right(telemetry):
    """Head Y rotation negative beyond threshold."""
    min_angle = min((t.get("headEulerAngleY", 0) for t in telemetry), default=0)
    passed = min_angle < -THRESHOLDS["turn_angle"]
    return passed, f"Max right angle: {min_angle:.1f}° (need <-{THRESHOLDS['turn_angle']}°)"


def validate_smile(telemetry):
    """
    Robust smile detection with:
    - Sliding window: detect rise+peak pattern
    - Reject constant low-level smiles (no variance)
    - Temporal constraint: threshold exceeded in >= smile_min_frames
    """
    if len(telemetry) < 3:
        return False, "Not enough frames for smile detection"

    probs = [t.get("smilingProbability", 0) for t in telemetry]
    window = THRESHOLDS["smile_window"]
    rise_delta = THRESHOLDS["smile_rise_delta"]
    threshold = THRESHOLDS["smile_threshold"]
    min_frames = THRESHOLDS["smile_min_frames"]

    above_count = sum(1 for p in probs if p > threshold)

    # Sliding window: detect a rise->peak pattern
    has_rise_pattern = False
    for i in range(len(probs) - min(window, len(probs)) + 1):
        win = probs[i:i + window]
        if max(win) > threshold and (max(win) - min(win)) >= rise_delta:
            has_rise_pattern = True
            break

    # Reject constant low-level smile (no variance = spoofed)
    if len(probs) >= 3:
        prob_std = statistics.stdev(probs)
        if above_count >= min_frames and prob_std < 0.005:
            return False, f"Constant smile probability (std={prob_std:.3f}), suspicious"

    passed = above_count >= min_frames
    return passed, f"Smile in {above_count} frames (need >={min_frames})"


def validate_look_up(telemetry):
    """Head tilts up (negative X angle) beyond threshold."""
    min_x = min((t.get("headEulerAngleX", 0) for t in telemetry), default=0)
    passed = min_x < THRESHOLDS["look_up_angle"]
    return passed, f"Max up angle: {min_x:.1f}° (need <{THRESHOLDS['look_up_angle']}°)"


CHALLENGE_VALIDATORS = {
    "blink": validate_blink,
    "turn_left": validate_turn_left,
    "turn_right": validate_turn_right,
    "smile": validate_smile,
    "look_up": validate_look_up,
}


def _detect_action_window(telemetry, challenge, search_start=0):
    """
    Scan telemetry starting from search_start for the first occurrence of
    the challenge action. Returns (start_idx, end_idx) or None.
    This is the PRIMARY segmentation method.
    """
    n = len(telemetry)
    if challenge == "blink":
        closed_start = None
        for i in range(search_start, n):
            t = telemetry[i]
            avg_eye = (t.get("leftEyeOpenProbability", 1) + t.get("rightEyeOpenProbability", 1)) / 2
            if avg_eye < THRESHOLDS["blink_closed"]:
                if closed_start is None:
                    closed_start = i
            elif avg_eye > THRESHOLDS["blink_open"] and closed_start is not None:
                # Include ±2 frames of context so validator has enough data
                win_start = max(search_start, closed_start - 2)
                win_end = min(i + 2, n - 1)
                return win_start, win_end
            else:
                closed_start = None
        # Blink started but didn't reopen
        if closed_start is not None:
            win_start = max(search_start, closed_start - 2)
            return win_start, min(closed_start + 3, n - 1)
    elif challenge == "turn_left":
        for i in range(search_start, n):
            if telemetry[i].get("headEulerAngleY", 0) > THRESHOLDS["turn_angle"]:
                return max(0, i - 1), min(i + 2, n - 1)
    elif challenge == "turn_right":
        for i in range(search_start, n):
            if telemetry[i].get("headEulerAngleY", 0) < -THRESHOLDS["turn_angle"]:
                return max(0, i - 1), min(i + 2, n - 1)
    elif challenge == "smile":
        for i in range(search_start, n):
            if telemetry[i].get("smilingProbability", 0) > THRESHOLDS["smile_threshold"]:
                return i, min(i + 3, n - 1)
    elif challenge == "look_up":
        for i in range(search_start, n):
            if telemetry[i].get("headEulerAngleX", 0) < THRESHOLDS["look_up_angle"]:
                return max(0, i - 1), min(i + 2, n - 1)
    return None


def validate_challenge_sequence(challenges, telemetry):
    """
    Event-based multi-step challenge validation:
    1. For each challenge, scan FULL telemetry via _detect_action_window()
    2. Validate action using detected window's telemetry
    3. If no window → challenge failed
    4. Full sequence ordering check (ALL consecutive pairs)
    5. Transition timing between consecutive actions
    """
    if not challenges or not telemetry:
        return False, {}, "No challenges or telemetry"

    results = {}
    action_timestamps = []  # [(challenge, timestamp, start_idx)]
    search_from = 0  # enforce forward scanning

    for challenge in challenges:
        validator = CHALLENGE_VALIDATORS.get(challenge)
        if not validator:
            results[challenge] = {"passed": False, "reason": f"Unknown challenge: {challenge}"}
            continue

        # PRIMARY: detect action window in full telemetry from search_from
        window = _detect_action_window(telemetry, challenge, search_start=search_from)
        if window is None:
            results[challenge] = {"passed": False, "reason": "Action not detected in telemetry"}
            continue

        start_idx, end_idx = window
        window_telemetry = telemetry[start_idx:end_idx + 1]

        if len(window_telemetry) < 1:
            results[challenge] = {"passed": False, "reason": "Window too small"}
            continue

        passed, reason = validator(window_telemetry)
        results[challenge] = {
            "passed": passed,
            "reason": reason,
            "window": [start_idx, end_idx],
        }

        if passed:
            action_ts = telemetry[start_idx].get("timestamp", 0)
            action_timestamps.append((challenge, action_ts, start_idx))
            # Next challenge must start AFTER this window
            search_from = end_idx + 1

    # Full sequence ordering — check ALL consecutive pairs
    if len(action_timestamps) >= 2:
        for i in range(len(action_timestamps) - 1):
            curr_name, curr_ts, _ = action_timestamps[i]
            next_name, next_ts, _ = action_timestamps[i + 1]

            if curr_ts >= next_ts:
                results["_ordering"] = {
                    "passed": False,
                    "reason": f"'{curr_name}' (ts={curr_ts}) not before '{next_name}' (ts={next_ts})"
                }
                print(f"[Challenge] Ordering violation: {curr_name}@{curr_ts} >= {next_name}@{next_ts}")
                return False, results, f"Actions out of order: {curr_name} >= {next_name}"

            transition_ms = next_ts - curr_ts
            if transition_ms < THRESHOLDS["transition_min_ms"]:
                results["_transition"] = {
                    "passed": False,
                    "reason": f"{curr_name}->{next_name} too fast ({transition_ms}ms, need >={THRESHOLDS['transition_min_ms']}ms)"
                }
                print(f"[Challenge] Fast transition: {curr_name}->{next_name} = {transition_ms}ms")
                return False, results, f"Transition too fast: {curr_name}->{next_name}"

    all_passed = all(r["passed"] for k, r in results.items() if not k.startswith("_"))
    return all_passed, results, "All challenges passed" if all_passed else "Some challenges failed"


# ──────────────────────────────────────────────────────────────────────────────
# Telemetry integrity — reject impossible/fabricated values
# ──────────────────────────────────────────────────────────────────────────────

def validate_telemetry_integrity(telemetry):
    """
    Reject impossible telemetry values that indicate fabrication:
    - Impossible head angle jumps (>45° in one frame)
    - Unrealistic blink frequency (>3/sec)
    - Perfectly linear motion (R² too close to 1.0)
    - Inconsistent or non-monotonic timestamps
    """
    if len(telemetry) < 3:
        return True, "Not enough data for integrity check"

    issues = []

    # 1. Timestamp monotonicity
    timestamps = [t.get("timestamp", 0) for t in telemetry]
    for i in range(1, len(timestamps)):
        if timestamps[i] < timestamps[i-1]:
            issues.append("Non-monotonic timestamps")
            break

    # 2. Impossible angle jumps
    angles_y = [t.get("headEulerAngleY", 0) for t in telemetry]
    angles_x = [t.get("headEulerAngleX", 0) for t in telemetry]
    max_jump = THRESHOLDS["max_angle_jump"]

    for i in range(1, len(angles_y)):
        jump_y = abs(angles_y[i] - angles_y[i-1])
        jump_x = abs(angles_x[i] - angles_x[i-1])
        if jump_y > max_jump or jump_x > max_jump:
            issues.append(f"Impossible angle jump: Y={jump_y:.1f}° X={jump_x:.1f}°")
            break

    # 3. Unrealistic blink frequency
    total_duration_s = (timestamps[-1] - timestamps[0]) / 1000.0 if timestamps[-1] > timestamps[0] else 1
    blink_count = 0
    eyes_closed = False
    for t in telemetry:
        avg_eye = (t.get("leftEyeOpenProbability", 1) + t.get("rightEyeOpenProbability", 1)) / 2
        if avg_eye < 0.3 and not eyes_closed:
            eyes_closed = True
        elif avg_eye > 0.6 and eyes_closed:
            eyes_closed = False
            blink_count += 1

    blink_freq = blink_count / total_duration_s if total_duration_s > 0 else 0
    if blink_freq > THRESHOLDS["max_blink_freq_per_sec"]:
        issues.append(f"Unrealistic blink frequency: {blink_freq:.1f}/sec")

    # 4. Perfectly linear motion (indicates scripted values)
    if len(angles_y) >= 5:
        x_vals = list(range(len(angles_y)))
        # Simple R² calculation
        mean_x = statistics.mean(x_vals)
        mean_y = statistics.mean(angles_y)
        ss_tot = sum((y - mean_y) ** 2 for y in angles_y)
        if ss_tot > 0:
            slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(x_vals, angles_y)) / \
                    sum((x - mean_x) ** 2 for x in x_vals)
            intercept = mean_y - slope * mean_x
            ss_res = sum((y - (slope * x + intercept)) ** 2 for x, y in zip(x_vals, angles_y))
            r_squared = 1 - (ss_res / ss_tot)
            if r_squared > 0.99 and abs(slope) > 1:
                issues.append(f"Perfectly linear motion (R²={r_squared:.4f})")

    # 5. Impossible probability values (outside 0-1)
    for t in telemetry:
        for key in ["smilingProbability", "leftEyeOpenProbability", "rightEyeOpenProbability"]:
            v = t.get(key, 0)
            if v < 0 or v > 1.0:
                issues.append(f"Invalid probability: {key}={v}")
                break

    # 6. Duplicate timestamps (indicates injected/replayed data)
    unique_ts = len(set(timestamps))
    if unique_ts < len(timestamps) * 0.5:
        issues.append(f"Too many duplicate timestamps ({unique_ts}/{len(timestamps)} unique)")

    passed = len(issues) == 0
    return passed, "; ".join(issues) if issues else "Telemetry integrity OK"


# ──────────────────────────────────────────────────────────────────────────────
# Server-side timestamp trust correction
# ──────────────────────────────────────────────────────────────────────────────

def validate_timestamp_trust(telemetry, server_receive_ms):
    """
    Compare client-reported timestamps against server ingestion time.
    Detects reversed ordering, impossible speed, client/server drift.
    """
    if len(telemetry) < 3 or server_receive_ms <= 0:
        return True, "Skipped timestamp trust (insufficient data)"

    timestamps = [t.get("timestamp", 0) for t in telemetry]
    timestamps = [ts for ts in timestamps if ts > 0]
    if len(timestamps) < 3:
        return True, "No valid client timestamps"

    client_duration_ms = timestamps[-1] - timestamps[0]
    if client_duration_ms <= 0:
        return False, f"Client duration non-positive: {client_duration_ms}ms"

    # Server should have received the request AFTER the last client timestamp.
    # If client_last is far in the future vs server time, timestamps are fabricated.
    client_last = timestamps[-1]
    if client_last > server_receive_ms + 5000:
        return False, f"Client last timestamp {client_last} is in the future vs server {server_receive_ms}"

    # The client duration shouldn't be absurdly longer than the server wall-clock
    # difference between session issue and request receipt. We apply a generous ratio.
    # If we don't have session_issue_time, skip this check.
    max_ratio = THRESHOLDS["ts_drift_ratio_max"]

    # Check for duplicate timestamps (indicates injected data)
    unique_ts = len(set(timestamps))
    if unique_ts < len(timestamps) * 0.5:
        return False, f"Too many duplicate timestamps ({unique_ts}/{len(timestamps)} unique)"

    return True, f"Timestamp trust OK (client_span={client_duration_ms}ms, unique_ts={unique_ts}/{len(timestamps)})"


def validate_frame_count_vs_duration(telemetry, frames_count):
    """
    Verify that the number of frames is consistent with the reported duration.
    A real capture at 350-700ms intervals should produce a predictable frame count.
    Catches cases where someone sends many frames with compressed timestamps.
    """
    if len(telemetry) < 3:
        return True, "Not enough telemetry"

    timestamps = [t.get("timestamp", 0) for t in telemetry if t.get("timestamp", 0) > 0]
    if len(timestamps) < 3:
        return True, "No valid timestamps"

    duration_ms = timestamps[-1] - timestamps[0]
    if duration_ms <= 0:
        return False, "Zero duration"

    # At 350-700ms intervals, 16 frames should take 5.25-11.2 seconds
    # Allow generous bounds: 200ms min per frame, 1500ms max per frame
    min_expected_duration = frames_count * 200
    max_expected_duration = frames_count * 1500

    if duration_ms < min_expected_duration:
        return False, f"Too many frames for duration: {frames_count} frames in {duration_ms}ms (min expected {min_expected_duration}ms)"

    if duration_ms > max_expected_duration:
        return False, f"Duration too long for frame count: {frames_count} frames over {duration_ms}ms"

    return True, f"Frame/duration consistent: {frames_count} frames in {duration_ms}ms"


# ──────────────────────────────────────────────────────────────────────────────
# Cross-verify telemetry against frames (landmark check)
# ──────────────────────────────────────────────────────────────────────────────

def cross_verify_telemetry_frames(telemetry, gray_frames, face_cascade):
    """
    Verify that telemetry face positions roughly match actual face detection
    from frames. Detects cases where telemetry is fabricated but frames are real
    (or vice versa).
    """
    if len(telemetry) < 2 or len(gray_frames) < 2:
        return 0.5, "Not enough data for cross-verification"

    matches = 0
    checks = 0
    # Sample every 3rd frame to limit computation
    step = max(1, len(gray_frames) // 5)

    for idx in range(0, min(len(gray_frames), len(telemetry)), step):
        t = telemetry[idx]
        gray = gray_frames[idx]

        reported_w = t.get("faceWidth", 0)
        reported_h = t.get("faceHeight", 0)
        reported_cx = t.get("faceCenterX", 0)
        reported_cy = t.get("faceCenterY", 0)

        if reported_w <= 0 or reported_h <= 0:
            continue

        faces = detect_faces(gray, face_cascade)
        if not faces:
            checks += 1
            continue

        x, y, w, h = faces[0]
        actual_cx = x + w / 2
        actual_cy = y + h / 2

        checks += 1

        width_ratio = reported_w / w if w > 0 else 0
        height_ratio = reported_h / h if h > 0 else 0

        width_ok = 0.4 < width_ratio < 2.5
        height_ok = 0.4 < height_ratio < 2.5
        cx_ok = reported_cx <= 0 or abs(reported_cx - actual_cx) < w * 1.2
        cy_ok = reported_cy <= 0 or abs(reported_cy - actual_cy) < h * 1.2

        match_score = sum([width_ok, height_ok, cx_ok, cy_ok]) / 4
        matches += match_score

    if checks == 0:
        return 0.5, "No cross-verification possible"

    score = min(1.0, matches / checks)
    return round(score, 3), f"Cross-verified {matches:.0f}/{checks} frame-telemetry pairs"


# ──────────────────────────────────────────────────────────────────────────────
# Timing security — detect robotic or impossible patterns
# ──────────────────────────────────────────────────────────────────────────────

def validate_timing_patterns(telemetry):
    """
    Reject impossibly fast completion, suspiciously perfect timing,
    or identical timestamp spacing (bot behavior).
    """
    if len(telemetry) < 3:
        return False, "Not enough frames for timing analysis"

    timestamps = [t.get("timestamp", 0) for t in telemetry]
    timestamps = [ts for ts in timestamps if ts > 0]

    if len(timestamps) < 3:
        return True, "No timestamps available, skipping timing check"

    total_duration_ms = timestamps[-1] - timestamps[0]
    if total_duration_ms < THRESHOLDS["min_duration_ms"]:
        return False, f"Challenge completed too fast ({total_duration_ms}ms, need >={THRESHOLDS['min_duration_ms']}ms)"

    intervals = [timestamps[i+1] - timestamps[i] for i in range(len(timestamps)-1)]
    intervals = [iv for iv in intervals if iv > 0]

    if not intervals:
        return True, "Could not compute intervals"

    avg_interval = statistics.mean(intervals)

    if avg_interval < THRESHOLDS["min_interval_ms"]:
        return False, f"Frame rate too fast ({avg_interval:.0f}ms avg, suspicious)"

    if len(intervals) >= 3:
        interval_stddev = statistics.stdev(intervals)
        cv = interval_stddev / avg_interval if avg_interval > 0 else 0
        if cv < THRESHOLDS["timing_cv_min"]:
            return False, f"Timestamp spacing too uniform (CV={cv:.3f}, suspicious)"

    # Also check for arithmetic progression (attacker adds fixed jitter)
    if len(intervals) >= 4:
        sorted_intervals = sorted(intervals)
        diffs = [sorted_intervals[i+1] - sorted_intervals[i]
                 for i in range(len(sorted_intervals)-1)]
        if max(diffs) < 30:  # all intervals within 30ms of each other when sorted
            return False, f"Suspiciously uniform interval distribution (max_diff={max(diffs):.0f}ms)"

    return True, f"Timing OK (duration={total_duration_ms}ms, avg_interval={avg_interval:.0f}ms)"


# ──────────────────────────────────────────────────────────────────────────────
# Face depth/size consistency
# ──────────────────────────────────────────────────────────────────────────────

def analyze_face_depth_consistency(telemetry):
    """Detect flat screen replay via face size/position variance."""
    widths = [t.get("faceWidth", 0) for t in telemetry if t.get("faceWidth", 0) > 0]
    heights = [t.get("faceHeight", 0) for t in telemetry if t.get("faceHeight", 0) > 0]

    if len(widths) < 3:
        return 0.5, "Not enough face size data"

    width_cv = statistics.stdev(widths) / statistics.mean(widths) if statistics.mean(widths) > 0 else 0
    height_cv = statistics.stdev(heights) / statistics.mean(heights) if statistics.mean(heights) > 0 else 0
    avg_cv = (width_cv + height_cv) / 2

    cx_list = [t.get("faceCenterX", 0) for t in telemetry if t.get("faceCenterX", 0) > 0]
    cy_list = [t.get("faceCenterY", 0) for t in telemetry if t.get("faceCenterY", 0) > 0]

    pos_jitter = 0
    if len(cx_list) >= 3 and len(cy_list) >= 3:
        pos_jitter = (statistics.stdev(cx_list) + statistics.stdev(cy_list)) / 2

    size_score = min(1.0, avg_cv / 0.05) if avg_cv > 0 else 0.2
    jitter_score = min(1.0, pos_jitter / 15.0) if pos_jitter > 0 else 0.3
    score = 0.5 * size_score + 0.5 * jitter_score

    return round(score, 3), f"size_cv={avg_cv:.4f} pos_jitter={pos_jitter:.1f}"


# ──────────────────────────────────────────────────────────────────────────────
# Motion irregularity
# ──────────────────────────────────────────────────────────────────────────────

def _shannon_entropy(values, num_bins=10):
    """Compute Shannon entropy of a sequence (discretized into bins)."""
    if len(values) < 2:
        return 0.0
    arr = np.array(values, dtype=float)
    hist, _ = np.histogram(arr, bins=num_bins, density=True)
    hist = hist[hist > 0]
    if len(hist) == 0:
        return 0.0
    bin_width = (arr.max() - arr.min()) / num_bins if arr.max() != arr.min() else 1.0
    probs = hist * bin_width
    probs = probs[probs > 0]
    return float(-np.sum(probs * np.log2(probs)))


def analyze_motion_irregularity(telemetry):
    """
    Detect robotic vs natural motion using:
    - Irregularity ratio (stddev/mean of deltas)
    - Shannon entropy of angle deltas (low entropy = scripted motion)
    """
    angles_y = [t.get("headEulerAngleY", 0) for t in telemetry]
    angles_x = [t.get("headEulerAngleX", 0) for t in telemetry]

    if len(angles_y) < 3:
        return 0.5, "Not enough angle data"

    deltas_y = [abs(angles_y[i+1] - angles_y[i]) for i in range(len(angles_y)-1)]
    avg_delta_y = statistics.mean(deltas_y) if deltas_y else 0
    std_delta_y = statistics.stdev(deltas_y) if len(deltas_y) >= 2 else 0

    irregularity = std_delta_y / avg_delta_y if avg_delta_y > 0.5 else 0.5

    total_range_y = max(angles_y) - min(angles_y)
    total_range_x = max(angles_x) - min(angles_x)
    has_movement = total_range_y > 3 or total_range_x > 3

    # Shannon entropy of angle deltas — low entropy = scripted/replay
    entropy_y = _shannon_entropy(deltas_y)
    # Real motion: entropy > 1.5, scripted: < 0.5
    entropy_score = min(1.0, entropy_y / 2.0) if entropy_y > 0.3 else 0.15

    irregularity_score = min(1.0, irregularity) if has_movement else 0.3
    score = 0.5 * irregularity_score + 0.5 * entropy_score

    return round(score, 3), f"irregularity={irregularity:.2f} entropy={entropy_y:.2f} range_y={total_range_y:.1f}"


# ──────────────────────────────────────────────────────────────────────────────
# Optical flow
# ──────────────────────────────────────────────────────────────────────────────

def analyze_optical_flow(gray_frames):
    """Sparse optical flow analysis for replay detection."""
    if len(gray_frames) < 2:
        return 0.5, "Not enough frames"

    flow_magnitudes = []
    flow_angle_stds = []

    for i in range(1, min(len(gray_frames), 6)):
        prev, curr = gray_frames[i-1], gray_frames[i]
        features = cv2.goodFeaturesToTrack(prev, maxCorners=50, qualityLevel=0.3, minDistance=7)
        if features is None or len(features) < 5:
            continue

        next_pts, status, _ = cv2.calcOpticalFlowPyrLK(prev, curr, features, None)
        if next_pts is None:
            continue

        good_mask = status.flatten() == 1
        if good_mask.sum() < 3:
            continue

        old_pts = features[good_mask]
        new_pts = next_pts[good_mask]
        dx = new_pts[:, 0, 0] - old_pts[:, 0, 0]
        dy = new_pts[:, 0, 1] - old_pts[:, 0, 1]
        magnitudes = np.sqrt(dx**2 + dy**2)
        angles = np.arctan2(dy, dx)

        flow_magnitudes.append(float(np.mean(magnitudes)))
        if len(angles) >= 2:
            flow_angle_stds.append(float(np.std(angles)))

    if not flow_magnitudes:
        return 0.5, "Could not compute optical flow"

    avg_magnitude = statistics.mean(flow_magnitudes)
    avg_angle_std = statistics.mean(flow_angle_stds) if flow_angle_stds else 0

    magnitude_score = min(1.0, avg_magnitude / 5.0) if avg_magnitude > 0.5 else 0.3
    diversity_score = min(1.0, avg_angle_std / 1.0) if avg_angle_std > 0.1 else 0.2
    score = 0.5 * magnitude_score + 0.5 * diversity_score

    return round(score, 3), f"avg_flow={avg_magnitude:.2f} angle_std={avg_angle_std:.2f}"


# ──────────────────────────────────────────────────────────────────────────────
# Texture analysis
# ──────────────────────────────────────────────────────────────────────────────

def analyze_texture(gray_frames, face_cascade):
    """Laplacian variance on face regions for screen replay detection."""
    texture_scores = []

    for gray in gray_frames[:8]:  # limit for performance
        faces = detect_faces(gray, face_cascade)
        if faces:
            x, y, w, h = faces[0]
            face_roi = gray[y:y+h, x:x+w]
            if face_roi.size > 0:
                lap_var = float(cv2.Laplacian(face_roi, cv2.CV_64F).var())
                texture_scores.append(lap_var)

    if not texture_scores:
        return 0.5, "No face regions for texture analysis"

    avg_texture = statistics.mean(texture_scores)
    texture_std = statistics.stdev(texture_scores) if len(texture_scores) >= 2 else 0

    score = min(1.0, avg_texture / 500.0) if avg_texture > 50 else 0.15
    return round(score, 3), f"avg_texture={avg_texture:.0f} std={texture_std:.0f}"


# ──────────────────────────────────────────────────────────────────────────────
# Advanced replay detection
# ──────────────────────────────────────────────────────────────────────────────

def analyze_frame_diffs(gray_frames):
    """Frame difference analysis with frozen/duplicate frame detection."""
    if len(gray_frames) < 2:
        return 0.5, {}, "Not enough frames"

    diffs = []
    duplicate_count = 0
    frozen_sequences = 0
    consecutive_frozen = 0

    for i in range(1, len(gray_frames)):
        diff = cv2.absdiff(gray_frames[i-1], gray_frames[i])
        mean_diff = float(diff.mean())
        diffs.append(mean_diff)

        # Detect duplicated/frozen frames
        if mean_diff < 0.3:
            duplicate_count += 1
            consecutive_frozen += 1
            if consecutive_frozen >= 3:
                frozen_sequences += 1
        else:
            consecutive_frozen = 0

    avg_diff = statistics.mean(diffs)
    diff_std = statistics.stdev(diffs) if len(diffs) >= 3 else 0

    brightnesses = [float(g.mean()) for g in gray_frames]
    brightness_range = max(brightnesses) - min(brightnesses)

    # Moiré pattern detection: high-frequency energy in face region
    moire_score = 0
    for gray in gray_frames[:4]:
        # Apply FFT and check for periodic peaks (moiré signature)
        f_transform = np.fft.fft2(gray.astype(np.float32))
        f_shift = np.fft.fftshift(f_transform)
        magnitude = np.abs(f_shift)
        # High freq energy ratio
        h, w = gray.shape
        center_mask = np.zeros_like(magnitude, dtype=bool)
        ch, cw = h // 2, w // 2
        r = min(h, w) // 6
        center_mask[ch-r:ch+r, cw-r:cw+r] = True
        low_energy = magnitude[center_mask].sum()
        total_energy = magnitude.sum()
        high_ratio = 1 - (low_energy / total_energy) if total_energy > 0 else 0
        moire_score += high_ratio

    moire_score = float(moire_score / min(4, len(gray_frames)))

    # Compression artifact detection: block boundary artifacts
    jpeg_artifact_score = 0
    for gray in gray_frames[:3]:
        # Check for 8x8 block boundaries (JPEG artifact)
        h, w = gray.shape
        h_blocks = h // 8
        w_blocks = w // 8
        if h_blocks > 2 and w_blocks > 2:
            # Difference at block boundaries vs within blocks
            boundary_diffs = []
            inner_diffs = []
            for by in range(1, min(h_blocks, 10)):
                y_pos = by * 8
                boundary_diffs.append(float(np.abs(gray[y_pos].astype(float) - gray[y_pos-1].astype(float)).mean()))
                inner_diffs.append(float(np.abs(gray[y_pos+1].astype(float) - gray[y_pos+2].astype(float)).mean()))
            if boundary_diffs and inner_diffs:
                ratio = statistics.mean(boundary_diffs) / max(statistics.mean(inner_diffs), 0.01)
                if ratio > 2.0:  # Strong block boundaries = screen capture
                    jpeg_artifact_score += 1

    checks = {
        "avg_diff": round(float(avg_diff), 2),
        "diff_std": round(float(diff_std), 2),
        "brightness_range": round(float(brightness_range), 2),
        "static_frames": bool(avg_diff < 1.0),
        "uniform_diffs": bool(diff_std < 0.5 and avg_diff > 2.0),
        "brightness_flicker": bool(brightness_range > 100),
        "duplicate_frames": int(duplicate_count),
        "frozen_sequences": int(frozen_sequences),
        "moire_detected": bool(moire_score > 0.7),
        "compression_artifacts": bool(jpeg_artifact_score > 0),
    }

    # Scoring
    if avg_diff < 1.0:
        score = 0.1
    elif duplicate_count > len(diffs) * 0.3:
        score = 0.1  # too many duplicates
    elif frozen_sequences > 0:
        score = 0.15
    elif checks["uniform_diffs"]:
        score = 0.2
    elif checks["brightness_flicker"]:
        score = 0.2
    elif checks["moire_detected"]:
        score = 0.15
    elif checks["compression_artifacts"]:
        score = 0.25
    else:
        diff_score = min(1.0, avg_diff / 8.0)
        variety_score = min(1.0, diff_std / 3.0) if diff_std > 0 else 0.5
        score = 0.6 * diff_score + 0.4 * variety_score

    reason = "Frame analysis OK" if score > 0.3 else "Suspicious frame patterns detected"
    return round(score, 3), checks, reason


# ──────────────────────────────────────────────────────────────────────────────
# Face presence check
# ──────────────────────────────────────────────────────────────────────────────

def check_face_presence(gray_frames, face_cascade):
    """Check face is present in majority of frames (using YuNet or Haar)."""
    frames_with_face = 0
    for gray in gray_frames:
        faces = detect_faces(gray, face_cascade)
        if faces:
            frames_with_face += 1

    ratio = frames_with_face / len(gray_frames) if gray_frames else 0
    return ratio, f"Face in {frames_with_face}/{len(gray_frames)} frames"


def validate_face_embedding_consistency(gray_frames, face_cascade):
    """
    Check that face size is consistent across frames.
    A real 3D face held at natural distance has low size variance.
    A flat photo moved around has high size variance relative to position change.
    """
    face_sizes = []
    for gray in gray_frames:
        faces = detect_faces(gray, face_cascade)
        if faces:
            x, y, w, h = faces[0]
            face_sizes.append(w * h)  # face area

    if len(face_sizes) < 4:
        return 0.5, "Not enough faces detected for consistency check"

    # Convert all numpy int32 to Python float before statistics operations
    face_sizes_float = [float(size) for size in face_sizes]
    mean_size = statistics.mean(face_sizes_float)
    std_size = statistics.stdev(face_sizes_float)
    cv = std_size / mean_size if mean_size > 0 else 0

    # Real face: low CV (consistent size as person holds position)
    # Flat photo being moved: higher CV (size changes as angle changes)
    # But we want SOME variance (person is alive and moving slightly)
    # Too low CV = possibly frozen frame/video loop
    # Too high CV = photo being waved around

    if cv < 0.02:
        return 0.2, f"Face size too uniform (cv={cv:.3f}), possible video loop"
    if cv > 0.3:
        return 0.2, f"Face size too variable (cv={cv:.3f}), possible photo attack"

    score = min(1.0, cv / 0.1) if cv < 0.1 else max(0.3, 1.0 - (cv - 0.1) / 0.2)
    return round(score, 3), f"Face size consistency cv={cv:.3f}"


# ──────────────────────────────────────────────────────────────────────────────
# Composite confidence scoring
# ──────────────────────────────────────────────────────────────────────────────

def _clamp01(v):
    """Clamp a value to [0, 1]."""
    return max(0.0, min(1.0, float(v)))


def compute_liveness_confidence(
    challenge_passed,
    timing_passed,
    telemetry_valid,
    face_ratio,
    frame_diff_score,
    texture_score,
    depth_score,
    motion_score,
    flow_score,
    cross_verify_score,
    face_consistency_score=None,
    report=None,
):
    """
    Unified normalized scoring pipeline.
    Hard gates → normalized soft scores → weighted sum → calibration log.
    report: optional FailureReport for explainability.
    """
    if report is None:
        report = FailureReport()

    # Hard gates (record each in report)
    report.record("challenge", challenge_passed, 1.0 if challenge_passed else 0.0,
                  "Passed" if challenge_passed else "Challenge verification failed")
    report.record("timing", timing_passed, 1.0 if timing_passed else 0.0,
                  "Passed" if timing_passed else "Timing analysis suspicious")
    report.record("telemetry_integrity", telemetry_valid, 1.0 if telemetry_valid else 0.0,
                  "Passed" if telemetry_valid else "Fabricated telemetry detected")
    if not challenge_passed:
        return 0.0, "HIGH", "Challenge verification failed"
    if not timing_passed:
        return 0.0, "HIGH", "Timing analysis suspicious"
    if not telemetry_valid:
        return 0.0, "HIGH", "Telemetry integrity check failed"
    if face_ratio < THRESHOLDS["face_presence_min"]:
        report.record("face_presence", False, face_ratio, "Insufficient face presence")
        return 0.0, "HIGH", "Insufficient face presence"

    # Normalize all soft scores to [0, 1]
    scores = {
        "frame_diff": _clamp01(frame_diff_score),
        "texture": _clamp01(texture_score),
        "depth": _clamp01(depth_score),
        "motion": _clamp01(motion_score),
        "flow": _clamp01(flow_score),
        "face": _clamp01(face_ratio / 0.8),
        "cross_verify": _clamp01(cross_verify_score),
    }
    
    # Add face consistency score if provided
    if face_consistency_score is not None:
        scores["face_consistency"] = _clamp01(face_consistency_score)

    weights = {
        "frame_diff": 0.10,
        "texture": 0.08,  # Reduced from 0.12
        "depth": 0.15,
        "motion": 0.15,
        "flow": 0.13,
        "face": 0.06,  # Reduced from 0.10
        "cross_verify": 0.25,
        "face_consistency": 0.08,  # New validator
    }

    raw = sum(weights[k] * scores[k] for k in weights)
    confidence = round(_clamp01(raw), 3)

    # Record soft scores in report
    for k, v in scores.items():
        report.record(k, v >= 0.25, v, f"score={v:.3f}")

    if confidence >= 0.75:
        risk = "LOW"
    elif confidence >= 0.55:
        risk = "MEDIUM"
    else:
        risk = "HIGH"

    is_live = confidence >= THRESHOLDS["confidence_threshold"]
    reason = "Liveness verified" if is_live else "Insufficient liveness confidence"

    if not is_live:
        primary = report.primary_failure()
        if primary:
            reason = f"Insufficient confidence — {primary}"

    log_score("liveness", scores, is_live, confidence)

    return confidence, risk, reason
