// Disclosed exact-body transport replay support. No model/network code runs during prepare.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {sha256, PINNED, createValidator, readNativeResult} from './tob-native-workflow-adapter.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const write=(p,v)=>fs.writeFileSync(p,JSON.stringify(v,null,2)+'\n');
const hash=p=>sha256(fs.readFileSync(p));
const canonical=v=>JSON.stringify(v,(_,x)=>x&&typeof x==='object'&&!Array.isArray(x)?Object.fromEntries(Object.entries(x).sort(([a],[b])=>a.localeCompare(b))):x);
const tree=root=>Object.fromEntries(fs.readdirSync(root,{recursive:true,withFileTypes:true}).filter(e=>e.isFile()).map(e=>path.join(e.parentPath??e.path,e.name)).sort().map(f=>[path.relative(root,f),hash(f)]));
const under=(root,relative)=>{if(path.isAbsolute(relative))throw Error('Absolute artifact path cannot preserve fresh-cwd isolation');const p=path.resolve(root,relative);if(!p.startsWith(path.resolve(root)+path.sep))throw Error('Artifact escapes workspace');return p;};
const artifacts=data=>{const result=[];function visit(v){if(!v||typeof v!=='object')return;for(const[k,x]of Object.entries(v)){if(['analysisFile','dossierFile','reportFile'].includes(k)&&typeof x==='string'&&x)result.push(x);else if(x&&typeof x==='object')visit(x);}}visit(data);return [...new Set(result)];};
function noDelegates(file){for(const line of fs.readFileSync(file,'utf8').split('\n').filter(Boolean)){const e=JSON.parse(line);if(['invoke_subagent','define_subagent','browser_subagent','run_workflow'].includes(e.step_update?.tool_name))throw Error('Native call delegated');}}
function key(context,prompt,options){return sha256(canonical({context,promptSha256:sha256(prompt),options, schema:options.schema}));}
function verifyBindings(bindings){for(const[file,expected]of Object.entries(bindings))if(hash(file)!==expected)throw Error('Immutable replay evidence changed: '+file);}
const add=(bindings,file)=>{bindings[file]=hash(file);};
export function prepareReplay(originalConfigFile,workspace,outputDir,frozenRoot){
 const c=read(originalConfigFile),pin=PINNED[c.workflow];if(!pin)throw Error('Unknown pinned workflow');
 const original=path.resolve(c.outputDir),finalFile=path.join(original,'workflow-result.json');if(!fs.existsSync(finalFile))throw Error('Original workflow not terminal; replay preparation refused');
 const final=read(finalFile),launch=read(path.join(original,'launch.json'));
 if(launch.adapterSha256!=='a9f2d72287aefee50e37e492c4ebfe394311eab21030744c6e81ba56dfc8046f'||launch.originalSourceSha256!==pin.sha256||hash(c.workflowFile)!==pin.sha256)throw Error('Original adapter/source provenance differs');
 if(c.args&&canonical(c.args)!==canonical(launch.args))throw Error('Original args mismatch');
 const sources=tree(frozenRoot);if(Object.keys(sources).length!==43||Object.keys(sources).filter(f=>f.endsWith('.sol')&&f.includes('/node_modules/')).length!==31)throw Error('Need exact43/31 frozen source inputs');
 const resources=tree(c.pluginRoot),skillRoot=path.join(c.workspace,'.agents/skills'),skillResources=tree(skillRoot),bindings={};
 for(const[name,expected]of Object.entries(sources)){const f=path.join(c.workspace,name);if(hash(f)!==expected)throw Error('Original frozen source changed');add(bindings,f);}
 for(const name of Object.keys(resources))add(bindings,path.join(c.pluginRoot,name));
 for(const name of Object.keys(skillResources))add(bindings,path.join(skillRoot,name));
 for(const f of [originalConfigFile,finalFile,path.join(original,'launch.json'),c.workflowFile,...(c.preambleFile?[c.preambleFile]:[])])add(bindings,f);
 const validator=createValidator(c.ajvPackage),seen=new Set(),context={workflowSha256:pin.sha256,sourceManifestSha256:sha256(canonical(sources)),resourceManifestSha256:sha256(canonical({resources,skillResources})),argsSha256:sha256(canonical(c.args??{})),preambleSha256:c.preambleFile?hash(c.preambleFile):null};
 const entries=[],failedLedger=[],nonReusable=[];
 for(const id of fs.readdirSync(path.join(original,'agents')).sort()){
  const dir=path.join(original,'agents',id),f=path.join(dir,'invocation.json'),r=read(f);add(bindings,f);
  if(r.status!=='succeeded'){failedLedger.push({id,status:r.status,error:r.error??null,invocation:f,sha256:hash(f)});continue;}
  const schema=read(path.join(dir,'schema.json')),prompt=fs.readFileSync(path.join(dir,'prompt.txt'),'utf8');
  if(r.schemaSha256!==sha256(JSON.stringify(schema))||r.promptSha256!==sha256(prompt)||canonical(schema)!==canonical(r.options.schema)||!r.schemaValidated||r.exit?.code!==0||r.exit?.signal)throw Error('Original successful invocation schema/prompt/exit mismatch');
  const argv=r.argv;if(argv[argv.indexOf('--model')+1]!=='gemini-4-argon-high'||argv[argv.indexOf('--effort')+1]!=='high'||argv.includes('--conversation')||argv[argv.indexOf('-p')+1]!==prompt)throw Error('Original successful actual argv route mismatch');
  noDelegates(path.join(dir,'stdout.ndjson'));const parsed=readNativeResult(path.join(dir,'stdout.ndjson'),validator.compile(schema),seen);
  if(parsed.conversationId!==r.conversationId||canonical(parsed.data)!==canonical(read(path.join(dir,'structured-output.json'))))throw Error('Native structured output mismatch');
  const files={};for(const name of ['invocation.json','schema.json','prompt.txt','stdout.ndjson','stderr.log','structured-output.json',...(fs.existsSync(path.join(dir,'native.log'))?['native.log']:[])]){const file=path.join(dir,name);add(bindings,file);files[name]={file,sha256:hash(file)};}
  let deliverables=[];try{deliverables=artifacts(parsed.data).map(relative=>{const file=under(c.workspace,relative);if(!fs.statSync(file).isFile())throw Error('Returned artifact missing');add(bindings,file);return {relative,file,sha256:hash(file)};});}catch(error){nonReusable.push({id,reason:String(error)});continue;}
  entries.push({key:key(context,prompt,r.options),originalCallId:id,conversationId:parsed.conversationId,immutableCallIdentity:sha256(canonical({original,id,conversationId:parsed.conversationId,promptSha256:r.promptSha256,schemaSha256:r.schemaSha256,options:r.options})),files,deliverables});
 }
 // A transport replay cannot silently repair denials, policy refusals or unclassified errors.
 for(const failure of failedLedger)if(!/stream was interrupted|operation timed out|context deadline exceeded/.test(failure.error??''))throw Error('Unclassified original failed call: '+failure.id);
 if(!failedLedger.length)throw Error('No eligible interrupted call: replay unnecessary');
 fs.mkdirSync(path.dirname(workspace),{recursive:true});fs.mkdirSync(workspace,{recursive:false});for(const name of Object.keys(sources)){const dest=path.join(workspace,name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(frozenRoot,name),dest);}
 // Copy exact resources for independent inventory; original path remains read-only to preserve full prompt bytes.
 for(const name of Object.keys(resources)){const dest=path.join(workspace,'upstream-plugins',name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(c.pluginRoot,name),dest);}
 for(const name of Object.keys(skillResources)){const dest=path.join(workspace,'.agents/skills',name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(skillRoot,name),dest);}
 fs.mkdirSync(path.dirname(outputDir),{recursive:true});const manifestFile=path.join(path.dirname(outputDir),'replay-manifest.json');
 const manifest={kind:'disclosed-same-cell-exact-body-transport-replay',createdUtc:new Date().toISOString(),originalOutput:original,originalConfigFile,context,sources,resources,skillResources,bindings,entries,failedLedger,nonReusable,originalFinalStatus:final.status,originalWorkflowResultSha256:hash(finalFile),originalResourcePathRetainedReadOnly:c.pluginRoot,rawTimestampsNormalized:false,newConcurrency:4,automaticRetry:false};write(manifestFile,manifest);
 const newConfig={...c,workspace:path.resolve(workspace),outputDir:path.resolve(outputDir),concurrency:4,replayManifest:manifestFile,replayManifestSha256:hash(manifestFile),replayAdapterSha256:hash(path.join(here,'tob-native-workflow-replay-adapter.mjs')),replaySupportSha256:hash(fileURLToPath(import.meta.url))};
 const configFile=path.join(path.dirname(outputDir),'replay-config.json');write(configFile,newConfig);return {status:'prepared-no-model-launched',configFile,manifestFile,reusableSuccessfulCalls:entries.length,failedCallIds:failedLedger.map(x=>x.id),nonReusable,concurrency:4};
}
export function loadReplay(config){
 if(!config.replayManifest)throw Error('Replay config/manifest required');if(config.replayAdapterSha256&&hash(path.join(here,'tob-native-workflow-replay-adapter.mjs'))!==config.replayAdapterSha256)throw Error('Prepared replay adapter changed');if(config.replaySupportSha256&&hash(fileURLToPath(import.meta.url))!==config.replaySupportSha256)throw Error('Prepared replay helper changed');if(hash(config.replayManifest)!==config.replayManifestSha256)throw Error('Replay manifest changed');
 const m=read(config.replayManifest);verifyBindings(m.bindings);
 if(path.resolve(config.pluginRoot)!==path.resolve(m.originalResourcePathRetainedReadOnly)||hash(config.workflowFile)!==m.context.workflowSha256)throw Error('Replay context mismatch');
 for(const[name,expected]of Object.entries(m.sources))if(hash(path.join(config.workspace,name))!==expected)throw Error('Fresh frozen source mismatch');
 const used=new Set();return {reuse({prompt,options,dir,record}){
  const wanted=key(m.context,prompt,options),entry=m.entries.find(e=>e.key===wanted&&!used.has(e.immutableCallIdentity));
  if(!entry){record.runtimeOrigin='fresh-native-High-after-transport-repair';return false;}
  // Reserve synchronously before any asynchronous native launch can race this identity.
  used.add(entry.immutableCallIdentity);verifyBindings(m.bindings);
  for(const item of entry.deliverables){const dest=under(config.workspace,item.relative);if(fs.existsSync(dest)&&hash(dest)!==item.sha256)throw Error('Cached deliverable conflicts with fresh work');fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(item.file,dest);}
  for(const[name,item]of Object.entries(entry.files))if(['stdout.ndjson','stderr.log','native.log'].includes(name))fs.copyFileSync(item.file,path.join(dir,name));
  const receipt={kind:'reused-original-validated-same-cell-native-result',originalOutput:m.originalOutput,originalCallId:entry.originalCallId,conversationId:entry.conversationId,immutableCallIdentity:entry.immutableCallIdentity,key:wanted,sourceEvidence:entry.files,deliverables:entry.deliverables,modelExecutedAgain:false,rawTimestampsNormalized:false};write(path.join(dir,'cache-reuse-receipt.json'),receipt);record.runtimeOrigin='reused-original-validated-native-call';record.reuse=receipt;record.argvExecuted=false;return true;
 },checkTrace(file){noDelegates(file);},finish(){verifyBindings(m.bindings);for(const[name,expected]of Object.entries(m.sources))if(hash(path.join(config.workspace,name))!==expected)throw Error('Fresh protected source mutated');for(const[name,expected]of Object.entries(m.skillResources??{}))if(hash(path.join(config.workspace,'.agents/skills',name))!==expected)throw Error('Fresh pinned skill mutated');for(const[name,expected]of Object.entries(m.resources??{}))if(hash(path.join(config.workspace,'upstream-plugins',name))!==expected)throw Error('Fresh pinned resource mutated');return {originalOutput:m.originalOutput,reusedOriginalCalls:used.size,originalFailedLedger:m.failedLedger,rawTimestampsNormalized:false};}};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 if(process.argv[2]!=='prepare'||process.argv.length!==7)throw Error('Usage: node support.mjs prepare ORIGINAL_CONFIG FRESH_WORKSPACE NEW_OUTPUT FROZEN_CONTEXT');
 console.log(JSON.stringify(prepareReplay(...process.argv.slice(3)),null,2));
}
