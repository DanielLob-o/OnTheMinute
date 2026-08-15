// Pure workout math for the EMOM timer: exercise list parsing, minute/second
// formatting, and countdown-phase detection. Kept Qt-free so it can be unit
// tested under node, same convention as the built-in plugins' Model.js files.

var DEFAULT_MINUTES = 10
var MAX_MINUTES = 180
var WARNING_WINDOW_SECONDS = 5

// One line per exercise, blank lines dropped, surrounding whitespace trimmed.
// "2 squats\n2 push ups\n2 kettlebell swings\n5 presses" -> 4 entries.
function parseExercises(text) {
  return String(text || "")
    .split("\n")
    .map(function(line) { return line.replace(/^\s+|\s+$/g, "") })
    .filter(function(line) { return line.length > 0 })
}

function exercisesToText(exercises) {
  return (exercises || []).join("\n")
}

// Whole minutes only, 1..MAX_MINUTES. Anything else falls back to
// DEFAULT_MINUTES so a bad/empty field never produces a zero-length workout.
function validMinutes(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^[0-9]+$/.test(text)) return DEFAULT_MINUTES
  var minutes = parseInt(text, 10)
  if (!isFinite(minutes) || minutes <= 0) return DEFAULT_MINUTES
  return Math.min(minutes, MAX_MINUTES)
}

// A workout needs at least one exercise and at least one minute to run.
function canStart(exercises, minutes) {
  return (exercises || []).length > 0 && validMinutes(minutes) > 0
}

// secondsLeft counts down from 59 to 0 within the current minute.
function isWarningPhase(secondsLeft) {
  return secondsLeft >= 0 && secondsLeft < WARNING_WINDOW_SECONDS
}

function isMinuteMark(secondsLeft) {
  return secondsLeft === 59
}

function formatClock(minutesLeft, secondsLeft) {
  var m = Math.max(0, minutesLeft)
  var s = Math.max(0, secondsLeft)
  return m + ":" + (s < 10 ? "0" : "") + s
}

// The whole list is the program for every minute — an EMOM repeats the same
// round each time, it doesn't rotate through one exercise per minute.
function exercisesLabel(exercises) {
  return (exercises || []).join(", ")
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_MINUTES: DEFAULT_MINUTES,
    MAX_MINUTES: MAX_MINUTES,
    WARNING_WINDOW_SECONDS: WARNING_WINDOW_SECONDS,
    parseExercises: parseExercises,
    exercisesToText: exercisesToText,
    validMinutes: validMinutes,
    canStart: canStart,
    isWarningPhase: isWarningPhase,
    isMinuteMark: isMinuteMark,
    formatClock: formatClock,
    exercisesLabel: exercisesLabel
  }
}
