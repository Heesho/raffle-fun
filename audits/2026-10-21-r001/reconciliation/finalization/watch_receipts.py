from pathlib import Path
import importlib.util,io,contextlib,time,datetime,json
p=Path(__file__).with_name('receipt_helper.py');spec=importlib.util.spec_from_file_location('receipts',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
print(json.dumps({'watch_started_utc':m.now(),'interval_seconds':35}),flush=True)
while True:
 try:
  spec.loader.exec_module(m)
  with contextlib.redirect_stdout(io.StringIO()) as out:m.scan()
  rows=out.getvalue().splitlines()
  for row in rows:
   if 'report_path' in row:print(row,flush=True)
  Path(__file__).with_name('watch-heartbeat.json').write_text(json.dumps({'checked_utc':m.now(),'status':'watching sealed receipts only','interval_seconds':35},indent=2)+'\n')
 except Exception as e:
  print(json.dumps({'checked_utc':m.now(),'watch_error':str(e)}),flush=True)
 time.sleep(35)
