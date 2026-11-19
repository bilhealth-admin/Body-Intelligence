"""Bind original48 archive and dSYM UUIDs to the exported signed IPA.

Read-only inspection of artifacts; invokes Apple's dwarfdump only. Does not
rebuild, sign, modify an app or upload any artifact.
"""
from __future__ import annotations
import argparse,hashlib,json,plistlib,re,subprocess,tempfile,zipfile
from pathlib import Path, PurePosixPath

def require(condition,message):
    if not condition:raise ValueError(message)
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        while data:=f.read(1024*1024):h.update(data)
    return h.hexdigest()
def uuids(path):
    result=subprocess.check_output(['dwarfdump','--uuid',str(path)],text=True)
    rows=re.findall(r'^UUID: ([A-Fa-f0-9-]{36}) \(([^)]+)\) ',result,re.MULTILINE)
    require(rows and len(rows)==len(set(rows)),'Missing or duplicate Mach-O UUID records')
    return sorted((arch,uuid.lower()) for uuid,arch in rows)
MACHO_MAGICS = frozenset((
    bytes.fromhex(value) for value in (
        'feedface','cefaedfe','feedfacf','cffaedfe',
        'cafebabe','bebafeca','cafebabf','bfbafeca')))

def export_matches(archived, exported):
    # Original Xcode export may thin architectures and re-sign Mach-O bytes.
    # Every retained exported arch must keep its original UUID; no new pair.
    return bool(exported) and set(exported).issubset(set(archived))

def framework_binaries(app):
    result = {}
    for path in sorted(app.rglob('*')):
        relative = path.relative_to(app)
        if not any(part.endswith('.framework') for part in relative.parts[:-1]):
            continue
        require(not path.is_symlink() and path.resolve().is_relative_to(app.resolve()),
                'Framework paths must remain inside the original app')
        if path.is_file():
            with path.open('rb') as stream:
                if stream.read(4) in MACHO_MAGICS:
                    result[relative.as_posix()] = path
    return result

def exported_framework_members(z, prefix):
    result = {}
    for info in z.infolist():
        if info.is_dir() or not info.filename.startswith(prefix + '/'):
            continue
        relative = info.filename[len(prefix) + 1:]
        parts = PurePosixPath(relative).parts
        if not any(part.endswith('.framework') for part in parts[:-1]):
            continue
        require(not PurePosixPath(relative).is_absolute() and '..' not in parts
                and ((info.external_attr >> 16) & 0o170000) != 0o120000,
                'Exported framework path must be a regular app member')
        with z.open(info) as stream:
            if stream.read(4) in MACHO_MAGICS:
                require(relative not in result, 'Duplicate exported framework executable')
                result[relative] = info.filename
    return result

def verify(archive,archive_zip,ipa,source,run,attempt):
    require(re.fullmatch('[a-f0-9]{40}',source) is not None,'Full accepted application SHA required')
    require(type(run) is int and run>0 and type(attempt) is int and attempt>0,'Actual run/attempt required')
    require(archive.is_dir() and not archive.is_symlink() and archive_zip.is_file() and not archive_zip.is_symlink() and ipa.is_file() and not ipa.is_symlink(),'Original regular archive/IPA required')
    apps=list((archive/'Products/Applications').glob('*.app'))
    require(len(apps)==1,'One original archived app required');app=apps[0]
    info=plistlib.loads((app/'Info.plist').read_bytes())
    require(info.get('CFBundleIdentifier')=='com.bilhealth.bodyintelligencelog' and info.get('CFBundleVersion')=='48' and info.get('CFBundleShortVersionString')=='1.0.0','Archived48 app identity required')
    executable=info.get('CFBundleExecutable')
    require(isinstance(executable,str) and executable and '/' not in executable and '\\' not in executable,'Regular app executable name required')
    binary=app/executable;require(binary.is_file() and not binary.is_symlink(),'Original archive executable required')
    archive_ids=uuids(binary)
    with zipfile.ZipFile(ipa) as z:
        infos=[n for n in z.namelist() if n.startswith('Payload/') and n.endswith('.app/Info.plist') and len(n.split('/'))==3]
        require(len(infos)==1,'One exported app plist required')
        require(len(z.namelist())==len(set(z.namelist())), 'Ambiguous exported IPA members')
        ipa_prefix=infos[0].rsplit('/',1)[0]
        exported=plistlib.loads(z.read(infos[0]))
        require(all(exported.get(k)==info.get(k) for k in ('CFBundleIdentifier','CFBundleVersion','CFBundleShortVersionString','CFBundleExecutable')),'Exported app identity differs from original archive')
        member=infos[0].rsplit('/',1)[0]+'/'+executable
        require(z.namelist().count(member)==1,'One exported executable required')
        with tempfile.TemporaryDirectory(prefix='bil48-exported-symbol-inspection-') as temp:
            selected=Path(temp)/executable;selected.write_bytes(z.read(member));exported_ids=uuids(selected)
    require(export_matches(archive_ids,exported_ids),'Exported IPA Runner UUID/architecture is not from original archive')
    dwarf_root=archive/'dSYMs';require(dwarf_root.is_dir(),'Original archive dSYMs folder required')
    inventory=[];runner=[]
    with zipfile.ZipFile(archive_zip) as z:
        names=z.namelist();require(len(names)==len(set(names)),'Ambiguous original archive ZIP members')
        for dwarf in sorted(dwarf_root.glob('*.dSYM/Contents/Resources/DWARF/*')):
            require(dwarf.is_file() and not dwarf.is_symlink() and dwarf.resolve().is_relative_to(archive.resolve()),'Regular original DWARF required')
            ids=uuids(dwarf);relative=dwarf.relative_to(archive).as_posix();member=archive.name+'/'+relative
            require(member in names,'An original DWARF is absent from retained archive ZIP')
            require(hashlib.sha256(z.read(member)).hexdigest()==digest(dwarf),'Retained archive ZIP DWARF differs')
            row={'relative_path':relative,'sha256':digest(dwarf),'uuids':ids};inventory.append(row)
            if dwarf.name==executable:runner.append(row)
        archived_member=archive.name+'/'+binary.relative_to(archive).as_posix()
        require(archived_member in names and hashlib.sha256(z.read(archived_member)).hexdigest()==digest(binary),'Retained original archive ZIP executable differs')
    require(len(runner)==1 and runner[0]['uuids']==archive_ids,'Exactly one matching original Runner dSYM is mandatory')
    frameworks=[]
    originals=framework_binaries(app)
    with zipfile.ZipFile(ipa) as exported_zip, zipfile.ZipFile(archive_zip) as retained_zip:
        exported_members=exported_framework_members(exported_zip,ipa_prefix)
        require(set(originals)==set(exported_members),
                'Original/archive and exported IPA framework executable inventory differs')
        with tempfile.TemporaryDirectory(prefix='bil48-exported-framework-inspection-') as temp:
            for relative,candidate in originals.items():
                ids=uuids(candidate)
                selected=Path(temp)/relative
                selected.parent.mkdir(parents=True,exist_ok=True)
                selected.write_bytes(exported_zip.read(exported_members[relative]))
                exported_framework_ids=uuids(selected)
                require(export_matches(ids,exported_framework_ids),
                        'Exported IPA framework UUID/architecture is not from original archive: '+relative)
                retained_member=archive.name+'/'+candidate.relative_to(archive).as_posix()
                require(retained_member in retained_zip.namelist()
                        and hashlib.sha256(retained_zip.read(retained_member)).hexdigest()==digest(candidate),
                        'Retained original archive ZIP framework executable differs: '+relative)
                match=[x for x in inventory if x['uuids']==ids]
                frameworks.append({'framework':candidate.parent.name,'relative_path':relative,
                    'uuids':ids,'exported_uuids':exported_framework_ids,
                    'export_binding':'EXACT' if exported_framework_ids==ids else 'ORIGINAL_ARCHITECTURE_SUBSET',
                    'original_dsym_status':'PRESENT_UUID_MATCH' if len(match)==1 else 'UNAVAILABLE_VENDOR_SYMBOLS_EXPLICIT' if not match else 'AMBIGUOUS'})
                require(len(match)<=1,'Duplicate vendor symbol UUID inventories')
    return {'status':'ORIGINAL_RUNNER_ARCHIVE_EXPORT_DSYM_UUID_PASS','source_sha':source,'build':48,'version':'1.0.0','run_id':run,'run_attempt':attempt,
            'ipa_sha256':digest(ipa),'original_archive_zip_sha256':digest(archive_zip),'runner_architecture_uuid_set':archive_ids,'exported_runner_architecture_uuid_set':exported_ids,
            'all_runtime_frameworks_archive_export_uuid_bound':True,
            'all_original_dwarfs':inventory,'vendor_frameworks':frameworks,'all_vendor_symbols_available':all(x['original_dsym_status']=='PRESENT_UUID_MATCH' for x in frameworks),
            'rebuilt_or_resigned':False,'rebuilt_or_resigned_field_scope':'THIS_INSPECTION_TOOL_ACTION_ONLY',
            'artifact_origin_requires_same_ci_build_export_and_hash_receipts':True,'physical_device_acceptance':'PENDING','store_submission_approved':False}
def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('archive','archive-zip','ipa','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--source',required=True);p.add_argument('--run',type=int,required=True);p.add_argument('--attempt',type=int,required=True)
    a=p.parse_args();require(not a.output.exists(),'Fresh symbol evidence output required')
    result=verify(a.archive,a.archive_zip,a.ipa,a.source,a.run,a.attempt)
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('IOS48_ORIGINAL_RUNNER_DSYM_UUID_BINDING=PASS;VENDOR_AVAILABILITY_EXPLICIT')
if __name__=='__main__':main()
