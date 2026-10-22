// SETUP-ONLY synthetic mocks. These tests are not an audit or evidence about assessed source.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { PINNED, transformWorkflow, sha256, createScheduler, createValidator,
  executeWorkflow, readNativeResult, resolveAgentType, runNativeWorkflow } from './tob-native-workflow-adapter.mjs';

const upstream = '/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins';
const ajvPath = '/Users/hishamel-husseini/.npm/_npx/d274a05a00f9ae59/node_modules/ajv/package.json';
const validator = createValidator(ajvPath);
const load = name => fs.readFileSync(path.join(upstream, PINNED[name].plugin, 'workflows', PINNED[name].file), 'utf8');
const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

test('only exact export declaration is transformed; assessed JS cannot be executed by host', async () => {
  for (const name of Object.keys(PINNED)) {
    const source = load(name);
    assert.equal(sha256(source), PINNED[name].sha256);
    assert.equal(transformWorkflow(source), source.replace('export const meta', 'const meta'));
  }
  assert.throws(() => transformWorkflow('throw new Error("not allowed")'), /exactly one/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tob-adapter-setup-'));
  const injected = path.join(dir, 'untrusted.js');
  fs.writeFileSync(injected, 'export const meta={}; throw new Error("must never execute");');
  await assert.rejects(runNativeWorkflow({ workflow: 'audit-context', workflowFile: injected,
    workspace: dir, outputDir: path.join(dir, 'never-created') }), /source hash mismatch/);
  assert.equal(fs.existsSync(path.join(dir, 'never-created')), false);
});

test('bounded agent scheduling preserves pipeline/parallel order and cannot deadlock on nested fan-out', async () => {
  let active = 0; let maximum = 0;
  const failures = [];
  const scheduler = createScheduler(2, event => failures.push(event));
  const work = (value, ms) => scheduler.scheduled(async () => {
    active += 1; maximum = Math.max(active, maximum);
    try { await delay(ms); return value; } finally { active -= 1; }
  });
  const result = await scheduler.pipeline([1, 2, 3],
    async (value, original, index) => { assert.equal(value, original); await work(value, 4 - index); if (value === 2) throw new Error('synthetic failure'); return value * 10; },
    async (value, original) => scheduler.parallel([
      () => work(value + original, 3), () => work(value - original, 1),
    ]));
  assert.deepEqual(result, [[11, 9], null, [33, 27]]);
  assert.equal(maximum, 2);
  assert.equal(failures[0].event, 'pipeline-item-failed');
  assert.equal(failures[0].index, 1);
  assert.deepEqual(await scheduler.parallel([() => Promise.reject(new Error('setup')), () => work(4, 1)]), [null, 4]);
  assert.throws(() => createScheduler(5), /1 through 4/);
});

test('native parser validates structured_output independently of duplicated response and fails closed', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tob-adapter-parser-'));
  const file = path.join(dir, 'stdout.ndjson');
  const schema = { type: 'object', required: ['ok'], properties: { ok: { type: 'boolean' } }, additionalProperties: false };
  const check = validator.compile(schema);
  const init = { event: 'init', conversation_id: 'synthetic-1', init: { model: 'gemini-4-argon-high', permission_mode: 'always-proceed' } };
  const terminal = { event: 'result', result: { conversation_id: 'synthetic-1', status: 'SUCCESS', structured_output: { ok: true }, response: '{"ok":true}{"ok":true}' } };
  const write = () => fs.writeFileSync(file, JSON.stringify(init) + '\n' + JSON.stringify(terminal) + '\n');
  write(); const seen = new Set();
  assert.deepEqual(readNativeResult(file, check, seen).data, { ok: true });
  assert.throws(() => readNativeResult(file, check, seen), /reused/);
  terminal.result.structured_output = { ok: 'true' }; write();
  assert.throws(() => readNativeResult(file, check), /Schema validation failed/);
  delete terminal.result.structured_output; write();
  assert.throws(() => readNativeResult(file, check), /no structured_output/);
  terminal.result.structured_output = { ok: true }; init.init.model = 'gemini-other'; write();
  assert.throws(() => readNativeResult(file, check), /model mismatch/);
});

test('named agent definitions resolve from exact pinned source; unknown types are rejected', () => {
  assert.equal(resolveAgentType(upstream, 'audit-context-building:function-analyzer').sha256,
    'd450f462b63dac6858015340a2e047293851d7e3c671725792d9770dca107d29');
  assert.match(resolveAgentType(upstream, 'spec-to-code-compliance:spec-compliance-checker').source, /Do not accept a name as evidence/);
  assert.throws(() => resolveAgentType(upstream, 'missing:no-such-agent'), /not found/);
  assert.throws(() => resolveAgentType(upstream, '../escape'), /format/);
});

test('exact S1 body drives orientation, twelve default analyses, and synthesis with thirteen synthetic candidates', async () => {
  const phases = []; const calls = []; const events = [];
  const scheduler = createScheduler(2, event => events.push(event));
  const candidates = Array.from({ length: 13 }, (_, i) => ({ name: `synthetic-${i + 1}`, file: 'Synthetic.sol', why: 'setup-only' }));
  const agent = (prompt, options) => scheduler.scheduled(async () => {
    calls.push({ prompt, options });
    let result;
    if (options.label === 'orient') result = { modules: [], entrypoints: [], actors: [], state: [], candidates };
    else if (options.label === 'synthesize') result = { dossierFile: 'synthetic/DOSSIER.md', trustBoundaries: [], fragilityClusters: [], unresolved: [] };
    else {
      assert.equal(options.agentType, 'audit-context-building:function-analyzer');
      result = { function: options.label, file: 'Synthetic.sol', analysisFile: 'synthetic/' + options.label + '.md',
        invariants: [], assumptions: [{ claim: 'synthetic assumption', establishedBy: 'nothing found' }], calls: [], openQuestions: [] };
    }
    return validator.compile(options.schema)(result);
  });
  const result = await executeWorkflow({ source: load('audit-context'), args: { path: 'synthetic' }, agent,
    parallel: scheduler.parallel, pipeline: scheduler.pipeline,
    phase: value => phases.push(value), log: value => events.push(value) });
  assert.deepEqual(phases, ['Orient', 'Analyze', 'Synthesize']);
  assert.equal(calls.length, 14);
  assert.equal(result.analyzed.length, 12);
  assert.deepEqual(result.notAnalyzed, ['synthetic-13']);
  assert.equal(result.unenforcedAssumptions.length, 12);
  assert.match(calls.find(c => c.options.label === 'synthesize').prompt, /synthetic assumption/);
});

test('exact S5 body keeps default ten, duplicate-ID handling, reverse sweep, native fallback, independent refutations and failed-item disclosure', async () => {
  const phases = []; const calls = []; const events = [];
  const scheduler = createScheduler(2, event => events.push(event));
  let alignmentCalls = 0;
  const agent = (prompt, options) => scheduler.scheduled(async () => {
    calls.push({ prompt, options });
    let result;
    if (options.label === 'discover') result = { documents: [{ path: 'A.md', describes: 'setup-A' }, { path: 'B.md', describes: 'setup-B' }], codePaths: ['Synthetic.sol'] };
    else if (['A.md', 'B.md'].includes(options.label)) result = { requirements: Array.from({ length: 6 }, (_, i) => ({ id: `REQ-${i + 1}`, quote: 'Synthetic MUST ' + i, location: 'L1', kind: 'invariant', force: 'mandatory' })) };
    else if (options.label === 'undocumented-behavior') result = { behaviors: [] };
    else if (options.label.startsWith('refute:')) {
      if (options.label === 'refute:REQ-3') throw new Error('synthetic verifier failure');
      result = { refuted: options.label === 'refute:REQ-2', reasoning: 'synthetic independent vote' };
    } else if (options.label === 'report') {
      assert.match(prompt, /REQ-4/);
      assert.match(prompt, /considered and/);
      assert.match(prompt, /refutation agents both failed/);
      result = { reportFile: 'synthetic/REPORT.md', divergences: [], documentProblems: [] };
    } else {
      alignmentCalls += 1;
      if (options.label === 'REQ-4') throw new Error('synthetic checker failure');
      const verdict = { 'REQ-1': 'absent', 'REQ-2': 'partial', 'REQ-3': 'stronger-than-spec' }[options.label] ?? 'implemented';
      result = { requirementId: options.label, verdict, confidence: 'high', searched: [{ where: 'Synthetic.sol', result: 'setup only' }], reasoning: 'synthetic', analysisFile: 'synthetic/' + options.label + '.md' };
    }
    return validator.compile(options.schema)(result);
  });
  const result = await executeWorkflow({ source: load('spec-compliance'), args: { path: 'synthetic' }, agent,
    parallel: scheduler.parallel, pipeline: scheduler.pipeline,
    phase: value => phases.push(value), log: value => events.push(value) });
  assert.deepEqual(phases, ['Extract', 'Align', 'Verify', 'Report'].filter(x => x !== 'Verify'));
  // Verify is metadata on each verifier invocation in the original algorithm, not phase('Verify').
  assert.equal(result.requirementsExtracted, 12);
  assert.equal(result.requirementsChecked, 9);
  assert.deepEqual(result.checksFailed, ['REQ-4']);
  assert.deepEqual(result.notChecked, ['REQ-5-2', 'REQ-6-2']);
  assert.deepEqual(result.refuted, [{ requirementId: 'REQ-2', verdict: 'partial' }]);
  assert.deepEqual(result.unverified, ['REQ-3']);
  assert.equal(alignmentCalls, 11); // exact native script retries REQ-4 once; the adapter adds none.
  assert.equal(calls.filter(c => c.options.phase === 'Verify').length, 6);
  assert.equal(calls.filter(c => c.options.label === 'undocumented-behavior').length, 1);
  assert.equal(calls.find(c => c.options.label === 'discover').options.effort, 'low');
  assert.ok(events.some(e => String(e).includes('retrying that requirement')));
});
