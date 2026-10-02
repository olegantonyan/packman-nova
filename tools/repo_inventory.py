"""Build docs/03-essentials-inventory.md tables from a Packman primary.xml(.gz)."""
import gzip, sys, collections, xml.etree.ElementTree as ET
ns={'c':'http://linux.duke.edu/metadata/common','rpm':'http://linux.duke.edu/metadata/rpm'}
path=sys.argv[1]
data=gzip.open(path).read() if path.endswith('.gz') else open(path,'rb').read()
root=ET.fromstring(data)
arch=collections.Counter(); bins=collections.defaultdict(set); srcs={}
for p in root.findall('c:package',ns):
    n=p.find('c:name',ns).text; a=p.find('c:arch',ns).text; v=p.find('c:version',ns); arch[a]+=1
    if a=='src':
        srcs.setdefault(n,set()).add(f"{v.get('ver')}-{v.get('rel')}"); continue
    s=p.find('c:format/rpm:sourcerpm',ns)
    if s is not None: bins[s.text.rsplit('-',2)[0]].add(n)
print('| arch | count |\n|---|---|'); [print(f'| {a} | {c} |') for a,c in sorted(arch.items())]
print('\n| source package | versions in repo | binary subpackages |\n|---|---|---|')
for n in sorted(set(srcs)|set(bins)):
    print(f"| {n} | {', '.join(sorted(srcs.get(n,[])))} | {', '.join(sorted(bins.get(n,[])))} |")
