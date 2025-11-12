open Yocaml

(* Helper functions *)
let with_ext exts file =
  List.exists (fun ext -> Path.has_extension ext file) exts

let is_markdown = with_ext [ "md"; "markdown"; "mdown" ]

let track_binary =
  Sys.executable_name |> Yocaml.Path.from_string |> Pipeline.track_file

(* DEBUG: Add debug logging *)
let debug_log msg =
  let open Task in
  let+ () = track_binary in
  Printf.eprintf "DEBUG: %s\n%!" msg

let copy_images resolver =
  let images_path = Resolver.Target.images resolver
  and where = with_ext [ "svg"; "png"; "jpg"; "gif" ] in
  Batch.iter_files ~where
    (Resolver.Source.images resolver)
    (Action.copy_file ~into:images_path)

let create_css resolver =
  let css_path = Resolver.Target.style_css resolver in
  let css = Resolver.Source.css resolver in
  Action.Static.write_file css_path
    Task.(
      track_binary
      >>> Pipeline.pipe_files ~separator:"\n"
            Path.[ css / "reset.css"; css / "style.css" ])

let create_page resolver source =
  let page_path = Resolver.Target.page resolver ~source in
  let templates = Resolver.Source.templates resolver in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ () = debug_log ("Creating page: " ^ Path.to_string source)
    and+ apply_templates =
      Yocaml_jingoo.read_templates
        Path.[ templates / "page.html"; templates / "layout.html" ]
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata
        (module Archetype.Page)
        source
    in
    content
    |> Yocaml_markdown.from_string_to_html
    |> apply_templates (module Archetype.Page) ~metadata
  in
  Action.Static.write_file page_path pipeline

let create_pages resolver =
  let where = is_markdown in
  Batch.iter_files ~where
    (Resolver.Source.pages resolver)
    (create_page resolver)

let create_article resolver source =
  let article_path = Resolver.Target.article resolver ~source in
  let templates = Resolver.Source.templates resolver in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ () =
      debug_log
        ("Creating article: "
        ^ Path.to_string source
        ^ " -> "
        ^ Path.to_string article_path)
    and+ templates =
      Yocaml_jingoo.read_templates
        Path.[ templates / "article.html"; templates / "layout.html" ]
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata
        (module Archetype.Article)
        source
    in
    content
    |> Yocaml_markdown.from_string_to_html
    |> templates (module Archetype.Article) ~metadata
  in
  Action.Static.write_file article_path pipeline

let create_articles resolver =
  let where = is_markdown in
  Batch.iter_files ~where
    (Resolver.Source.articles resolver)
    (create_article resolver)

(* 
   The key fix: compute_link now uses Path.move instead of basename
   This follows the YOCaml documentation approach
*)
<<<<<<< HEAD
let compute_link resolver source =
  source
  |> Resolver.Target.article resolver ~source
  |> Resolver.Server.from_target resolver
=======
let compute_link resolver source = Resolver.Server.article_link resolver ~source
>>>>>>> b2fc66b (fixed path issues)

let fetch_articles resolver =
  Archetype.Articles.fetch ~where:is_markdown
    ~compute_link:(compute_link resolver)
    (module Yocaml_yaml)
    (Resolver.Source.articles resolver)

let create_index resolver =
  let source = Resolver.Source.index resolver in
  let index_path = Resolver.Target.index resolver in
  let templates = Resolver.Source.templates resolver in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ () = debug_log "Creating index page"
    and+ templates =
      Yocaml_jingoo.read_templates
        Path.
          [
            templates / "index.html"
          ; templates / "page.html"
          ; templates / "layout.html"
          ]
    and+ articles = fetch_articles resolver
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata
        (module Archetype.Page)
        source
    in
    let metadata = Archetype.Articles.with_page ~page:metadata ~articles in
    content
    |> Yocaml_markdown.from_string_to_html
    |> templates (module Archetype.Articles) ~metadata
  in
  Action.Static.write_file index_path pipeline

module Feed = struct
  let title = "Joy's Beautiful Apple-themed Blog"
  let site_url = "https://Dev-JoyA.github.io/yocaml_blog"
  let feed_description = "My personal blog using YOCaml"

  let owner =
    Yocaml_syndication.Person.make ~uri:site_url ~email:"joy.gold13@gmail.com"
      "Joy Aruku"

  let authors = Nel.singleton owner

  let article_to_entry (url, article) =
    let open Yocaml.Archetype in
    let open Yocaml_syndication in
    let page = Article.page article in
    let title = Article.title article
    and content_url = site_url ^ Path.to_string url
    and updated = Datetime.make (Article.date article)
    and categories = List.map Category.make (Page.tags page)
    and summary = Option.map Atom.text (Page.description page) in
    let links = [ Atom.alternate content_url ~title ] in
    Atom.entry ~links ~categories ?summary ~updated ~id:content_url
      ~title:(Atom.text title) ()

  let make entries =
    let open Yocaml_syndication in
    Atom.feed ~title:(Atom.text title)
      ~subtitle:(Atom.text feed_description)
      ~updated:(Atom.updated_from_entries ())
      ~authors ~id:site_url article_to_entry entries
end

let create_feed resolver =
  let feed_path = Resolver.Target.atom resolver
  and pipeline =
    let open Task in
    let+ () = track_binary
    and+ () = debug_log "Creating feed"
    and+ articles = fetch_articles resolver in
    articles |> Feed.make |> Yocaml_syndication.Xml.to_string
  in
  Action.Static.write_file feed_path pipeline

let program resolver () =
  let open Eff in
  let cache = Resolver.Target.cache resolver in
  Action.restore_cache cache
  >>= copy_images resolver
  >>= create_css resolver
  >>= create_pages resolver
  >>= create_articles resolver
  >>= create_index resolver
  >>= create_feed resolver
  >>= Action.store_cache cache

let () =
  let resolver = Resolver.make () in
  Printf.eprintf "=== Yocaml Blog Build ===\n";
  Printf.eprintf "WWW path: %s\n"
    (Path.to_string (Resolver.Target.target resolver));
  Printf.eprintf "Content path: %s\n"
    (Path.to_string (Resolver.Source.content resolver));
  Printf.eprintf "Articles path: %s\n"
    (Path.to_string (Resolver.Source.articles resolver));
  Printf.eprintf "Templates path: %s\n"
    (Path.to_string (Resolver.Source.templates resolver));
  Printf.eprintf
    "Expected article URLs: http://localhost:8000/articles/article-name.html\n\n";

  match Sys.argv.(1) with
  | "server" ->
      Printf.eprintf "Starting server at http://localhost:8000/\n";
      Yocaml_unix.serve ~level:`Info
        ~target:(Resolver.Target.target resolver)
        ~port:8000 (program resolver)
  | _
  | (exception _) ->
      Yocaml_unix.run ~level:`Debug (program resolver)
