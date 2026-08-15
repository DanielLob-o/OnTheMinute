// Pure session-history math for the EMOM timer, mirroring the built-in
// clipboard plugin's history module: parse/add/remove/clear over a plain
// array, persisted to disk by the QML FileView that owns this data.

function parseHistory(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  if (text === "") return []
  try {
    var parsed = JSON.parse(text)
    return Array.isArray(parsed) ? parsed : []
  } catch (e) {
    return []
  }
}

// Newest first. `session` shape: { finishedAt, minutes, exercises,
// roundsCompleted }. finishedAt is an ISO string so history survives
// round-tripping through JSON without a Date object.
function addSession(history, session, limit) {
  var next = [session].concat(history || [])
  var cap = limit > 0 ? limit : next.length
  return next.slice(0, cap)
}

function removeAt(history, index) {
  var next = (history || []).slice()
  if (index >= 0 && index < next.length) next.splice(index, 1)
  return next
}

function clearHistory() {
  return []
}

if (typeof module !== "undefined") {
  module.exports = {
    parseHistory: parseHistory,
    addSession: addSession,
    removeAt: removeAt,
    clearHistory: clearHistory
  }
}
