---
title: Understanding Paths in Yocaml - From Broken Links to Working Blog
description: My journey fixing absolute vs relative paths in Yocaml static site generation
date: 2025-11-05
tags: [yocaml, static-sites, github-pages, paths, deployment]
---

<link rel="stylesheet" href="../style.css">

# Understanding Paths in Yocaml: My Journey from Broken Links to a Working Blog

## The Problem That Cost Me Days of Debugging

When I built my first Yocaml blog, everything worked perfectly locally. But when I deployed to GitHub Pages, my article links turned into a mess: `https://dev-joya.github.io/yocaml_blog//yocaml_blog/articles/my-first-article.html`. 

That double `/yocaml_blog` wasn't just a visual bug—it represented a fundamental misunderstanding of how paths work in static site generators. Here's what I learned the hard way.

## Absolute vs Relative Paths: The Core Concept

### What I Got Wrong Initially

**My Broken `compute_link` Function:**
```ocaml
(* WRONG - This caused the double base URL issue *)
let compute_link source =
  let article_filename = 
    source |> Path.basename |> Option.map (fun name -> 
      Filename.chop_extension name ^ ".html"
    ) |> Option.value ~default:"article.html"
  in
  Path.(rel ["/yocaml_blog"; "articles"; article_filename])
```
**The Correct Version:**
```ocaml
(* CORRECT - Let the deployment environment handle the base *)
let compute_link source =
  let article_filename = 
    source |> Path.basename |> Option.map (fun name -> 
      Filename.chop_extension name ^ ".html"
    ) |> Option.value ~default:"article.html"
  in
  Path.(rel ["articles"; article_filename])
```

## The Three Types of Paths You MUST Understand

### 1. Root-Relative Paths (What Finally Worked)
```html
<!-- These start with / and are resolved from domain root -->
<a href="/articles/my-first-article.html">Article</a>
<a href="/index.html">Home</a>
<a href="/yocaml_blog/index.html">Home (with base)</a>
```

**Why They Work Everywhere:**
- **Locally**: `http://localhost:8000/articles/my-first-article.html`
- **GitHub Pages**: `https://username.github.io/yocaml_blog/articles/my-first-article.html`

The browser automatically prepends the current domain, making these paths environment-agnostic.

### 2. Document-Relative Paths (What Broke My Site)
```html
<!-- These are relative to current directory -->
<a href="articles/my-first-article.html">Article</a>
<a href="../index.html">Back to Home</a>
```

**The Problem:** These paths behave differently based on your URL structure. What works locally (`http://localhost:8000/index.html`) breaks on GitHub Pages (`https://username.github.io/yocaml_blog/index.html`) because the base path changes.

### 3. Absolute Paths (The Nuclear Option)
```html
<!-- These include the full URL -->
<a href="https://dev-joya.github.io/yocaml_blog/articles/my-first-article.html">
```

While these always work, they make your site impossible to test locally and break if you change domains.

## The Local vs Production Divide

### Local Development Environment
```
Project Structure:
yocaml_blog/
├── _www/                    # Generated files
│   ├── index.html
│   └── articles/
│       └── my-first-article.html
└── bin/joy_blog.ml         # Your build code

Local Server: http://localhost:8000/
Serves from: _www/ directory
```

### GitHub Pages Environment
```
URL Structure: https://username.github.io/yocaml_blog/
Serves from: Repository root
Actual files: _www/ directory contents
Base path: /yocaml_blog automatically added
```

**The Critical Insight:** GitHub Pages doesn't serve from `_www/` directly—it serves the *contents* of `_www/` at your base URL. This subtle difference is what broke my links.

## My Template Mistakes and Fixes

### The Broken Back Link
```html
<!-- What I had (BROKEN on GitHub Pages) -->
<a href="../index.html" class="back-link">Back to articles</a>
<!-- This tried to go to https://dev-joya.github.io/index.html -->
```

### The Working Solution
```html
<!-- What fixed it (WORKS everywhere) -->
<a href="/yocaml_blog/index.html" class="back-link">Back to articles</a>
<!-- This correctly goes to https://dev-joya.github.io/yocaml_blog/index.html -->
```

## Testing Strategy: Why Python Server Saved Me

### The Yocaml Local Server Quirk
```bash
dune exec joy_blog -- server  # Sometimes has path issues
```

### The Reliable Python Method
```bash
# Build the site
dune exec joy_blog -- --output _www

# Test exactly what will be deployed
cd _www
python3 -m http.server 8000

# Now test: http://localhost:8000/articles/my-first-article.html
```

**Why This Matters:** The Python server serves files exactly as they exist in your `_www` directory, giving you a perfect preview of your production environment.

## Key Lessons for Yocaml Developers

### 1. Never Hardcode Base URLs in Path Generation
```ocaml
(* 🚫 DON'T: Hardcodes deployment environment *)
Path.(rel ["/yocaml_blog"; "articles"; filename])

(* ✅ DO: Let environment handle base path *)
Path.(rel ["articles"; filename])
```

### 2. Use Root-Relative Paths in Templates
```html
<!-- ✅ These work in both environments -->
<link href="/style.css" rel="stylesheet">
<a href="/articles/some-article.html">Read more</a>
```

### 3. Test with Production-like Servers
Don't rely solely on Yocaml's development server. Use a simple HTTP server to preview your built site.

### 4. Understand Your Deployment Environment
GitHub Pages, Netlify, and other platforms have different URL rewriting behaviors. Test early and often.

## The GitHub Actions Configuration That Works

```yaml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Build site
        run: |
          dune exec joy_blog -- --output _www
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: "./_www"  # Deploy CONTENTS of _www, not _www itself
```

**Crucial Note:** We deploy `./_www` (the directory contents), not `./_www/yocaml_blog`. GitHub Pages automatically adds the repository name as the base path.

## Conclusion: Paths Are About Context

The hardest lesson I learned was that paths don't exist in isolation—they're always resolved relative to their context. A path that works in your local file system might break when served through a CDN, and a path that works in development might fail in production.

By understanding the difference between root-relative, document-relative, and absolute paths—and by testing in environments that mirror production—you can avoid the days of frustration I experienced and build Yocaml sites that work flawlessly from localhost to production.

**Remember:** Your static site generator creates the files, but the web server determines how they're accessed. Design for the latter, not the former.
```

