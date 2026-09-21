+++
date = "2025-07-29T22:19:41"
lastmod = "2026-09-16T00:00:00"
draft = false
title = "efficient terminal tools"
+++

In this post, I hope to give the best, most useful, and most practical terminal-based tools that I regularly use. These are the tools I wish someone had forced me to try years ago, so I hope to convince you to try them here.

> This post was originally written for a presentation I gave to coworkers in 2025. I updated it in September 2026 for a second presentation, and I plan to keep updating it with any new discoveries I make.

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [philosophy](#philosophy)
- [prerequisite: you need a good tty](#prerequisite-you-need-a-good-tty)
- [cht.sh](#chtsh)
- [ripgrep and fd](#ripgrep-and-fd)
- [atuin](#atuin)
- [yazi](#yazi)
- [lazygit and lazydocker](#lazygit-and-lazydocker)
- [nushell](#nushell)
- [gh-stack](#gh-stack)
- [tuicr](#tuicr)
- [herdr](#herdr)
- [pi](#pi)

<!-- mdformat-toc end -->

---

As I progressed in my education and experience as a software engineer, I received a lot of guidance as to how to improve how my software was structured. However, I was never really instructed on the _process_ of creating that software. I moved between Eclipse, JetBrains, and VS Code without ever really learning how to navigate a codebase quickly, script programs together, or work with `git` beyond the dreaded:

```bash
git add . && git commit -m "changes" && git push
```

<figcaption>still a classic, but there is so much more</figcaption>

Later, I saw online what certain engineers and [bash wizards](https://www.youtube.com/watch?v=L967hYylZuc) were capable of. Certain things feel intractable, like mastering every `awk` and `bash` nuance. However, as I used the tools, I got more comfortable and began to move faster.

There has also been an influx of usability improvements. As developer interest grows in languages like Rust and Zig, the chance to redesign from scratch has led to a new wave of excellent, easy-to-use tools.

---

## philosophy

Before the tools themselves, three rules that shape which ones I pick and how I use them.

**Use open source tools.** Every tool below has its source on GitHub. That means I can read how it works when the docs fall short, I can fix it when it breaks, and it does not vanish or change its pricing model when a company pivots.

**Define stuff in code.** All of my configuration for every tool in this post lives in [my nixconf repo](https://github.com/drew-council/nixconf). Keybinds, themes, aliases, and the tools themselves are declared in Nix and applied with [home-manager](https://github.com/nix-community/home-manager). A new laptop goes from blank to my full setup with one command. The bigger win is that every tweak is a commit, so I can `git blame` my own config to remember why I set something six months ago.

**If it gets in your way, patch it.** Open source plus config-as-code makes this cheap. When a tool does something I don't like, I fork it, make a small change on a branch, and point my flake input at that branch. I have done this for [tuicr](#tuicr) to add `nu` syntax highlighting and to fix reviewing very large PRs. Neither change was more than a few dozen lines. You do not need to be a maintainer to fix the one thing that annoys you.

---

## prerequisite: you need a good tty

> I will cry if you run these in Command Prompt.

Terminal applications can only do so much if the surrounding terminal interface is poor.

**For Linux and Mac**, I highly recommend either [kitty](https://sw.kovidgoyal.net/kitty/) or [ghostty](https://ghostty.org/). Both have excellent performance and support all the fancy terminal features. Namely, they work with the [kitty terminal graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/) that lets you display images in the terminal!

**For Windows**, [alacritty](https://alacritty.org/index.html) is the best native option I have found. Not _quite_ as feature-rich in my experience, but the only tty of this class that is windows-native (that I have found).

**Also important:** Install a [Nerd Font](https://www.nerdfonts.com/)! Many programs depend on these for icons.

---

## cht.sh

When the maze of arguments and options are starting to slow you down, **[cht.sh](https://cht.sh/) is your best friend**. At any terminal with internet access, you can use it to search for command-line tools and their usage.

Lets say you are trying to do a simple tar operation.

[![hugo](images/tar.webp#large "Obligatory xkcd.")](https://xkcd.com/1168/)

First, you can use it directly from your browser _or through curl_: `curl cht.sh/tar`

Or, you can install their [command line client](https://github.com/chubin/cheat.sh#command-line-client-chtsh). I prefer this, as you don't need to use URL syntax to search. I'll run `cht.sh tar`:

{{< include-html "content/posts/efficient_terminal_tools/html/cht_sh.html" >}}

---

## ripgrep and fd

When I speak of older tools getting a modern redesign, these are probably the prime examples.

**[fd](https://github.com/sharkdp/fd) and [ripgrep](https://github.com/BurntSushi/ripgrep)** are fantastic alternatives to `find` and `grep`, and are multi-threaded by default. [^multi-thread] They have become my default for scripting operations to find certain regex patterns and file names quickly.

{{< asciicast src="/casts/rg_fd.demo" >}}

---

## gh

This section is basically here to say: **stop trying to script GitHub with `curl`!**

**[gh](https://github.com/cli/cli)** provides a helpful wrapper over many GitHub APIs and `git` operations. This integration allows for commands like `gh repo clone drew-council/nixconf`, which clones based on the GitHub repo name using your preference setting for SSH/HTTP. It also lets you make queries like `gh repo list --visibility=public`:

```
NAME                     DESCRIPTION              INFO              UPDATED
drew-council/nixconf     Nix Configuration Files  public            about 1 hour ago
drew-council/drew-cou...                           public            about 2 hours ago
drew-council/nixpkgs     Nix Packages collect...  public, fork      about 19 hours ago
drew-council/typeracer-FPGA                           public, archived  about 4 days ago
drew-council/hugo        The world’s fastest ...  public, fork      about 4 days ago
drew-council/zed         configuration for ze...  public            about 5 days ago
...
```

`gh` can output as `json`, which can be used in scripting quite easily.

---

## atuin

One of the most aggravating thing about working in the terminal can be when you know you have run a command before but it can't be found in your history. Maybe it was in another session, maybe your history ran out of space, or maybe it was run on a completely different machine.

**[atuin](https://github.com/ellie/atuin)** is a terminal history manager that aims to always capture the history of the commands you run. This means syncing across sessions, windows, different terminals, and even different devices if you choose.

It stores all of your command history in a local SQLite database and replaces your `CTRL+R` search with a fuzzyfind of that history database in a nice TUI.

{{< asciicast src="/casts/atuin.demo" speed=1.5 >}}

---

## yazi

`cd` and `ls` get you surprisingly far, but sometimes you just want to _look around_ a directory.

**[yazi](https://github.com/sxyazi/yazi)** is a file manager TUI with vim keybinds. It shows three columns: the parent directory, the current directory, and a preview of whatever is under the cursor. Press `h` and `l` to move up and down the tree, `j` and `k` to move through files, and `Enter` to open one.

The preview pane is what sold me on it. Source files get syntax highlighting. Images, PDFs, and even video thumbnails render right in the terminal through the kitty graphics protocol. I use it constantly to skim through a folder of screenshots or check a diagram without leaving the shell.

The other trick is the shell wrapper. I have it aliased to `y`, and when I quit `yazi`, my shell is now in whatever directory I navigated to. It ends up being a much faster way to get somewhere deep in a repo than tab-completing a path.

---

## lazygit and lazydocker

`lazygit` and `lazydocker` are wonderful TUIs for `git` and `docker` respectively by [@jesseduffield](https://github.com/jesseduffield/).

{{< asciicast src="/casts/lazytui.demo" speed=2 >}}

<figcaption>When you learn just a few keyboard shortcuts, you can really move quickly in these tools.</figcaption>

In both, the keybinds are nicely displayed for you at the bottom, but you can even _use your mouse_.

Both have almost entirely replaced most of the `docker` and `git` calls I would type out before. `lazygit` especially has completely changed how I work with git, as it allows for quickly selecting files to add, exclude, and discard from your working `git` changes to your commit.

---

## nushell

[Nushell](https://www.nushell.sh/) is my absolute favorite of these tools.

It is probably wrong to even call it a _tool_, as `nu` is a fully-fledged _shell_ which can be in lieu of `bash`/`zsh`/`fish`. [^posix] The key feature that sets `nu` apart from these is **Pipelines**.

Pipelines are a lot like traditional piping of stdin to stdout, but in `nu` they can store _structured data_. These look a lot like `json` and are printed as nicely formatted tables. You can then use the `nu` language functional operators to do some fairly powerful things:

{{< asciicast src="/casts/nushell.demo" >}}

Here's a `nu` script to get the Git-LFS files in a repo and sort by the ones using the most space.

```nu
#!/usr/bin/env nu

let lfs_file_data = (
  git lfs ls-files --size |
    detect columns -n |
    reject column1 |
    rename hash file size |
    update size {|row| $row.size | str substring 1..-2 | into filesize} |
    sort-by size
)

print $lfs_file_data

let total_size = ($lfs_file_data | get size | math sum)
print $"Total size: ($total_size)"
```

Here's what the script output looks like:

{{< include-html "content/posts/efficient_terminal_tools/html/lfs_sizes.html" >}}

The nice things here:

- `git lfs` commands don't have the ability to output `json`, but you can just pipe them into `detect columns` and it will figure the data structure out for you!
- There is a first-class `filesize` datatype, which we convert a string to and sort by. I don't even want to know the crazy scripting it would take to properly compare mega**bits** with kilo**bytes** without this.
- The biggest selling point for me: _I didn't have to look up anything._ No googling. No reading manpages. `nu` has a very high skill floor, and it can become very powerful if you take the time to read through the [excellent Nushell Book](https://www.nushell.sh/book/).

---

## gh-stack

Large PRs are hard to review. The usual advice is to split them up, but then you have three branches that depend on each other, and a change to the first one means manually rebasing the other two.

**[gh-stack](https://github.com/github/gh-stack)** is a `gh` extension that manages that chain for you. A stack is an ordered list of branches, each based on the one below it, with one PR per branch. The reviewer for each PR only sees that layer's diff.

```
(main) <- auth <- api <- frontend
```

The workflow is `gh stack init auth` for the first layer, commit, then `gh stack add api` for the next, and so on. When you are done, `gh stack submit` pushes every branch and opens the PRs with the right base branches.

The part I use the most is going back in history. When a reviewer asks for a change in the bottom layer, I check out that branch, make the commit, and run one command to replay every branch above it:

```bash
gh stack down
git commit -am "address review on auth"
gh stack rebase --upstack
gh stack top
gh stack push
```

Every PR in the stack updates, and none of the upper layers show the bottom layer's change in their diff. When the bottom PR merges, `gh stack sync` rebases the rest onto trunk and cleans up. I have a small `gs` wrapper in my nixconf that adds single-letter aliases and a `review` command to open a stack's layers in [tuicr](#tuicr).

---

## tuicr

Reviewing code in a browser is slow. Every file expands and collapses, comments open little text boxes, and none of it responds to the keyboard.

**[tuicr](https://github.com/agavra/tuicr)** is a code review TUI with vim keybinds. It shows one continuous diff across every changed file, so you scroll through the whole change with `j` and `k`. Press `c` on a line to leave a comment, `v` to select a range, and it tracks which hunks you have already reviewed across sessions. You can point it at a commit range, your working tree, or a PR number with `tuicr pr 1234`.

When you are done, you pick where the review goes. It can post as a real GitHub review, with every comment attached to the right line. Or it copies the whole thing to your clipboard as structured markdown. The second option is the one I did not expect to use so much. Paste that markdown into a coding agent and it has the file, line numbers, and your comment for every item, so it can go address all of them at once.

This is also the tool I patched most recently. The upstream version had no syntax highlighting for `nu` scripts and could not open PRs with more than a few hundred files. Both were small fixes, and my flake points at [my branch](https://github.com/drew-council/tuicr/tree/bizmythy-tweaks) until they land upstream.

---

## herdr

If you have used `tmux` you know the pitch: one terminal holds many shells, and they keep running when you disconnect. You also know that getting `tmux` to feel nice takes an afternoon of config.

**[herdr](https://github.com/herdrdev/herdr)** is a terminal multiplexer that ships nicely configured out of the box, and it is built around running coding agents. Workspaces hold tabs, tabs hold panes, and a sidebar shows every workspace with the status of any agent running in it. You can see at a glance which agents are working, which are done, and which are blocked waiting on you.

**Detach and resume from anywhere.** The server runs separately from the client, so closing my laptop lid or dropping an SSH connection does not touch the sessions. I attach to my desktop from my laptop over `herdr --remote`, and the layout is exactly where I left it. I also serve it as a web terminal on my home network, so I can check on a long-running agent from my phone. The mobile layout collapses to a single column, and it is surprisingly usable.

**Easy tabbing around.** The defaults are already good, but I bound the common actions to `alt+` chords so they are one keypress: `alt+t` for a new tab, `alt+v` and `alt+-` to split, `alt+hjkl` to move between panes. It is basically `tmux` with someone else's well-tuned config.

**A CLI and a skill for agents.** Every part of the session is reachable through a socket API and the `herdr` CLI. Agents can split a pane, launch another agent in it, send it a prompt, wait for its status to change, and read its output. Herdr ships an [agent skill](https://herdr.dev/docs/agent-skill/) that teaches this to any agent running inside a pane. This turns into a very powerful way to run a lot of work at once. I can ask one agent to fan a task out to three others in separate worktrees, then check in on each from the sidebar rather than a wall of nested tool output.

**An extension system.** Plugins are a small manifest plus any executable. Herdr calls the executable for a keybind, and the executable talks back over the socket. Mine is a [Go program in my nixconf](https://github.com/drew-council/nixconf/tree/main/home/programs/herdr) that adds directional navigation across panes, tabs, and workspaces, an `alt+g` popup for `lazygit` and `alt+b` for `btop`, and a workspace picker that creates a new git worktree and opens it in one step. The plugin manifest and the keybind config are generated from the same Nix expression, so adding a popup app is a three-line change.

---

## pi agent

The `pi` agent is a open source, highly extensible coding agent. It provides a harness for interacting with various model providers and a TUI for interfacing with said harness. It also provides a rich API for extending every aspect of the application in TypeScript.

Critically, it also exposes documentation for this TypeScript extension system _to the agent itself_, allowing you to use `pi` to make changes to itself!

This confers a _lot_ of benefits:

### model providers

With `pi`, I can easily switch between model providers. When I do this, I can keep the same tooling, skills, interface, etc. Most other harnesses (claude code, codex, etc) try to get you to lean on vendor-specific affordances like claude workflows or codex apps, but these have trouble getting adapted to other model providers.

This has been especially helpful as of late, with the release of several capable and extremely cheap open source models. I am able to quickly switch provider and model based on the task at hand. This can extend nicely to things like using Fable 5.1 to orchestrate a subagent team of GLM 5.3 flash models, for example.

### endless tweaking

If part of the interface to the agent irk you, it is quite possible to tweak it to your heart's desire or to extend as you wish.

I've always been annoyed at the typical text entry boxes for the other harnesses, and I wanted true Vim-style editing. In `pi`, I was able to embed an actual headless `neovim` instance which provides a seamless editing experience in the prompt field, while preserving the stock pi features like auto-complete.

As for extending, the TUI API provided makes it trivial to make custom `/usage` displays covering your accounts, add profile switching, change status-lines, and whatever else you might want to adjust.

### integrated tools

`pi` lets you expose custom tools to your agent quite easily that can do a number of things. These can integrate with the TUI of the application to allow for some very nice human-in-the-loop workflows.

A good example of this is my `/address-review-comments` workflow. It does the bookkeeping of pulling all the contextual info about the pull request reviews for the agent and prompts it to work through each comment and present a checkpoint. This checkpoint displays a TUI menu where I can give feedback until it's right, then submit the changes. The actual GitHub operations get nicely abstracted from the agent and parallelized where possible to make for a very reliable experience.

### recommendations

Run this to install my recommended extensions:

```bash
pi install \
  npm:pi-web-access \ # allows for searching the web
  npm:pi-multi-skills \ # invoke multiple skills in one prompt with $
  npm:pi-claude-bridge \ # connect to claude code and use usage-based spend
  npm:@bizmyth/pi-review \ # my custom self-review workflow
  npm:@bizmyth/pi-git-conflicts \ # my custom git conflict resolution workflow
  npm:@bizmyth/pi-address-review-comments \ # my custom github review comment addressing workflow
```

For those who are vim/neovim users, I'd also recommend my `npm:@bizmyth/pi-neovim-editor` extension. It uses a real headless `neovim` (using their new embedded mode) to give a full-accuracy vim editing experience in your prompt while integrating nicely with the `pi` TUI.

---

\[^multi-thread\]: A capable user of [GNU Parallel](https://www.gnu.org/software/parallel/) can make `grep` and `find` operations parallelized, which is useful in scripting. However, for most use cases, having these optimizations compiled in is very beneficial.

\[^posix\]: Similar to `fish`, `nu` is _extremely_ not POSIX compliant, so copy-pasting or running scripts with `nu` as the interpreter are bound to fail often. Never set a non-POSIX shell as your system's default shell. I set `nu` as the default program that launches when I start my TTY.
