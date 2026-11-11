from pathlib import Path
import sys,plistlib,struct,json
app=Path(sys.argv[1]);info=plistlib.loads((app/'Info.plist').read_bytes());binary=app/info['CFBundleExecutable'];b=binary.read_bytes();assert b[:4]==b'\xcf\xfa\xed\xfe','Expected64-bit little-endian Mach-O';assert struct.unpack_from('<I',b,4)[0]==0x0100000c,'ExpectedARM64 device build'
for p in app.rglob('*'):
 assert not p.is_symlink(),'No unreviewed symlink in code-only artifact'
 assert p.suffix.lower()not in ['.mp4','.mov','.jpg','.jpeg','.png','.p12','.pk8','.mobileprovision'],'Unexpected private media/key/profile: '+p.name
 assert '_CodeSignature'not in p.parts,'Expected unsigned app'
assert 'Build-stage placeholder'in(app/'Web/index.html').read_text()
print(json.dumps({'unsigned_code_only':True,'arm64':True,'private_media':False,'apple_credentials_or_profiles':False,'bundle':info['CFBundleIdentifier']}))
