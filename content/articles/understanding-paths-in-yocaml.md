---
title: Understanding Paths in Yocaml - From Broken Links to Working Blog
description: My journey fixing article links in Yocaml and learning the resolver pattern the right way
date: 2025-11-05
tags: [yocaml, static-sites, github-pages, paths, deployment]
---

# Understanding Paths in Yocaml: My Journey from Broken Links to a Working Blog

## The Problem That Cost Me Days

When I first deployed my Yocaml blog to GitHub Pages, I was so excited. Everything worked perfectly locally—the articles loaded, the navigation was smooth, CSS looked great. Then I pushed to production and... 404 errors everywhere. My article links were completely broken.

What made it worse? My mentor kept pointing me to the documentation about `Path.move` and `Path.relocate` and something called a "resolver pattern," but I didn't understand why I needed all that. I just wanted my links to work! 

Here's what I learned after finally getting it right.

## The Wrong Way I Did It First

My initial approach was to use `Path.basename` to extract the filename and manually construct article links:

```ocaml
let compute_link source =
  let article_filename = 
    source
    |> Path.basename
    |> Option.map (fun name -> Filename.chop_extension name ^ ".html")
    |> Option.value ~default:"article.html"
  in
  Path.(rel ["articles"; article_filename])
```

This seemed logical! Take the source file path, get just the filename, slap `.html` on it, and boom—article link. And you know what? It *did* work locally.

**The problem:** When I deployed to GitHub Pages at `https://Dev-JoyA.github.io/yocaml_blog`, my articles were being linked as `/articles/my-first-article.html` when they should have been `/yocaml_blog/articles/my-first-article.html`.

More importantly, my mentor pointed out something crucial: "Using `Path.move` and `Path.relocate`, you probably never need to use `basename` that leads to an option."

I was like... what? Why?

## Understanding The Three Path Contexts

After reading the docs about five times (okay, maybe ten), I finally got it. When you're building a static site, you're actually dealing with THREE different path contexts:

### 1. Source Paths
Where your content lives *before* building:
```
./content/articles/my-first-article.md
```

### 2. Target Paths  
Where files are written *after* building:
```
./_www/articles/my-first-article.html
```

### 3. Server Paths
What URLs look like when someone visits your site:
```
/yocaml_blog/articles/my-first-article.html  (on GitHub Pages)
/articles/my-first-article.html              (locally)
```

The key insight? These are all *transformations* of the same logical path. You shouldn't be manually extracting filenames—you should be using `Path.move` to transform one path context into another.

## The Resolver Pattern (Why My Mentor Was Right)

Instead of scattering path calculations all over my code, the Yocaml way is to centralize everything in a resolver module. Here's what I ended up creating:

### Creating `bin/resolver.ml`

```ocaml
open Yocaml

type t = 
  { source: Path.t
  ; target: Path.t
  ; server_root: Path.t
  }

let make 
  ?(source_folder = Path.rel [])
  ?(target_folder = Path.rel ["_www"])
  ?(server_root = Path.abs []) 
  () 
  = 
  { source = source_folder
  ; target = target_folder
  ; server_root
  }

module Source = struct 
  let source { source; _ } = source
  let assets r = Path.(source r / "assets")
  let content r = Path.(source r / "content")
  let articles r = Path.(content r / "articles")
  (* ... other source paths ... *)
end

module Target = struct 
  let target { target; _ } = target
  
  let article r ~source =
    let into = Path.(target r / "articles") in
    source 
    |> Path.move ~into
    |> Path.change_extension "html"
    
  (* ... other target paths ... *)
end

module Server = struct 
  let server { server_root; _ } = server_root
  
  let article_link r ~source =
    let into = Path.(server r / "articles") in
    source
    |> Path.move ~into
    |> Path.change_extension "html"
end
```

See what's happening? No `basename`, no `Option.map`, no manual string manipulation. Just clean path transformations using `Path.move`.

## The Fix That Actually Worked

Here's how I updated my main blog code:

```ocaml
(* Old way - using basename *)
let compute_link source =
  let article_filename = 
    source |> Path.basename |> Option.map ...
  in
  Path.(rel ["articles"; article_filename])

(* New way - using resolver *)
let compute_link resolver source =
  Resolver.Server.article_link resolver ~source
```

That's it. Seriously. All that complexity collapsed into one line.

And here's the magic part—when I create my resolver, I can tell it about GitHub Pages:

```ocaml
let () =
  (* For GitHub Pages deployment *)
  let resolver = Resolver.make ~server_root:(Path.abs ["yocaml_blog"]) () in
  
  match Sys.argv.(1) with
  | "server" -> 
    Yocaml_unix.serve 
       ~target:(Resolver.Target.target resolver)
       ~port:8000 
       (program resolver)
  | _ -> 
     Yocaml_unix.run (program resolver)
```

Now my article links are automatically generated as `/yocaml_blog/articles/my-first-article.html`—exactly what GitHub Pages expects!

## Why This Approach Is Better

### 1. No More Options to Handle
With `basename`, I had to deal with `Option.map` and `Option.value ~default` because a path *might* not have a basename. With `Path.move`, the transformation is guaranteed to work.

### 2. Works Everywhere
The same code works locally and in production. I just change one parameter (`server_root`) and everything adjusts.

### 3. Centralized Path Logic
All my path calculations live in one file. Need to change how articles are organized? Update the resolver, done.

### 4. Following Best Practices
This is how the official Yocaml website does it. There's a reason—it scales.

## The GitHub Pages "Gotcha"

Here's something that confused me: GitHub Pages serves your repository at `https://username.github.io/repository-name/`, not at the root. 

This means:
- **Files are built to:** `./_www/articles/my-first-article.html`
- **But accessed at:** `https://Dev-JoyA.github.io/yocaml_blog/articles/my-first-article.html`

The resolver pattern handles this perfectly. Your target paths (where files are physically written) stay clean, while your server paths (what appears in HTML links) get the `/yocaml_blog` prefix.

## My Updated GitHub Actions Workflow

No changes needed! The workflow stays the same:

```yaml
- name: Build site
  run: |
    dune exec joy_blog
    
- name: Upload artifact
  uses: actions/upload-pages-artifact@v3
  with:
    path: "./_www"
```

The files are built to `_www/`, then uploaded. GitHub Pages serves them at `/yocaml_blog/`, and because I set `server_root` correctly, all my links just work.

## Testing Locally

One thing that tripped me up: when you set `server_root` to `/yocaml_blog`, your local development server expects URLs like:
```
http://localhost:8000/yocaml_blog/articles/my-first-article.html
```

Not ideal for local development, right? You could make it configurable:

```ocaml
let server_root = 
  match Sys.getenv_opt "GITHUB_PAGES" with
  | Some "true" -> Path.abs ["yocaml_blog"]
  | _ -> Path.abs []
```

But honestly? I just kept it set to `/yocaml_blog` everywhere. It's a minor inconvenience locally, but it means my local testing is closer to production.

## Key Takeaways

**What I learned:**
1. Don't fight the framework—learn its patterns
2. `Path.move` and `Path.relocate` are your friends
3. The resolver pattern isn't over-engineering, it's good design
4. Testing locally isn't enough; you need to understand your deployment environment

**What my mentor was trying to tell me:**
When you use `Path.move`, you're expressing a *transformation* between path contexts. The framework understands this and can reason about it. When you use `basename` and string manipulation, you're just hacking strings together—you lose all that semantic information.

## The Before and After

**Before (fighting Yocaml):**
```ocaml
let compute_link source =
  let article_filename = 
    source
    |> Path.basename
    |> Option.map (fun name -> Filename.chop_extension name ^ ".html")
    |> Option.value ~default:"article.html"
  in
  Path.(rel ["articles"; article_filename])
```

**After (working with Yocaml):**
```ocaml
let compute_link resolver source =
  Resolver.Server.article_link resolver ~source
```

One is full of edge cases and manual string operations. The other is declarative and clear about intent.

## Final Thoughts

If you're reading this because your Yocaml blog's article links are broken on GitHub Pages, I feel you. It's frustrating when things work locally but fail in production.

But here's the thing: the documentation really does have the answer. The resolver pattern isn't just some academic exercise—it's the battle-tested solution to exactly this problem. Take the time to understand it, set up your resolver properly, and you'll save yourself hours of debugging.

And if your mentor tells you to stop using `basename`? Listen to them. They're probably right.

Now if you'll excuse me, I have a blog to deploy. And this time, the links actually work! 🎉

---

*P.S. Big thanks to @xvw for patiently explaining this to me about five times until it finally clicked. The documentation is great, but sometimes you just need someone to tell you "no really, read section 2.3 again."*