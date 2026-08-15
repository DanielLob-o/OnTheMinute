// Pure workout math for the EMOM timer: exercise list parsing, minute/second
// formatting, and countdown-phase detection. Kept Qt-free so it can be unit
// tested under node, same convention as the built-in plugins' Model.js files.

var DEFAULT_MINUTES = 10
var MAX_MINUTES = 180
var WARNING_WINDOW_SECONDS = 5
var INITIAL_SECONDS_LEFT = 59

// One line per exercise, blank lines dropped, surrounding whitespace trimmed.
// "2 squats\n2 push ups\n2 kettlebell swings\n5 presses" -> 4 entries.
function parseExercises(text) {
  return String(text || "")
    .split("\n")
    .map(function(line) { return line.trim() })
    .filter(function(line) { return line.length > 0 })
}

function exercisesToText(exercises) {
  return (exercises || []).join("\n")
}

// Whole minutes only, 1..MAX_MINUTES. Anything else falls back to
// DEFAULT_MINUTES so a bad/empty field never produces a zero-length workout.
function validMinutes(value) {
  var text = String(value === undefined || value === null ? "" : value).trim()
  if (!/^[0-9]+$/.test(text)) return DEFAULT_MINUTES
  var minutes = parseInt(text, 10)
  if (!isFinite(minutes) || minutes <= 0) return DEFAULT_MINUTES
  return Math.min(minutes, MAX_MINUTES)
}

// A workout needs at least one exercise and at least one minute to run.
function canStart(exercises, minutes) {
  return (exercises || []).length > 0 && validMinutes(minutes) > 0
}

// secondsLeft counts down from 59 to 0 within the current minute. The
// warning window is the 5 seconds counting into the boundary — 5,4,3,2,1 —
// deliberately excluding 0: that tick is the minute landmark itself (see
// isMinuteLandmark), not another warning tick, so the two cues never both
// fire on the same second.
function isWarningPhase(secondsLeft) {
  return secondsLeft >= 1 && secondsLeft <= WARNING_WINDOW_SECONDS
}

// The tick where a minute rolls over — the landmark moment a running EMOM
// is really counting toward, so it gets its own larger, distinct cue
// instead of blending into the last-5-seconds warning ticks.
function isMinuteLandmark(secondsLeft) {
  return secondsLeft <= 0
}

function formatClock(minutesLeft, secondsLeft) {
  var m = Math.max(0, minutesLeft)
  var s = Math.max(0, secondsLeft)
  return m + ":" + (s < 10 ? "0" : "") + s
}

// Compact local-time display for a session's ISO finishedAt, e.g.
// "2026-08-15 20:32" — no seconds, no milliseconds, no T/Z.
function formatSessionDate(isoString) {
  var date = new Date(isoString)
  if (isNaN(date.getTime())) return String(isoString || "")

  function pad2(n) { return (n < 10 ? "0" : "") + n }

  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate()) +
    " " + pad2(date.getHours()) + ":" + pad2(date.getMinutes())
}

// The whole list is the program for every minute: an EMOM repeats the same
// round each time, it doesn't rotate through one exercise per minute. This
// is the one place that fact is encoded; callers just display the result.
function exercisesLabel(exercises) {
  return (exercises || []).join(", ")
}

function completionMessage(minutes) {
  return minutes + " minute" + (minutes === 1 ? "" : "s") + " done"
}

function formatHistorySummary(session) {
  var count = (session && session.exercises || []).length
  return formatSessionDate(session && session.finishedAt) + " · " +
    (session && session.minutes) + " min, " + count + " exercise" + (count === 1 ? "" : "s")
}

// Defensive parse of the live-state JSON BarWidget.qml writes on every tick
// and Overlay.qml reads back, mirroring History.parseHistory's shape so
// both watched-file readers in this plugin fail the same way.
function parseLiveState(raw) {
  var state = {}
  try { state = JSON.parse(raw || "{}") } catch (e) { state = {} }
  return {
    running: state.running === true,
    displayText: state.displayText || "EMOM",
    exercisesLabel: state.exercisesLabel || "",
    exercises: Array.isArray(state.exercises) ? state.exercises : []
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_MINUTES: DEFAULT_MINUTES,
    MAX_MINUTES: MAX_MINUTES,
    WARNING_WINDOW_SECONDS: WARNING_WINDOW_SECONDS,
    INITIAL_SECONDS_LEFT: INITIAL_SECONDS_LEFT,
    parseExercises: parseExercises,
    exercisesToText: exercisesToText,
    validMinutes: validMinutes,
    canStart: canStart,
    isWarningPhase: isWarningPhase,
    isMinuteLandmark: isMinuteLandmark,
    formatClock: formatClock,
    formatSessionDate: formatSessionDate,
    exercisesLabel: exercisesLabel,
    completionMessage: completionMessage,
    formatHistorySummary: formatHistorySummary,
    parseLiveState: parseLiveState
  }
}
