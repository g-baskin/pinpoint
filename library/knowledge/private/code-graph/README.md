# Code Graph

> Category: Code Graph | Version: 1.0 | Date: November 2026 | Status: Active

Entry point for the Pinpoint code graph: what each diagram shows, how it was derived from the source, and how to regenerate it.

**Related:**
- [`module-graph.md`](module-graph.md)
- [`type-graph.md`](type-graph.md)
- [`flows.md`](flows.md)
- [`../architecture/README.md`](../architecture/README.md)
- [`../glossary/glossary.md`](../glossary/glossary.md)

---

## Snapshot

| Item | Value |
|---|---|
| Date | 27 November 2026 |
| Branch | `dev` |
| Commit | `66349de` (`git rev-parse --short HEAD`) |
| `Sources/` tree | `8144765` (`git rev-parse --short HEAD:Sources`) |
| Working tree | `git status -s -- Sources Package.swift` was empty, so the diagrams match the committed source exactly. Other files had uncommitted changes that do not affect the graph. |

If `Sources/` changes, regenerate with the commands below and update this table.

## What each diagram shows

| File | Diagrams | Size |
|---|---|---|
| [`module-graph.md`](module-graph.md) | Target-level graph from `Package.swift`; file-level flowcharts for inside PinpointCore, inside the app, and app-to-core, each target drawn as a subgraph; a ledger with the symbol and line behind every edge | 3 + 14 + 16 + 23 nodes; 2 + 26 + 36 + 35 edges (97 file edges in total) |
| [`type-graph.md`](type-graph.md) | Two class diagrams: capture data, editor and app ownership; AI providers (`LLMClient` and its four implementers), the edit agent and on-device analysis | 20 classes and 25 relationships; 30 classes and 37 relationships |
| [`flows.md`](flows.md) | Three sequence diagrams: capture from hotkey to saved library entry; agent edit from prompt to undoable markup; ChatGPT sign-in with loopback callback through the first model request | 10, 7 and 10 participants |

The file graph is split into three flowcharts because one diagram with all 30 files and 97 edges is unreadable. The class graph is split in two for the same reason.

## How it was derived

Edges in `module-graph.md` mean "file A names a symbol declared in file B". They were found in three passes.

**1. List top-level declarations.** Every type declared at column 0 in either target:

```bash
grep -nE '^\s*(public |internal |private |fileprivate |final |@MainActor |open )*(class|struct|enum|protocol|actor|extension|typealias) [A-Z][A-Za-z0-9_]*' Sources/*/*.swift
```

Free functions and module-level constants, which can also create edges:

```bash
grep -nE '^(public |private |fileprivate |internal )?(func|let|var) ' Sources/*/*.swift
grep -n 'extension' Sources/*/*.swift
```

This adds `extractJSONObject` (`JSONValue.swift:99`), `perform(_:session:)` (`LLM.swift:62`) and the notification name `pinpointLibraryChanged` (`EditorModel.swift:378-379`).

**2. Match every name against every other file.** This script strips comments and string literals, keeps only unindented (top-level) declarations so nested names such as `Coordinator`, `Options` or `Node` cannot create false edges, then reports which files use which names with word-boundary matching. Run it from the repository root with `python3 -I deps.py`:

```python
import re,glob,sys,collections
files=sorted(glob.glob('Sources/*/*.swift'))
def strip(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    s=re.sub(r'"""[\s\S]*?"""','""',s)
    s=re.sub(r'//[^\n]*','',s)
    s=re.sub(r'"(?:\\.|[^"\\\n])*"','""',s)
    return s
decl=re.compile(r'^(?:(?:public|internal|private|fileprivate|final|open|@MainActor)\s+)*(?:class|struct|enum|protocol|actor)\s+([A-Z]\w*)',re.M)
defs={}
src={f:strip(open(f).read()) for f in files}
for f in files:
    for m in decl.finditer(src[f]):
        name=m.group(1)
        # only top-level (no indentation)
        line=src[f][src[f].rfind('\n',0,m.start())+1:m.end()]
        if line.startswith((' ','\t')): continue
        defs.setdefault(name,f)
extra={'extractJSONObject':'Sources/PinpointCore/JSONValue.swift','perform':'Sources/PinpointCore/LLM.swift','pinpointLibraryChanged':'Sources/Pinpoint/EditorModel.swift'}
defs.update(extra)
for f in files:
    uses=collections.defaultdict(list)
    for n,df in defs.items():
        if df==f: continue
        pat=r'\b'+n+r'\b' if n!='perform' else r'(?<![.\w])perform\('
        if re.search(pat,src[f]): uses[df].append(n)
    for df,ns in sorted(uses.items()):
        print(f.split('/',1)[1],'->',df.split('/',1)[1],':',','.join(sorted(ns)))
```

**3. Confirm each edge by hand.** Each reported edge was checked with a grep for the symbol in the From file, for example:

```bash
grep -nw 'ChatGPTPlanClient' Sources/PinpointCore/LLM.swift Sources/Pinpoint/AppSettings.swift
grep -nw 'Renderer' Sources/Pinpoint/CaptureService.swift
grep -n 'perform(' Sources/Pinpoint/SelectionOverlay.swift Sources/PinpointCore/*.swift
```

The last check removed one false positive: `SelectionOverlay.swift:301` declares its own private `perform(_:)`, unrelated to `LLM.swift:62`. The script reported 98 edges; 97 remain. The core-to-app rule was checked twice, by the script (no `PinpointCore/... -> Pinpoint/...` lines) and by imports:

```bash
grep -h '^import' Sources/PinpointCore/*.swift | sort | uniq -c
grep -l '^import PinpointCore' Sources/Pinpoint/*.swift | wc -l
```

The first shows only system frameworks; the second reports 12 app files.

**Type graph and flows** were not generated by script. They came from reading the declarations listed in step 1 and the handlers cited in each doc's source ledger (for example `sed -n 118,223p Sources/Pinpoint/AppDelegate.swift`, `sed -n 205,253p Sources/PinpointCore/Agent.swift`, `sed -n 107,344p Sources/PinpointCore/ChatGPTPlan.swift`). Every class, relationship and message has a `file:line` reference next to its diagram.

## Checks and limits

The edge counts and the class and relationship counts were recounted from the written Markdown with `grep`. The Mermaid was not rendered or parsed: no local Mermaid CLI is installed, and the diagrams were not sent to a remote renderer. The flows describe the source as read; the app was not run to observe them. Symbol matching is textual, so a future type whose name equals a common identifier could create a false edge; step 3 exists to catch that.
