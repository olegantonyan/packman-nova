import urllib.request, xml.etree.ElementTree as ET, os, sys, urllib.parse
API='https://pmbs.links2linux.de/public/source/Essentials'
def get(u):
    with urllib.request.urlopen(u, timeout=120) as r: return r.read()
root=ET.fromstring(get(API))
pkgs=sorted({e.get('name').split(':')[0] for e in root.findall('entry')})
skip=lambda p: p.startswith(('A_16.','A_sr-','A_sle15','A_KMP'))
total=0; report=[]
for p in pkgs:
    if skip(p): continue
    d=ET.fromstring(get(f'{API}/{p}?expand=1'))
    if d.tag=='status': report.append((p,'ERR',d.get('code'))); continue
    rev=d.get('srcmd5'); os.makedirs(f'essentials-src/{p}',exist_ok=True)
    n=0;sz=0
    for e in d.findall('entry'):
        name=e.get('name'); dst=f'essentials-src/{p}/{name}'
        if not os.path.exists(dst) or os.path.getsize(dst)!=int(e.get('size')):
            open(dst,'wb').write(get(f'{API}/{p}/{urllib.parse.quote(name)}?expand=1&rev={rev}'))
        n+=1; sz+=int(e.get('size'))
    li=d.find('linkinfo'); kind=f"link:{li.get('project')}/{li.get('package')}" if li is not None else 'native'
    total+=sz; report.append((p,n,sz,kind))
for r in report: print(*r)
print('TOTAL bytes',total)
