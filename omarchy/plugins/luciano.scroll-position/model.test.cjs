const assert = require('node:assert/strict');
const { test } = require('node:test');
const { build, focusCommand, slice, parseSnapshot } = require('./Model.js');

function fixture() {
  const window = (address, x, y = 30) => ({ address, at: [x, y], size: [400, 600],
    workspace: { id: 9 }, mapped: true, floating: false, hidden: false, title: address });
  return [[{ id: 9, tiledLayout: 'scrolling' }],
    [window('0xc', 700), window('0xa', -450), window('0xb', 0)],
    { address: '0xb' }, [{ name: 'eDP-1', focused: true, activeWorkspace: { id: 9 },
      x: 0, y: 0, width: 1000, height: 800, scale: 1, transform: 0 }]];
}

test('orders actual window geometry, highlights focus and classifies viewport intersection', () => {
  const result = build(fixture(), 'eDP-1');
  assert.equal(result.label, '2/3');
  assert.deepEqual(result.windows.map(w => w.address), ['0xa', '0xb', '0xc']);
  assert.deepEqual(result.windows.map(w => w.visibility), ['offscreen', 'visible', 'partial']);
  assert.deepEqual(result.windows.map(w => w.focused), [false, true, false]);
});
test('ignores floating, hidden, unmapped and other-workspace windows', () => {
  const data = fixture();
  for (const patch of [{floating: true}, {hidden: true}, {mapped: false}, {workspace: {id: 5}}])
    data[1].push({...data[1][0], ...patch});
  assert.equal(build(data, 'eDP-1').total, 3);
});
test('counts stacked windows in top-to-bottom order within a column', () => {
  const data = fixture();
  data[1][0].at = [0, 650];
  assert.deepEqual(build(data, 'eDP-1').windows.map(w => w.address), ['0xa', '0xb', '0xc']);
});
test('hides in dwindle, missing monitors, malformed snapshots and special overlays', () => {
  assert.equal(build([], 'eDP-1').scrolling, false);
  assert.equal(build([null, null, null, null], 'eDP-1').scrolling, false);
  assert.equal(build(fixture(), 'missing').scrolling, false);
  const data = fixture();
  data[0][0].tiledLayout = 'dwindle';
  assert.equal(build(data, 'eDP-1').scrolling, false);
  data[0][0].tiledLayout = 'scrolling';
  data[3][0].specialWorkspace = {id: -99};
  assert.equal(build(data, 'eDP-1').scrolling, false);
});
test('empty workspace and floating focus do not invent a focused tiled window', () => {
  const data = fixture();
  data[2] = {address: '0x1234'};
  assert.equal(build(data, 'eDP-1').label, '–/3');
  data[1] = [];
  assert.equal(build(data, 'eDP-1').label, '–/0');
});
test('accounts for scaled rotated monitors and global coordinate offsets', () => {
  const data = fixture();
  Object.assign(data[3][0], {x: 1000, width: 1600, height: 2000, scale: 2, transform: 1});
  data[1].forEach(w => { w.at[0] += 1000; });
  assert.deepEqual(build(data, 'eDP-1').windows.map(w => w.visibility), ['offscreen', 'visible', 'partial']);
});
test('each screen uses its own workspace, not the globally focused monitor', () => {
  const data = fixture();
  data[3].push({...data[3][0], name: 'DP-1', focused: false, activeWorkspace: {id: 5}});
  data[0].push({id: 5, tiledLayout: 'dwindle'});
  assert.equal(build(data, 'DP-1').scrolling, false);
  assert.equal(build(data, '').scrolling, true);
});
test('bounds marker strip while keeping focus and true total', () => {
  const state = {windows: Array.from({length: 30}, (_, i) => i), index: 19, total: 30};
  const result = slice(state, 12);
  assert.equal(result.windows.length, 12);
  assert.ok(result.windows.includes(19));
  assert.equal(result.before, true);
  assert.equal(result.after, true);
  assert.deepEqual(slice({windows: [], index: -1, total: 0}, 12).windows, []);
});
test('click focus accepts only a hexadecimal compositor address', () => {
  assert.equal(focusCommand('0xabc'), 'hl.dsp.focus({ window = "address:0xabc" })');
  assert.equal(focusCommand('0xabc\" }); os.execute(\"bad'), '');
});
test('parses native batch JSON including escaped quotes and brackets in titles', () => {
  const data = fixture();
  data[1][0].title = 'A "title" with [brackets], {braces}, \\ and\nnewlines';
  assert.deepEqual(parseSnapshot(data.map(x => JSON.stringify(x, null, 2)).join('\n\n\n')), data);
});
test('rejects incomplete and non-JSON batch responses', () => {
  for (const text of ['', '[]\n{}', 'error', '[]\n[]\n{}\n[', '[] [] {} [] trailing'])
    assert.throws(() => parseSnapshot(text));
});
