#!/usr/bin/env node
// Disclosed host adapter for exact pinned ToB workflow bodies; never an upstream Workflow-engine claim.
import fs from 'node:fs';
import {loadReplay} from './tob-workflow-replay-support.mjs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
export const PINNED = Object.freeze({
  'audit-context': {
    plugin: 'audit-context-building', file: 'audit-context.js',
    sha256: '71cd025216e2589fee1e1a0ffe215fb7bbeaf22751dc7417ca6ce74497e6d0b3',
    defaultLimit: 12, maxLimit: 40,
  },
  'spec-compliance': {
    plugin: 'spec-to-code-compliance', file: 'spec-compliance.js',
    sha256: '782c17752a1b8f9e83e65120d59b7588548aba0441943ce5388163226f6d5238',
    defaultLimit: 10, maxLimit: 30,
  },
});
export const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const AGENT_PINS = Object.freeze({
  'audit-context-building:function-analyzer': 'd450f462b63dac6858015340a2e047293851d7e3c671725792d9770dca107d29',
  'spec-to-code-compliance:spec-compliance-checker': '20dbf4d9b8013e8c42691dab08bd4df1ac0250eb715f3a02b2270be78bc287c4',
});
const utc = () => new Date().toISOString();
const writeJson = (file, value) => fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');

export function transformWorkflow(source) {
  const matches = source.match(/export const meta\s*=/g) ?? [];
  if (matches.length !== 1) throw new Error('Expected exactly one export const meta declaration');
  return source.replace('export const meta', 'const meta');
}

// Agent calls alone hold permits. Pipeline/parallel callbacks never do: nested refutation fan-out
// otherwise deadlocks when every outer pipeline worker waits for a child permit it already holds.
export function createScheduler(concurrency, journal = () => {}) {
  if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 4)
    throw new Error('Concurrency must be an integer from 1 through 4');
  let active = 0;
  const waiting = [];
  async function scheduled(fn) {
    await new Promise(resolve => {
      if (active < concurrency) { active += 1; resolve(); }
      else waiting.push(resolve);
    });
    try { return await fn(); }
    finally {
      if (waiting.length) waiting.shift()();
      else active -= 1;
    }
  }
  async function parallel(tasks) {
    return Promise.all(tasks.map(async (task, index) => {
      try { return await task(); }
      catch (error) { journal({ event: 'parallel-item-failed', index, error: String(error) }); return null; }
    }));
  }
  async function pipeline(items, ...stages) {
    return Promise.all(items.map(async (item, index) => {
      let value = item;
      try {
        for (const stage of stages) {
          if (value === null || value === undefined) return null;
          value = await stage(value, item, index);
        }
        return value;
      } catch (error) {
        journal({ event: 'pipeline-item-failed', index, error: String(error) });
        return null;
      }
    }));
  }
  return { scheduled, parallel, pipeline };
}

export function createValidator(packagePath) {
  const require = createRequire(path.resolve(packagePath));
  const Ajv = require('./dist/ajv.js');
  const metadata = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  const ajv = new Ajv({ allErrors: true, strict: false, validateFormats: false,
    coerceTypes: false, useDefaults: false, removeAdditional: false });
  return {
    metadata: { package: path.resolve(packagePath), version: metadata.version,
      packageSha256: sha256(fs.readFileSync(packagePath)) },
    compile(schema) {
      const check = ajv.compile(schema);
      return data => {
        if (!check(data)) throw new Error('Schema validation failed: ' + JSON.stringify(check.errors));
        return data;
      };
    },
  };
}

export function readNativeResult(file, check, seenConversationIds = new Set()) {
  const events = fs.readFileSync(file, 'utf8').split('\n').filter(line => line.trim()).map(JSON.parse);
  const inits = events.filter(event => event.event === 'init');
  const results = events.filter(event => event.event === 'result');
  if (inits.length !== 1 || results.length !== 1) throw new Error('Expected exactly one native init and result');
  const init = inits[0]; const result = results[0].result;
  if (init.init?.model !== 'gemini-4-argon-high') throw new Error('Native init model mismatch');
  if (init.init?.permission_mode !== 'always-proceed') throw new Error('Native permission mode mismatch');
  if (result.status !== 'SUCCESS') throw new Error('Native terminal error: ' + (result.error ?? result.status));
  if (!result.conversation_id || result.conversation_id !== init.conversation_id)
    throw new Error('Missing or inconsistent native conversation identity');
  if (seenConversationIds.has(result.conversation_id)) throw new Error('Agent conversation was reused');
  seenConversationIds.add(result.conversation_id);
  if (!Object.hasOwn(result, 'structured_output')) throw new Error('Native result has no structured_output');
  // Do not parse response: the verified CLI can duplicate its textual JSON while returning valid structured_output.
  const data = check(result.structured_output);
  return { data, init: init.init, conversationId: result.conversation_id, usage: result.usage ?? null,
    nativeSchema: result.json_schema ?? null, terminalStatus: result.status };
}

export function resolveAgentType(pluginRoot, agentType) {
  if (!agentType) return null;
  const match = /^([A-Za-z0-9_-]+):([A-Za-z0-9_-]+)$/.exec(agentType);
  if (!match) throw new Error('Unknown agent type format: ' + agentType);
  const plugin = path.join(pluginRoot, match[1]);
  const file = path.join(plugin, 'agents', match[2] + '.md');
  if (!fs.existsSync(file)) throw new Error('Agent type not found in pinned plugin: ' + agentType);
  const source = fs.readFileSync(file, 'utf8');
  if (!AGENT_PINS[agentType] || sha256(source) !== AGENT_PINS[agentType])
    throw new Error('Agent type pinned source hash mismatch: ' + agentType);
  return { type: agentType, file, baseDir: plugin, source, sha256: sha256(source) };
}

export async function executeWorkflow({ source, args, agent, parallel, pipeline, phase, log }) {
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  const transformed = transformWorkflow(source);
  const fn = new AsyncFunction('args', 'agent', 'parallel', 'pipeline', 'phase', 'log', 'budget', transformed);
  return fn(args, agent, parallel, pipeline, phase, log, Object.freeze({ total: 0, remaining: () => 0 }));
}

export async function runNativeWorkflow(config) {
  const { workflow, workflowFile, workspace, outputDir } = config;
  const pin = PINNED[workflow];
  if (!pin) throw new Error('Only the two exact pinned ToB workflows are supported');
  const source = fs.readFileSync(workflowFile, 'utf8');
  if (sha256(source) !== pin.sha256) throw new Error('Pinned workflow source hash mismatch; refusing host execution');
  const transformed = transformWorkflow(source);
  const pluginRoot = path.resolve(config.pluginRoot);
  const expectedPluginFile = path.join(pluginRoot, pin.plugin, 'workflows', pin.file);
  if (sha256(fs.readFileSync(expectedPluginFile)) !== pin.sha256)
    throw new Error('Pinned plugin workflow tree mismatch');
  const cwd = fs.realpathSync(workspace);
  const output = path.resolve(outputDir);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.mkdirSync(output, { recursive: false });
  const journalFile = path.join(output, 'journal.jsonl');
  const journal = value => fs.appendFileSync(journalFile, JSON.stringify({ utc: utc(), ...value }) + '\n');
  const cli = path.resolve(config.cli ?? path.join(here, 'bin/agy'));
  const validator = createValidator(config.ajvPackage ?? '/Users/hishamel-husseini/.npm/_npx/d274a05a00f9ae59/node_modules/ajv/package.json');
  const replay = loadReplay(config);
  const sourceHashes = {};
  for (const plugin of [pin.plugin]) {
    const agentsDir = path.join(pluginRoot, plugin, 'agents');
    if (fs.existsSync(agentsDir)) for (const name of fs.readdirSync(agentsDir)) {
      const file = path.join(agentsDir, name);
      if (fs.statSync(file).isFile()) sourceHashes[file] = sha256(fs.readFileSync(file));
    }
  }
  const launch = { method: 'exact-pinned-ToB-JS-body-on-disclosed-native-agy-host-adapter',
    upstreamWorkflowEngineClaim: false, startedUtc: utc(), workflow, workflowFile: path.resolve(workflowFile),
    workspace: cwd, args: config.args ?? {}, pinnedRevision: '82fe8226252622fa807643bdca1710901198553a',
    originalSourceSha256: sha256(source), transformedSourceSha256: sha256(transformed),
    transformation: 'only export const meta -> const meta; wrap body in AsyncFunction with seven supplied globals',
    adapterSha256: sha256(fs.readFileSync(fileURLToPath(import.meta.url))),
    cli, cliSha256: sha256(fs.readFileSync(cli)), schemaValidator: validator.metadata,
    concurrency: config.concurrency ?? 2, budget: { total: 0, remaining: 0 },
    unchangedDefaultLimit: pin.defaultLimit, unchangedMaximumLimit: pin.maxLimit,
    actualModel: 'gemini-4-argon-high', actualEffort: 'high',
    effortOverride: 'upstream low/medium options preserved in each call record; actual effort high by user instruction',
    adapterAutomaticRetries: false, adapterFallbackModel: false, outerWallClockTimeout: null,
    nativeWorkflowFallbacks: 'S5 typed-checker fallback remains exactly as written in pinned JS',
    namedAgentSourceHashes: sourceHashes };
  writeJson(path.join(output, 'launch.json'), launch);
  fs.writeFileSync(path.join(output, 'upstream-workflow.js'), source);
  fs.writeFileSync(path.join(output, 'transformed-workflow.js'), transformed);
  const scheduler = createScheduler(config.concurrency ?? 2, journal);
  const seenConversationIds = new Set();
  const calls = [];
  const pending = new Set();
  let nextId = 0;
  let currentPhase = null;
  const preamble = config.preambleFile ? fs.readFileSync(config.preambleFile, 'utf8') : '';
  const agentImpl = (prompt, options = {}) => {
    const id = String(++nextId).padStart(3, '0');
    const requested = { id, requestedUtc: utc(), phase: options.phase ?? currentPhase,
      label: options.label ?? null, options, model: 'gemini-4-argon-high', actualEffort: 'high' };
    journal({ event: 'agent-requested', ...requested });
    return scheduler.scheduled(async () => {
      const dir = path.join(output, 'agents', id);
      fs.mkdirSync(dir, { recursive: true });
      const record = { ...requested, startedUtc: utc(), status: 'running' };
      calls.push(record);
      const save = () => writeJson(path.join(dir, 'invocation.json'), record);
      try {
        if (!options.schema) throw new Error('Every workflow agent must provide its exact upstream schema');
        const check = validator.compile(options.schema);
        const typed = resolveAgentType(pluginRoot, options.agentType);
        if (typed && sourceHashes[typed.file] !== typed.sha256) throw new Error('Pinned named-agent instructions changed');
        record.agentType = typed ? { type: typed.type, path: typed.file, sourceSha256: typed.sha256 } : null;
        const schemaFile = path.join(dir, 'schema.json');
        writeJson(schemaFile, options.schema);
        if (typed) fs.writeFileSync(path.join(dir, 'named-agent-original.md'), typed.source);
        let fullPrompt = [
          'This is an authorized independent schema-bound call driven by the exact pinned ToB workflow script. Start a fresh analysis from only this task and the prepared workspace. Do not read prior provider lanes, other audits, or personal memory. Do not change owned source or build configuration. Read relevant dependency source as needed. Use native file tools to write requested analysis deliverables inside this workspace. Do not delegate or change models: this call is already an independently scheduled workflow agent. Return the structured object required by the supplied schema.',
          'Tool vocabulary mapping for pinned instructions: Read=read-only native view_file/sed_file; Grep=grep_search; Glob=find_by_name; Write=write_to_file. No host code from the assessed repository is executed by this adapter.',
          preamble,
          ...(typed ? [`The following pinned agent instructions are reproduced verbatim. Their {baseDir} placeholder denotes ${typed.baseDir}. YAML frontmatter identifies the original instructions; native model selection is fixed by this controller.`, typed.source] : []),
          'Exact workflow task follows:', prompt,
        ].filter(Boolean).join('\n\n');
        fs.writeFileSync(path.join(dir, 'prompt.txt'), fullPrompt);
        const argv = [cli, '-p', fullPrompt, '--model', 'gemini-4-argon-high', '--effort', 'high',
          '--dangerously-skip-permissions', '--output-format', 'stream-json', '--print-timeout', '0',
          '--json-schema', schemaFile, '--log-file', path.join(dir, 'native.log')];
        Object.assign(record, { argv, cwd, schemaSha256: sha256(JSON.stringify(options.schema)),
          promptSha256: sha256(fullPrompt), requestedEffort: options.effort ?? null,
          effortOverridden: options.effort != null && options.effort !== 'high' });
        save();
        const cacheHit = replay.reuse({prompt: fullPrompt, options, dir, record});
        if (!cacheHit && typed) {
          const skillName = typed.type.split(':')[0];
          const repairedBase = path.join(cwd, '.agents', 'skills', skillName);
          const mappingNote = 'Disclosed runtime resource-path repair for this fresh typed call: the original pinned instructions above are unchanged, but their {baseDir}/skills/' + skillName + '/ path resolves to the complete exact pinned resource tree at ' + repairedBase + '/ in THIS workspace. Use that explicit path for SKILL.md and every referenced resource. Do not read or write original attempt artifacts. This mapping note repairs the missing original pluginRoot skill subtree; it changes the actual native prompt hash and is recorded separately.';
          record.preResourceMappingPromptSha256 = sha256(fullPrompt);
          fullPrompt += '\n\n' + mappingNote;
          record.resourcePathMapping = {originalBaseDir: typed.baseDir, actualPinnedSkillRoot: repairedBase, note: mappingNote};
          record.promptSha256 = sha256(fullPrompt);
          argv[2] = fullPrompt;
          fs.writeFileSync(path.join(dir, 'prompt.txt'), fullPrompt);
        }
        let exit = {code: 0, signal: null};
        if (!cacheHit) {
        record.argvExecuted = true;
        const outFd = fs.openSync(path.join(dir, 'stdout.ndjson'), 'wx');
        const errFd = fs.openSync(path.join(dir, 'stderr.log'), 'wx');
        try {
          exit = await new Promise((resolve, reject) => {
            const child = spawn(cli, argv.slice(1), { cwd, stdio: ['ignore', outFd, errFd] });
            record.pid = child.pid; save();
            child.once('error', reject);
            child.once('close', (code, signal) => resolve({ code, signal }));
          });
        } finally { fs.closeSync(outFd); fs.closeSync(errFd); }
        }
        replay.checkTrace(path.join(dir, 'stdout.ndjson'));
        record.exit = exit;
        if (exit.code !== 0 || exit.signal) throw new Error('Native process failed: ' + JSON.stringify(exit));
        const parsed = readNativeResult(path.join(dir, 'stdout.ndjson'), check, seenConversationIds);
        writeJson(path.join(dir, 'structured-output.json'), parsed.data);
        Object.assign(record, { status: 'succeeded', conversationId: parsed.conversationId,
          nativeInit: parsed.init, nativeTerminalStatus: parsed.terminalStatus, usage: parsed.usage,
          schemaValidated: true, endedUtc: utc() });
        save(); journal({ event: 'agent-finished', id, status: record.status,
          conversationId: record.conversationId, usage: record.usage });
        return parsed.data;
      } catch (error) {
        Object.assign(record, { status: 'failed', error: String(error), endedUtc: utc() });
        save(); journal({ event: 'agent-finished', id, status: 'failed', error: record.error });
        throw error;
      }
    });
  };
  const agent = (...values) => {
    const promise = agentImpl(...values);
    pending.add(promise);
    promise.then(() => pending.delete(promise), () => pending.delete(promise));
    return promise;
  };
  let workflowResult;
  let error;
  try {
    workflowResult = await executeWorkflow({ source, args: config.args ?? {}, agent,
      parallel: scheduler.parallel, pipeline: scheduler.pipeline,
      phase: title => { currentPhase = title; journal({ event: 'phase', title }); },
      log: message => journal({ event: 'workflow-log', message }) });
  } catch (caught) { error = String(caught); }
  // The pinned S5 body can return before its reverse sweep on an all-checks-failed path.
  // Drain already requested calls without creating, retrying, or cancelling any work.
  while (pending.size) await Promise.allSettled([...pending]);
  const replaySummary = replay.finish();
  const result = { replay: replaySummary, method: launch.method, endedUtc: utc(), workflowResult: workflowResult ?? null,
    error: error ?? null, calls: calls.map(({ id, status, conversationId, error: e, usage, runtimeOrigin }) =>
      ({ id, status, runtimeOrigin, conversationId: conversationId ?? null, error: e ?? null, usage: usage ?? null })),
    uniqueConversations: seenConversationIds.size,
    status: error || workflowResult?.error ? 'failed' : calls.some(c => c.status === 'failed') ? 'completed-with-agent-failures' : 'completed',
    assessedSourceExecutedByHost: false, reviewImportPerformed: false };
  writeJson(path.join(output, 'workflow-result.json'), result);
  return result;
}

async function main() {
  if (process.argv.length !== 3 || process.argv[2] === '--help') {
    console.log('Usage: node tob-native-workflow-adapter.mjs CONFIG.json\nRuns exact pinned workflow JS through native agy calls. CONFIG requires workflow, workflowFile, pluginRoot, workspace, outputDir; optional args, concurrency (default2 max4), preambleFile, cli, ajvPackage. No assessed calls occur until invoked with a config.');
    return;
  }
  const result = await runNativeWorkflow(JSON.parse(fs.readFileSync(process.argv[2], 'utf8')));
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== 'completed') process.exitCode = 1;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main().catch(error => { console.error(error); process.exitCode = 1; });
