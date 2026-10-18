// Pure geometry model, shared by QML and the Node regression tests.
// Counts windows, not columns. Stacked windows are ordered top to bottom.
function build(snapshot, screenName) {
  var empty = { scrolling: false, windows: [], index: -1, total: 0, label: "", workspace: null };
  if (!Array.isArray(snapshot) || snapshot.length !== 4) return empty;
  var workspaces = snapshot[0], clients = snapshot[1], active = snapshot[2], monitors = snapshot[3];
  if (!Array.isArray(workspaces) || !Array.isArray(clients) || !Array.isArray(monitors)) return empty;
  var monitor = monitors.find(function(m) { return screenName ? m.name === screenName : m.focused; });
  if (!monitor || !monitor.activeWorkspace) return empty;
  // A special-workspace overlay is not part of the strip beneath it.
  if (monitor.specialWorkspace && monitor.specialWorkspace.id) return empty;
  var workspace = workspaces.find(function(w) { return w.id === monitor.activeWorkspace.id; });
  if (!workspace || workspace.tiledLayout !== "scrolling") return empty;
  var scale = monitor.scale || 1;
  var rotated = Number(monitor.transform || 0) % 2 === 1;
  var width = (rotated ? monitor.height : monitor.width) / scale;
  var height = (rotated ? monitor.width : monitor.height) / scale;
  var windows = clients.filter(function(c) {
    return c.workspace && c.workspace.id === workspace.id && c.mapped !== false && !c.hidden
      && !c.floating && Array.isArray(c.at) && Array.isArray(c.size);
  }).sort(function(a, b) {
    return a.at[0] - b.at[0] || a.at[1] - b.at[1] || String(a.address).localeCompare(String(b.address));
  }).map(function(c) {
    var intersectionWidth = Math.max(0, Math.min(c.at[0] + c.size[0], monitor.x + width) - Math.max(c.at[0], monitor.x));
    var intersectionHeight = Math.max(0, Math.min(c.at[1] + c.size[1], monitor.y + height) - Math.max(c.at[1], monitor.y));
    var fraction = intersectionWidth * intersectionHeight / Math.max(1, c.size[0] * c.size[1]);
    return {
      address: c.address, title: c.title || c.class || "Window",
      focused: !!active && c.address === active.address,
      visibility: fraction <= 0 ? "offscreen" : (fraction >= 0.99 ? "visible" : "partial")
    };
  });
  var index = windows.findIndex(function(w) { return w.focused; });
  return { scrolling: true, windows: windows, index: index, total: windows.length,
    label: (index < 0 ? "–" : String(index + 1)) + "/" + windows.length, workspace: workspace.id };
}

function focusCommand(address) {
  // Only compositor-generated hexadecimal addresses can enter the Lua command.
  if (!/^0x[0-9a-f]+$/i.test(String(address))) return "";
  return 'hl.dsp.focus({ window = "address:' + address + '" })';
}

function slice(state, limit) {
  var count = Math.max(1, limit || 12);
  var start = Math.max(0, Math.min(state.total - count, state.index - Math.floor(count / 2)));
  return { windows: state.windows.slice(start, start + count), start: start,
    before: start > 0, after: start + count < state.total };
}

if (typeof module !== "undefined") module.exports = { build: build, focusCommand: focusCommand, slice: slice };
