#!/usr/bin/env python3
"""Prepare only a fresh CI-owned Supabase project/ports; never start/stop a stack."""
from __future__ import annotations
import argparse
import copy
import errno
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tomllib

DEFAULTS = {('api','port'):54321, ('db','port'):54322, ('db','shadow_port'):54320}


def require(value, code):
    if not value: raise ValueError(code)


def replace_scalar(source: str, section: str | None, key: str, value: str) -> str:
    start = 0
    end = len(source)
    if section:
        matches = list(re.finditer(r'(?m)^\['+re.escape(section)+r'\][ \t]*(?:#[^\n]*)?$',source))
        require(len(matches)==1, 'GENERATED_CONFIG_SECTION_AMBIGUOUS')
        start=matches[0].end()
        following=re.search(r'(?m)^\[',source[start:])
        if following: end=start+following.start()
    else:
        first=re.search(r'(?m)^\[',source)
        if first: end=first.start()
    body=source[start:end]
    pattern=r'(?m)^([ \t]*'+re.escape(key)+r'[ \t]*=[ \t]*)(?:"[^"\n]*"|[0-9]+)([ \t]*(?:#[^\n]*)?)$'
    body,count=re.subn(pattern,lambda m:m[1]+value+m[2],body)
    require(count==1, 'GENERATED_CONFIG_VALUE_AMBIGUOUS')
    return source[:start]+body+source[end:]


def allocate_ports(*, factory=socket.socket):
    held=[];chosen={};busy={}
    try:
        for field, default in DEFAULTS.items():
            handle=factory(socket.AF_INET,socket.SOCK_STREAM);held.append(handle)
            try:
                handle.bind(('0.0.0.0',default));busy[field]=False
            except OSError as error:
                if error.errno!=errno.EADDRINUSE: raise
                busy[field]=True
                handle.bind(('0.0.0.0',0))
            chosen[field]=handle.getsockname()[1]
        require(len(set(chosen.values()))==3, 'CI_PORTS_MUST_BE_DISTINCT')
        return chosen,busy
    finally:
        for handle in held: handle.close()


def prepare(source: str, run_id: str, attempt: str, *, allocator=allocate_ports):
    require(re.fullmatch(r'[0-9]+',run_id) and re.fullmatch(r'[0-9]+',attempt), 'CI_RUN_ID_REQUIRED')
    before=tomllib.loads(source)
    require(before.get('project_id')=='Body-Intelligence','FRESH_REPOSITORY_INIT_REQUIRED')
    for (section,key),value in DEFAULTS.items():
        require(before.get(section,{}).get(key)==value,'PINNED_INIT_PORT_SCHEMA_CHANGED')
    selected,busy=allocator()
    project='bil-ci-'+run_id+'-'+attempt
    require(re.fullmatch(r'bil-ci-[0-9]+-[0-9]+',project),'INVALID_OWNED_PROJECT_ID')
    result=replace_scalar(source,None,'project_id',json.dumps(project))
    expected=copy.deepcopy(before);expected['project_id']=project
    for (section,key),port in selected.items():
        require(type(port) is int and 1024<=port<=65535,'INVALID_LOCAL_PORT')
        expected[section][key]=port
        result=replace_scalar(result,section,key,str(port))
    require(tomllib.loads(result)==expected,'CONFIG_CHANGED_OUTSIDE_OWNED_ID_PORTS')
    report={'project_id':project,'exact_database_container':'supabase_db_'+project,
            'ports':[{'field':section+'.'+key,'original':DEFAULTS[(section,key)],
                      'selected':selected[(section,key)],'original_port_busy':busy[(section,key)]}
                     for section,key in DEFAULTS],
            'scope':'Only generated local project_id and api/db/shadow host ports. No schema/auth/RLS changes.',
            'port_claim_is_preflight_not_atomic_docker_reservation':True}
    return result,report


def ownership_metadata():
    report={}
    for name,args in [('listeners',['ss','-H','-ltnp']),
                      ('containers',['docker','ps','--format','{{.Names}}\t{{.Ports}}'])]:
        try:
            result=subprocess.run(args,stdin=subprocess.DEVNULL,capture_output=True,
                text=True,encoding='utf-8',errors='replace',timeout=5)
            rows=[line for line in result.stdout.splitlines()
                  if any(re.search(r':'+str(port)+r'(?:\D|$)',line) for port in DEFAULTS.values())]
            report[name]={'status':result.returncode,'matching_port_rows':[x[:1000] for x in rows[:30]],
                          'truncated':len(rows)>30}
        except FileNotFoundError:
            report[name]={'diagnostic':'TOOL_UNAVAILABLE'}
        except subprocess.TimeoutExpired:
            report[name]={'diagnostic':'READONLY_METADATA_TIMEOUT'}
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,required=True)
    parser.add_argument('--github-env',type=Path,required=True)
    parser.add_argument('--evidence-dir',type=Path,required=True)
    args=parser.parse_args()
    require(os.environ.get('GITHUB_ACTIONS')=='true'
            and os.environ.get('GITHUB_REPOSITORY')=='bilhealth-admin/Body-Intelligence','ONLY_OWNED_GITHUB_CI')
    require(args.config==Path('supabase/config.toml') and not args.config.is_symlink(), 'ONLY_GENERATED_LOCAL_CONFIG')
    temp=Path(os.environ['RUNNER_TEMP']).resolve()
    require(args.github_env.resolve()==Path(os.environ['GITHUB_ENV']).resolve()
            and args.github_env.resolve().is_relative_to(temp),'ONLY_CURRENT_RUNNER_ENV')
    require(args.evidence_dir.resolve().is_relative_to(temp),'ONLY_OWNED_EVIDENCE_DIRECTORY')
    args.evidence_dir.mkdir(exist_ok=False)
    diagnostics=ownership_metadata()
    (args.evidence_dir/'PORT_OWNERSHIP_BEFORE_START.json').write_text(json.dumps(diagnostics,indent=2)+'\n')
    source=args.config.read_text(encoding='utf-8')
    updated,report=prepare(source,os.environ.get('GITHUB_RUN_ID',''),os.environ.get('GITHUB_RUN_ATTEMPT',''))
    args.config.write_text(updated,encoding='utf-8')
    require(tomllib.loads(args.config.read_text(encoding='utf-8'))==tomllib.loads(updated),'CONFIG_READBACK_MISMATCH')
    with args.github_env.open('a',encoding='utf-8') as target:
        target.write('BIL_LOCAL_DB_CONTAINER='+report['exact_database_container']+'\n')
    (args.evidence_dir/'OWNED_LOCAL_STACK_CONFIG.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))


if __name__=='__main__': main()
