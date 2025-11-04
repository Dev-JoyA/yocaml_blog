# Joy's Beautiful Apple-themed Blog

A stunning, modern static blog built with [YOCaml](https://github.com/xhtmlboi/yocaml) - featuring Apple-inspired design with smooth animations, Lottie graphics, and an exceptional user experience.

🌐 **Live Site**: [https://Dev-JoyA.github.io/yocaml_blog](https://Dev-JoyA.github.io/yocaml_blog)

![Blog Preview](https://img.shields.io/badge/OCaml-5.3.0-orange) ![YOCaml](https://img.shields.io/badge/YOCaml-2.5.0-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

- 🎨 **Apple-inspired Design** - Clean, modern UI with glassmorphism and blur effects
- ✨ **Lottie Animations** - Smooth, engaging animations throughout the site
- 📱 **Fully Responsive** - Beautiful on desktop, tablet, and mobile
- 🚀 **Lightning Fast** - Static site generation for optimal performance
- 📝 **Markdown Support** - Write content in Markdown with YAML frontmatter
- 🏷️ **Tag System** - Organize articles with tags
- 📰 **ATOM Feed** - RSS/ATOM feed for syndication
- 🎯 **SEO Optimized** - Semantic HTML and meta tags
- 🌈 **Smooth Scrolling** - Delightful navigation experience

## 📁Project Structure

```
yocaml_blog/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions deployment
├── _build/                     # Build artifacts (git-ignored)
├── _opam/                      # Local opam switch (git-ignored)
├── _www/                       # Generated site (git-ignored)
│   ├── articles/              # Generated article pages
│   ├── images/                # Copied images
│   ├── style.css              # Concatenated CSS
│   ├── atom.xml               # RSS/ATOM feed
│   ├── index.html             # Homepage
│   ├── about.html             # About page
│   └── contact.html           # Contact page
├── assets/
│   ├── css/
│   │   ├── reset.css          # CSS reset
│   │   └── style.css          # Main stylesheet
│   ├── images/
│   │   └── icons.svg          # SVG icons
│   └── templates/
│       ├── layout.html        # Base layout
│       ├── page.html          # Page template
│       ├── article.html       # Article template
│       └── index.html         # Homepage template
├── bin/
│   ├── dune                   # Executable configuration
│   └── joy_blog.ml            # Main generator
├── content/
│   ├── articles/              # Article markdown files
│   │   └── my-first-article.md
│   ├── pages/                 # Page markdown files
│   │   ├── about.md
│   │   └── contact.md
│   └── index.md               # Homepage content
├── .gitignore                 # Git ignore rules
├── dune-project               # Dune project config
├── joy_blog.opam              # OPAM package (auto-generated)
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

- **OCaml** 5.3.0 or higher
- **opam** 2.0 or higher
- **dune** 3.0 or higher

### Local Development

1. **Clone the repository:**

```bash
git clone https://github.com/Dev-JoyA/yocaml_blog.git
cd yocaml_blog
```

2. **Create local opam switch:**

```bash
opam switch create . 5.3.0
eval $(opam env)
```

3. **Install dependencies:**

```bash
opam install . --deps-only --yes
```

4. **Build the blog:**

```bash
dune build
dune exec joy_blog
```

5. **View locally:**

Since the YOCaml server has some issues, use Python's HTTP server:

```bash
dune exec joy_blog server

cd _www
python3 -m http.server 8000
```

Then visit: `http://localhost:8000`

### Development Workflow

**When you make changes:**

```bash
# 1. Rebuild the site
dune exec joy_blog

# 2. View changes
cd _www && python3 -m http.server 8000
```

**Or use watch mode** (requires `entr` or similar):

```bash
# Install entr (macOS)
brew install entr

# Auto-rebuild on file changes
ls bin/*.ml content/**/*.md assets/**/* | entr -r sh -c 'dune exec joy_blog'
```

## 📝 Creating Content

### Writing Articles

Create `content/articles/my-article.md`:

```markdown
---
title: My Awesome Article
description: A brief description
date: 2025-11-03
tags: [ocaml, functional-programming, yocaml]
---

# My Awesome Article

Your **markdown** content here!
```

**Required fields:**

- `title` - Article title
- `date` - Publication date (YYYY-MM-DD)

**Optional fields:**

- `description` - Brief summary
- `tags` - Array of tags

### Writing Pages

Create `content/pages/my-page.md`:

```markdown
---
page_title: My Page
description: Page description
tags: [info]
---

# Page Content

Your content here!
```

### Updating Homepage

Edit `content/index.md` to customize your homepage.

## 🎨 Customization

### Colors & Design

Edit `assets/css/style.css` - customize CSS variables:

```css
:root {
  --apple-blue: #007aff;
  --apple-purple: #af52de;
  --apple-pink: #ff2d55;
  /* ... modify colors, spacing, etc. */
}
```

### Templates

Templates use [Jingoo](https://github.com/tategakibunko/jingoo) (Jinja2-like):

- `assets/templates/layout.html` - Navigation & footer
- `assets/templates/page.html` - Regular pages
- `assets/templates/article.html` - Blog articles
- `assets/templates/index.html` - Homepage with article list

### Site Information

Update `bin/joy_blog.ml` in the `Feed` module:

```ocaml
module Feed = struct
  let title = "Your Blog Title"
  let site_url = "https://yourdomain.com"
  let feed_description = "Your description"

  let owner =
    Yocaml_syndication.Person.make
      ~uri:site_url
      ~email:"your@email.com"
      "Your Name"
end
```

## 🚀 Deployment

### GitHub Pages (Automatic)

This blog is configured for automatic deployment via GitHub Actions.

**How it works:**

1. Push to `main` branch
2. GitHub Actions builds the site
3. Deploys to GitHub Pages automatically
4. Live at: https://Dev-JoyA.github.io/yocaml_blog

**Workflow file:** `.github/workflows/deploy.yml`

### Custom Domain Setup

**1. Add CNAME file:**

Create `content/CNAME`:

```
yourdomain.com
```

**2. Update `bin/joy_blog.ml`:**

Add CNAME copy function:

```ocaml
let copy_cname =
  let cname_file = Path.(content / "CNAME") in
  Action.copy_file ~into:www cname_file

let program () =
  let open Eff in
  let cache = Path.(www / ".cache") in
  Action.restore_cache cache
  >>= copy_images
  >>= copy_cname
  >>= create_css
  >>= create_pages
  >>= create_articles
  >>= create_index
  >>= create_feed
  >>= Action.store_cache cache
```

Update site URL:

```ocaml
module Feed = struct
  let site_url = "https://yourdomain.com"  (* Your domain *)
  (* ... *)
end
```

**3. Configure DNS** (at your domain registrar):

**For apex domain:**

```
Type: A, Name: @, Value: 185.199.108.153
Type: A, Name: @, Value: 185.199.109.153
Type: A, Name: @, Value: 185.199.110.153
Type: A, Name: @, Value: 185.199.111.153
```

**For www subdomain:**

```
Type: CNAME, Name: www, Value: Dev-JoyA.github.io
```

**4. Configure GitHub Pages:**

1. Go to: Settings → Pages
2. Custom domain: Enter `yourdomain.com`
3. Wait for DNS to propagate (24-48 hours)
4. Enable "Enforce HTTPS"

**5. Push changes:**

```bash
git add .
git commit -m "Add custom domain"
git push origin main
```

### Manual Deployment

**Build and deploy manually:**

```bash
# Build
dune exec joy_blog

# Deploy _www contents to your hosting
rsync -avz _www/ user@yourserver:/var/www/html/
```

## 🛠️ Commands Reference

```bash
# Build project
dune build

# Generate site
dune exec joy_blog

# Clean build artifacts
dune clean

# Update dependencies
opam update && opam upgrade

# Install new dependency
opam install package-name

# View locally with Python
cd _www && python3 -m http.server 8000
```

## 📚 Technology Stack

- **[YOCaml](https://yocaml.github.io/)** - Static site generator
- **[OCaml](https://ocaml.org/)** 5.3.0 - Programming language
- **[Dune](https://dune.build/)** - Build system
- **[Jingoo](https://github.com/tategakibunko/jingoo)** - Template engine
- **[Cmarkit](https://github.com/dbuenzli/cmarkit)** - Markdown parser
- **[Lottie](https://lottiefiles.com/)** - Animations
- **[Inter Font](https://rsms.me/inter/)** - Typography

## 🐛 Troubleshooting

### Server Issues

The YOCaml development server may hang. Use Python instead:

```bash
dune exec joy_blog  # Build site
cd _www && python3 -m http.server 8000  # Serve locally
```

### HTML Escaping in Templates

If you see escaped HTML like `&lt;div&gt;`, add `| safe` filter:

```html
{{ yocaml_body | safe }}
```

### GitHub Pages Not Updating

1. Check Actions tab for build errors
2. Ensure Settings → Pages → Source is "GitHub Actions"
3. Clear browser cache
4. Wait a few minutes for deployment

### Build Errors

```bash
# Clean and rebuild
dune clean
dune build
opam install . --deps-only --yes
dune exec joy_blog
```

## 🤝 Contributing

Contributions welcome! Feel free to:

- Report bugs
- Suggest features
- Submit pull requests

## 📄 License

MIT License - use freely for your own blog!

## 👤 Author

**Joy Aruku**

- GitHub: [@Dev-JoyA](https://github.com/Dev-JoyA)
- Website: [Dev-JoyA.github.io/yocaml_blog](https://Dev-JoyA.github.io/yocaml_blog)

## 🙏 Acknowledgments

- [YOCaml](https://yocaml.github.io/) team for the excellent SSG
- [OCaml](https://ocaml.org/) community
- Apple for design inspiration
- [LottieFiles](https://lottiefiles.com/) for animations

---

Built with ❤️ using OCaml and YOCaml
