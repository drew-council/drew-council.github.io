+++
date = "2025-07-24T00:49:45"
draft = false
title = "creating this website"

+++

I wanted to document the creation of this website. It's nicely meta, and I had some interesting challeneges come up in setting it up and syling it just how I preferred.

## github pages

When starting this project, I was already pretty sure I would be using [GitHub Pages](https://pages.github.com/) to handle hosting the static site. It's free, and I'm already familiar with the GitHub Actions tooling, for better or (often) worse.[^gha]

It's free and everyone uses it, so the documentation for DNS setup, deployment, and integration with all the site generators is excellent. _What's not to love?_ ☺️

## hugo

To handle my static site generation, I chose [**Hugo**](https://github.com/gohugoio/hugo).

[![hugo](images/hugo-logo-wide.svg#small)](https://github.com/gohugoio/hugo)

### why not xyz other framework?

> I'm scared of javascript.

In all seriousness, I chose Hugo because I am very comfortable with Go and its tooling. This means that if I need to patch in a feature, I won't be stabbing in the dark.

[![foreshadowing](images/foreshadowing.webp#medium)](https://www.youtube.com/watch?v=0twDETh6QaI)

Additionally, it is [available in nixpkgs](https://search.nixos.org/packages?channel=unstable&show=hugo), which means someone else has done the work of making it build nicely in the nix ecosystem for me.

Ultimately, I'm pretty happy with this choice. The website builds super quickly (the `hugo server` command works excellently), and even if I need to recompile Hugo from source, it only takes a couple of minutes at most on my old laptop.

### theme

I ended up settling on [typo](https://tomfran.github.io/typo-wiki/features/homepage/), which I find to be pretty stylish. I really like the structure of the default layout.

The only change I made from the default behavior is changing the monospace/code font to [`JetBrains Mono`](https://www.jetbrains.com/lp/mono/). It was my favorite part of JetBrains when I used it in school, and I use it practically everywhere. I also added a slightly tweaked version of the included [catppuccin theme](https://catppuccin.com/)

---

**Great!** I have my website set up and deploying nicely using the [Hugo docs for working with GitHub Pages](https://gohugo.io/host-and-deploy/host-on-github-pages/). It _should_ be smooth sailing from here...

# one tiny issue

Syntax highlighting isn't working for [`nu` files](https://www.nushell.sh/)...

```
ls ~/Documents
```

<figcaption>dang it.</figcaption>

Well, let me see if I can figure out why that is.

## down the rabbit hole

![rabbithole](images/looney-tunes-swim-in-rabbit-hole.gif#small "Away we go!")

Turns out, Hugo uses [chroma](https://github.com/alecthomas/chroma) to do syntax highlighting. Any language with a chroma _lexer_ is automatically supported in Hugo, but chroma does not have any Nu/Nushell support to speak of.

That's fine, chroma is effectively a port of the patterns from the Python package [pygments](https://pygments.org/) and includes some helpful scripting to convert a pygments lexer to a chroma lexer. Pygments has no official nushell lexer, but there is the [pygments-nushell](https://pypi.org/project/pygments-nushell) package for just that purpose.

So, I apply the script to the package and get a chroma `nu.xml` file defining the lexer patterns. Then, I manually patch it a bit to fix issues with syntax highlighting for `$var` patterns and [upstream the final product](https://github.com/alecthomas/chroma/pull/1110).

## compiling the fix into hugo

To add this syntax highlighting to Hugo, I needed to [fork Hugo](https://github.com/drew-council/hugo) and use `go get -u github.com/alecthomas/chroma/v2@master` to pull in the latest chroma changes.

Then, I want to build this fork of Hugo for my project. I'm using **Nix Flakes** to define my development environment in a [`flake.nix` file](https://github.com/drew-council/drew-council.github.io/blob/main/flake.nix), and this allows me to define a new source for `pkgs.hugo`:

```nix
myHugo = pkgs.hugo.overrideAttrs (old: {
  version = "0.149.0";
  src = pkgs.fetchFromGitHub {
    owner = "drew-council";
    repo = "hugo";
    rev = "<revision>";
    hash = "<hash>";
  };
  vendorHash = "<vendor hash>";
  doCheck = false; # speeds up build times, fine for personal use
});
```

<figcaption>Defining a new package with overrides over pkgs.hugo.</figcaption>

Hugo then takes a couple minutes to build the first time and works flawlessly from then on.

This also provides the benefit that my local development and GitHub Workflow versions of Hugo are always guaranteed to be the same. With the default Hugo setup, you are expected to make sure of that on your own.

As of now, this will need to _slowly_ build in the free-tier GitHub runner every time I deploy. The action from the Hugo docs does handle binary caching, but the source is just the Hugo-provided binaries. I really don't want to manually cache all my dependencies...

### cachix to the rescue

[Cachix](https://www.cachix.org/) provides a Nix binary cache designed to solve this problem.[^cachix]

Setting up nix with store caching in a GitHub Workflow is fairly simple:

```yaml
- uses: cachix/install-nix-action@v31
- uses: cachix/cachix-action@v16
  with:
    name: hugo-site
    authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
---
- name: Build with Hugo
  run: |
    nix develop --command hugo \
      --gc \
      --minify \
      --baseURL "${{ steps.pages.outputs.base_url }}/" \
          --cacheDir "${{ runner.temp }}/hugo_cache"
```

Now, the deploy action runs in **less than 30 seconds!**

[![greenpipeline](images/your_pipeline_is_green.webp#medium)](https://www.youtube.com/watch?v=ia8Q51ouA_s)

## problem solved

Now the site has highlighting support for Nushell!

```nu
let lfs_data = (
  git lfs ls-files --size |
    detect columns -n |
    reject column1 |
    rename hash file size |
    update size {|row| $row.size | str substring 1..-2 | into filesize} |
    sort-by size
)

print $lfs_data

let total_size = ($lfs_data | get size | math sum)
print $"Total size: ($total_size)"
```

<figcaption>Example nu script that extracts git-lfs file data. Highlighting isn't perfect, but it's there!</figcaption>

> Was this practical?

No.

> Was this worth the time I spent on it?

**Absolutely not.**[^nu] It was fun though, and I'm very pleased with the final product.

[^gha]: This is likely an incoming blog, as GitHub actions can be very messy at times. See [fasterthanlime's excellent overview of the mess we are in](https://www.youtube.com/watch?v=9qljpi5jiMQ).

[^cachix]: In all honesty, this addition was mostly an excuse for me to try out Cachix in a real use case. Overall, I have found it very pleasant to use.

[^nu]: I do plan on blogging about nushell in the future, so I guess it isn't fully useless.
