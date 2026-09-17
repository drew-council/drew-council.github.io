#!/usr/bin/env nu
# Turn the "efficient terminal tools" post into an interactive herdr + presenterm
# presentation.
#
# Every `## section` of the post becomes a herdr workspace whose label is the
# section title. Inside it, a vertical split holds a plain shell on the left
# for live demos and a presenterm deck on the right showing that section's
# markdown. Sections listed in NO_DEMO only get the presenterm pane. DEMO_CWD
# picks the directory each demo shell opens in, and demo-command can start
# something in it (tuicr opens a review of your most recent PR).
#
# The decks are generated from index.md on every run, so edits to the post
# propagate. presenterm hot-reloads the file unless you pass --present via
# --presenterm-flags, so re-running the script while workspaces are open just
# refreshes the slides in place.
#
# Usage:
#   nu scripts/present.nu                       # into the current herdr session
#   nu scripts/present.nu --session talk        # into (and start) a named session
#   nu scripts/present.nu --dry-run             # only build the slide decks
#   nu scripts/present.nu --clean               # close the presentation workspaces first
#   nu scripts/present.nu --only cht-sh,yazi    # subset of sections (slugs)

const DEFAULT_POST = "content/posts/efficient_terminal_tools/index.md"

# Sections (by slug) that get only a slides pane; nothing to demo in a shell.
const NO_DEMO = [
  "intro"
  "philosophy"
  "prerequisite-you-need-a-good-tty"
  "herdr"
]

# Working directory for each demo section (by slug). Anything not listed
# uses DEFAULT_DEMO_CWD, or --cwd if given.
const DEFAULT_DEMO_CWD = "~/nixconf"
const DEMO_CWD = {
  "ripgrep-and-fd": "~/work/sheer"
  "gh": "~/work/sheer"
  "lazygit-and-lazydocker": "~/work/sheer"
  "gh-stack": "~/work/sheer"
  "tuicr": "~/work/sheer"
  "pi": "~/.pi"
}

# Logos rendered in the tty section to show off the kitty graphics protocol.
const LOGOS = [
  { name: "ghostty", url: "https://raw.githubusercontent.com/ghostty-org/ghostty/main/images/icons/icon_512.png" }
  { name: "kitty", url: "https://raw.githubusercontent.com/kovidgoyal/kitty/master/logo/kitty.png" }
  { name: "alacritty", url: "https://raw.githubusercontent.com/alacritty/alacritty/master/extra/logo/compat/alacritty-term.png" }
]

# Rough vertical cost of an image, in rows, when packing blocks into slides.
const IMAGE_ROWS = 14
# Rows presenterm uses for the slide title, margins and footer.
const CHROME_ROWS = 7
# Fallback pane size when no pane exists yet (dry run).
const DEFAULT_WIDTH = 90
const DEFAULT_ROWS = 40

def main [
  --post: string = "content/posts/efficient_terminal_tools/index.md"  # markdown source
  --session (-s): string  # herdr session name; started headless if not running
  --cwd: string  # working directory for demo shells not listed in DEMO_CWD (default: ~/nixconf)
  --out: string  # where generated decks and images go
  --only: string  # comma separated section slugs to set up
  --width: int = 0  # override the estimated slide width (columns)
  --rows: int = 0  # override the estimated slide height (rows)
  --presenterm-flags: string = ""  # extra flags for presenterm, e.g. "--present"
  --clean  # close existing presentation workspaces before creating them
  --focus  # focus the first workspace when done
  --dry-run  # only generate the decks, do not touch herdr
] {
  let post_path = $post | path expand
  let post_dir = $post_path | path dirname
  let repo_root = $post_dir | path join .. .. .. | path expand
  let fallback_cwd = if ($cwd | is-empty) { $DEFAULT_DEMO_CWD } else { $cwd } | path expand
  let build_dir = if ($out | is-empty) {
    $env.XDG_CACHE_HOME? | default ($env.HOME | path join .cache) | path join terminal-tools-presentation
  } else {
    $out | path expand
  }
  mkdir ($build_dir | path join images)
  mkdir ($build_dir | path join decks)

  let doc = load-post $post_path
  let all_sections = split-sections $doc.body $doc.title
  let wanted = if ($only | is-empty) { [] } else { $only | split row "," | each { str trim } }
  let sections = if ($wanted | is-empty) {
    $all_sections
  } else {
    $all_sections | where {|s| $s.slug in $wanted }
  }
  if ($sections | is-empty) {
    error make { msg: $"no sections matched --only ($only). known: ($all_sections | get slug | str join ', ')" }
  }

  if not $dry_run {
    if not ($session | is-empty) { use-session $session }
    if ($env.HERDR_SOCKET_PATH? | is-empty) and ($env.HERDR_ENV? | default "") != "1" {
      error make { msg: "not inside a herdr session; pass --session <name> or run from a herdr pane" }
    }
    if $clean { clean-workspaces ($sections | get title) }
  }

  let existing = if $dry_run { [] } else { herdr-json [workspace list] | get workspaces }

  mut summary = []
  for sec in $sections {
    let deck = $build_dir | path join decks $"($sec.index | fill --width 2 --alignment right --character "0")-($sec.slug).md"
    let demo = $sec.slug not-in $NO_DEMO
    let demo_cwd = demo-cwd $sec.slug $fallback_cwd
    let already = $existing | where label == $sec.title

    if $dry_run {
      let ctx = make-ctx $post_dir $build_dir $width $rows $DEFAULT_WIDTH $DEFAULT_ROWS
      render-deck $sec $ctx | save -f $deck
      $summary = ($summary | append { section: $sec.title, demo: $demo, workspace: "(dry run)", deck: $deck })
      continue
    }

    if ($already | is-not-empty) {
      # presenterm hot reloads the deck, so just regenerate it in place.
      let ws = $already | first
      let slides_pane = herdr-json [pane list --workspace $ws.workspace_id]
        | get panes
        | last
      let rect = pane-rect $slides_pane.pane_id
      let ctx = make-ctx $post_dir $build_dir $width $rows $rect.width $rect.height
      render-deck $sec $ctx | save -f $deck
      $summary = ($summary | append { section: $sec.title, demo: $demo, workspace: $"($ws.workspace_id) updated", deck: $deck })
      continue
    }

    let created = herdr-json [workspace create --cwd $demo_cwd --label $sec.title --no-focus]
    let ws_id = $created.workspace.workspace_id
    let root = $created.root_pane.pane_id

    let slides_pane = if $demo {
      let split = herdr-json [pane split $root --direction right --ratio 0.5 --cwd $demo_cwd --no-focus]
      herdr-json [pane rename $root demo] | ignore
      $split.pane.pane_id
    } else {
      $root
    }
    herdr-json [pane rename $slides_pane slides] | ignore

    let rect = pane-rect $slides_pane
    let ctx = make-ctx $post_dir $build_dir $width $rows $rect.width $rect.height
    render-deck $sec $ctx | save -f $deck

    let cmd = $"presenterm ($presenterm_flags) '($deck)'" | str replace --all --regex '\s+' ' '
    herdr-json [pane run $slides_pane $cmd] | ignore

    if $demo {
      let demo_cmd = demo-command $sec.slug $demo_cwd
      if ($demo_cmd | is-not-empty) { herdr-json [pane run $root $demo_cmd] | ignore }
    }

    $summary = ($summary | append { section: $sec.title, demo: $demo, workspace: $ws_id, deck: $deck })
  }

  if $focus and not $dry_run {
    let first = $summary | first | get workspace | split row " " | first
    if ($first | str starts-with "w") { herdr-json [workspace focus $first] | ignore }
  }

  print $summary
  print $"decks written to ($build_dir | path join decks)"
}

# --- demos --------------------------------------------------------------------

def demo-cwd [slug: string, fallback: string] {
  let dir = $DEMO_CWD | get --optional $slug | default $fallback | path expand
  if ($dir | path exists) {
    $dir
  } else {
    print --stderr $"warning: ($dir) does not exist for ($slug), using ($fallback)"
    $fallback
  }
}

# Command to launch in the demo shell once it is open, so the section starts
# with something on screen. Empty means leave the shell at its prompt.
def demo-command [slug: string, cwd: string] {
  match $slug {
    "tuicr" => {
      let pr = recent-own-pr $cwd
      if ($pr | is-empty) { "" } else { $"tuicr pr ($pr)" }
    }
    _ => ""
  }
}

# Number of the most recently updated PR authored by the current gh user in
# the repo at cwd, preferring open ones.
def recent-own-pr [cwd: string] {
  for state in [open all] {
    let res = do { cd $cwd; ^gh pr list --author @me --state $state --limit 1 --json number } | complete
    if $res.exit_code != 0 {
      print --stderr $"warning: gh pr list failed in ($cwd): ($res.stderr | str trim)"
      return ""
    }
    let prs = $res.stdout | from json
    if ($prs | is-not-empty) { return ($prs | first | get number | into string) }
  }
  print --stderr $"warning: no PRs by you found in ($cwd)"
  ""
}

# --- markdown -----------------------------------------------------------------

def load-post [path: string] {
  let raw = open --raw $path
  let parts = $raw | split row "+++"
  let front = $parts | get 1
  let title = $front | parse --regex 'title = "(?<t>[^"]+)"' | get 0.t
  let body = $parts | skip 2 | str join "+++"
    | str replace --regex '(?s)<!-- mdformat-toc start.*?mdformat-toc end -->' ''
  { title: $title, body: $body }
}

def slugify [s: string] {
  $s | str downcase | str replace --all --regex '[^a-z0-9]+' '-' | str trim --char '-'
}

# Split the body on `## ` headings. Everything before the first heading is the
# intro, titled after the post itself. Footnote definitions are pulled out and
# attached to whichever section references them.
def split-sections [body: string, post_title: string] {
  mut sections = []
  mut current = { title: $post_title, slug: "intro", lines: [] }
  mut fence = false
  mut footnotes = {}
  for line in ($body | lines) {
    if ($line | str trim | str starts-with '```') { $fence = not $fence }
    let fn = $line | parse --regex '^\[\^(?<id>[^\]]+)\]: (?<text>.*)$'
    if (not $fence) and ($line | str starts-with "## ") {
      $sections = ($sections | append $current)
      let title = $line | str substring 3.. | str trim
      $current = { title: $title, slug: (slugify $title), lines: [] }
    } else if (not $fence) and ($fn | is-not-empty) {
      $footnotes = ($footnotes | insert $fn.0.id $fn.0.text)
    } else {
      $current.lines = ($current.lines | append $line)
    }
  }
  $sections = ($sections | append $current)

  let notes = $footnotes
  $sections | enumerate | each {|it|
    let sec = $it.item
    let text = $sec.lines | str join "\n"
    let used = $notes | columns | where {|id| $text | str contains $"[^($id)]" }
    $sec | insert index $it.index | insert footnotes ($used | each {|id| $"[^($id)]: ($notes | get $id)" })
  }
}

def make-ctx [post_dir: string, build_dir: string, width: int, rows: int, pane_width: int, pane_rows: int] {
  {
    post_dir: $post_dir
    repo_root: ($post_dir | path join .. .. .. | path expand)
    build_dir: $build_dir
    width: (if $width > 0 { $width } else { [($pane_width - 12) 40] | math max })
    rows: (if $rows > 0 { $rows } else { [($pane_rows - $CHROME_ROWS) 12] | math max })
  }
}

# Render one section into a presenterm deck: hugo shortcodes and asciinema
# casts dropped, links flattened to their text (and collected on a final
# slide), images resolved to absolute paths, and paragraphs packed into slides
# that fit the pane.
def render-deck [sec: record, ctx: record] {
  mut lines = []
  mut links = []
  mut fence = false
  for line in $sec.lines {
    let trimmed = $line | str trim
    if ($trimmed | str starts-with '```') {
      $fence = not $fence
      $lines = ($lines | append $line)
      continue
    }
    if $fence {
      $lines = ($lines | append $line)
      continue
    }
    let include = $trimmed | parse --regex '^\{\{< include-html "(?<path>[^"]+)" >\}\}$'
    if ($include | is-not-empty) {
      # The post embeds pre-rendered terminal output as HTML; show it as plain text.
      $lines = ($lines | append ([""] | append (html-as-code $include.0.path $ctx) | append ""))
      continue
    }
    if ($trimmed | str starts-with '{{<') and ($trimmed | str ends-with '>}}') { continue }
    if ($trimmed | str starts-with '<!--') and ($trimmed | str ends-with '-->') { continue }
    if ($trimmed =~ '^-{3,}$') { continue }

    let line = $line | str replace --all --regex '<figcaption>(.*?)</figcaption>' '_${1}_'

    let img = $line | parse --regex '^\[?!\[[^\]]*\]\((?<src>[^)\s]+)'
    if ($img | is-not-empty) {
      let resolved = resolve-image $img.0.src $ctx
      if ($resolved | is-not-empty) {
        $lines = ($lines | append $"![image:width:70%]\(($resolved)\)")
      }
      continue
    }

    $links = ($links | append (find-links $line))
    $lines = ($lines | append (strip-links $line))
  }

  mut blocks = to-blocks $lines
  if ($sec.footnotes | is-not-empty) {
    for note in $sec.footnotes { $links = ($links | append (find-links $note)) }
    $blocks = ($blocks | append [($sec.footnotes | each {|n| strip-links $n })])
  }
  if ($links | is-not-empty) {
    let list = $links | uniq-by url | each {|l| $"- ($l.text): ($l.url)" }
    $blocks = ($blocks | append [(["## links"] | append $list)])
  }

  let slides = pack-slides $blocks $ctx
  let heading = $"# ($sec.title)"
  let body = $slides
    | each {|blocks| [$heading] | append ($blocks | each {|b| $b | str join "\n" }) | str join "\n\n" }
    | str join "\n\n<!-- end_slide -->\n\n"

  let extra = extra-slides $sec $ctx
  let front = if $sec.slug == "intro" {
    $"---\ntitle: ($sec.title)\nsub_title: the terminal tools i wish someone had forced me to try years ago\n---\n\n"
  } else {
    ""
  }
  $front + $body + $extra + "\n"
}

def find-links [line: string] {
  $line | parse --regex '\[(?<text>[^\]]+)\]\((?<url>https?://[^)\s]+)'
}

# `[text](url)` -> `text`; presenterm would otherwise print the url inline.
def strip-links [line: string] {
  $line | str replace --all --regex '\[([^\]\[]+)\]\([^)]*\)' '${1}'
}

# Strip the tags from one of the pre-rendered html snippets and return it as a
# fenced code block, truncated so it fits on a slide.
def html-as-code [rel_path: string, ctx: record] {
  let path = $ctx.repo_root | path join $rel_path
  if not ($path | path exists) {
    print --stderr $"warning: included html not found, skipping: ($path)"
    return []
  }
  let text = open --raw $path
    | str replace --all --regex '<[^>]*>' ''
    | str replace --all '&lt;' '<'
    | str replace --all '&gt;' '>'
    | str replace --all '&quot;' '"'
    | str replace --all '&#39;' "'"
    | str replace --all '&amp;' '&'
    | str trim
    | lines
  let cap = [($ctx.rows - 6) 8] | math max
  let body = if ($text | length) > $cap {
    $text | first ($cap - 1) | append "..."
  } else {
    $text
  }
  ["```"] | append $body | append "```"
}

def to-blocks [lines: list<string>] {
  mut blocks = []
  mut cur = []
  mut fence = false
  for line in $lines {
    if ($line | str trim | str starts-with '```') { $fence = not $fence }
    if (not $fence) and (($line | str trim) == "") {
      if ($cur | is-not-empty) {
        $blocks = ($blocks | append [$cur])
        $cur = []
      }
    } else {
      $cur = ($cur | append $line)
    }
  }
  if ($cur | is-not-empty) { $blocks = ($blocks | append [$cur]) }
  $blocks
}

def block-height [block: list<string>, width: int] {
  let rows = $block | each {|l|
    if ($l | str starts-with '![') {
      $IMAGE_ROWS
    } else if ($l | str starts-with '#') {
      2
    } else {
      [1 (($l | str length) / $width | math ceil)] | math max
    }
  } | math sum
  $rows + 1
}

def pack-slides [blocks: list, ctx: record] {
  mut slides = []
  mut cur = []
  mut height = 0
  for block in $blocks {
    let h = block-height $block $ctx.width
    if ($cur | is-not-empty) and ($height + $h > $ctx.rows) {
      $slides = ($slides | append [$cur])
      $cur = []
      $height = 0
    }
    $cur = ($cur | append [$block])
    $height = $height + $h
  }
  if ($cur | is-not-empty) { $slides = ($slides | append [$cur]) }
  if ($slides | is-empty) { [[]] } else { $slides }
}

# Resolve a post-relative image to an absolute path presenterm can load,
# converting webp (unsupported by presenterm) to png in the build dir.
def resolve-image [src: string, ctx: record] {
  let clean = $src | split row '#' | first
  let abs = $ctx.post_dir | path join $clean
  if not ($abs | path exists) {
    print --stderr $"warning: image not found, skipping: ($abs)"
    return ""
  }
  let parsed = $abs | path parse
  if $parsed.extension != "webp" { return $abs }
  let out = $ctx.build_dir | path join images $"($parsed.stem).png"
  if ($out | path exists) { return $out }
  let attempts = [
    { ^magick $abs $out }
    { ^sips -s format png $abs --out $out }
  ]
  for convert in $attempts {
    let res = do $convert | complete
    if $res.exit_code == 0 and ($out | path exists) { return $out }
  }
  print --stderr $"warning: could not convert ($abs) to png, skipping"
  ""
}

# Section specific additions that are not in the post itself.
def extra-slides [sec: record, ctx: record] {
  match $sec.slug {
    "prerequisite-you-need-a-good-tty" => {
      let logos = $LOGOS | each {|l| $l | insert path (fetch-logo $l $ctx) } | where path != ""
      if ($logos | is-empty) { return "" }
      let ratio = $logos | each { 1 } | to json --raw
      let columns = $logos | enumerate | each {|it|
        $"<!-- column: ($it.index) -->\n\n![image:width:80%]\(($it.item.path)\)\n\n($it.item.name)"
      } | str join "\n\n"
      [
        ""
        "<!-- end_slide -->"
        ""
        $"# ($sec.title)"
        ""
        "images in the terminal, via the kitty graphics protocol:"
        ""
        $"<!-- column_layout: ($ratio) -->"
        ""
        $columns
        ""
        "<!-- reset_layout -->"
        ""
        "nerd font icons:      󰊢   "
      ] | str join "\n"
    }
    _ => ""
  }
}

def fetch-logo [logo: record, ctx: record] {
  let out = $ctx.build_dir | path join images $"($logo.name).png"
  if ($out | path exists) { return $out }
  let res = ^curl -sfL -o $out $logo.url | complete
  if $res.exit_code != 0 {
    print --stderr $"warning: could not download ($logo.name) logo from ($logo.url)"
    return ""
  }
  $out
}

# --- herdr --------------------------------------------------------------------

def herdr-json [args: list<string>] {
  let res = ^herdr ...$args | complete
  if $res.exit_code != 0 {
    error make { msg: $"herdr ($args | str join ' ') failed: ($res.stderr | str trim)" }
  }
  # some commands (pane run, for one) print nothing on success
  if ($res.stdout | str trim | is-empty) { return null }
  $res.stdout | from json | get result
}

def pane-rect [pane_id: string] {
  herdr-json [pane layout --pane $pane_id]
    | get layout.panes
    | where pane_id == $pane_id
    | first
    | get rect
}

# Point the herdr CLI at a named session, starting a headless server if needed.
def --env use-session [name: string] {
  let running = ^herdr session list --json | from json | get sessions | where name == $name and running == true
  if ($running | is-empty) {
    print $"starting headless herdr session '($name)'"
    ^bash -c $"nohup herdr --session '($name)' server >/dev/null 2>&1 &"
    mut tries = 0
    while $tries < 20 {
      sleep 250ms
      let now = ^herdr session list --json | from json | get sessions | where name == $name and running == true
      if ($now | is-not-empty) { break }
      $tries = $tries + 1
    }
  }
  let sessions = ^herdr session list --json | from json | get sessions | where name == $name and running == true
  if ($sessions | is-empty) {
    error make { msg: $"could not start herdr session '($name)'" }
  }
  $env.HERDR_SOCKET_PATH = ($sessions | first | get socket_path)
  print $"attach with: herdr session attach ($name)"
}

def clean-workspaces [titles: list<string>] {
  let stale = herdr-json [workspace list] | get workspaces | where label in $titles
  for ws in $stale {
    print $"closing workspace ($ws.workspace_id) \(($ws.label)\)"
    herdr-json [workspace close $ws.workspace_id] | ignore
  }
}
