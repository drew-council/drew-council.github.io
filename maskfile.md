## server

> Start hugo server locally with drafts

```bash
hugo server --buildDrafts --buildFuture
```

## start

> Start zellij session with server running

```bash
set -x

session="personal-site"
zellij kill-session $session || true
zellij delete-session $session || true
zellij --layout layout_file.kdl attach --create $session
```

## open

> Open the local site in chromium

```bash
hyprctl dispatch exec "chromium-browser http://localhost:1313/"
```

## update-date (file)

> Update the date in the header of the site

```python
import os
from datetime import datetime
from pathlib import Path
from scripts.front_matter import load_file, dump_file

file = Path(os.getenv("file", "."))

post = load_file(file)
post["date"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S%z")
dump_file(post, file)
```

## resume

> Use pandoc to make a PDF of the resume doc

```python
import os
import pypandoc
from pathlib import Path
from scripts.front_matter import load_file

file = Path("content/resume/index.md")
post = load_file(file)
content = "\n".join(post.content.splitlines()[2:])

pypandoc.convert_text(
    source=content,
    format="md",
    to="pdf",
    outputfile=file.parent / "resume.pdf",
    extra_args=["-V", "geometry:margin=0.5in"],
)
```

## present

> Turn the terminal tools post into herdr workspaces with presenterm decks

**OPTIONS**

- session
  - flags: -s --session
  - type: string
  - desc: herdr session to use (started headless if not running; default is the current one)
- clean
  - flags: --clean
  - desc: close the presentation workspaces before creating them

```bash
nu scripts/present.nu ${session:+--session "$session"} ${clean:+--clean}
```

## post (name)

> Create a new post with correct structure

```bash
hugo new content content/posts/$name/index.md \
  --editor zeditor
# TODO: add sed for title replace
```
