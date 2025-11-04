open Yocaml

let base_url = "/yocaml_blog"
let www = Path.rel [ "_www" ]
let assets = Path.rel [ "assets" ]
let content = Path.rel [ "content" ]
let images = Path.(assets / "images")
let css = Path.(assets / "css")
let pages = Path.(content / "pages")
let articles = Path.(content / "articles")
let templates = Path.(assets / "templates")

let with_ext exts file =
  List.exists (fun ext -> Path.has_extension ext file) exts

let is_markdown = with_ext [ "md"; "markdown"; "mdown" ]

let track_binary = 
  Sys.executable_name
  |> Yocaml.Path.from_string
  |> Pipeline.track_file

let copy_images =
  let images_path = Path.(www / "images")
  and where = with_ext [ "svg"; "png"; "jpg"; "gif" ] in
  Batch.iter_files 
    ~where images 
    (Action.copy_file ~into:images_path)

let create_css =
  let css_path = Path.(www / "style.css") in
  Action.Static.write_file css_path
    Task.(
      track_binary
      >>> Pipeline.pipe_files ~separator:"\n"
            Path.[ 
              css / "reset.css"
            ; css / "style.css" ])

let create_page source =
  let page_path =
    source 
    |> Path.move ~into:www 
    |> Path.change_extension "html"
  in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ apply_templates = 
      Yocaml_jingoo.read_templates 
        Path.[ templates / "page.html"
             ; templates / "layout.html" ]
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

let create_pages =
  let where = is_markdown in
  Batch.iter_files ~where pages create_page

let create_article source =
  let article_path =
    source
    |> Path.(move ~into:(www / "articles"))
    |> Path.change_extension "html"
  in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ templates =
      Yocaml_jingoo.read_templates
        Path.[ templates / "article.html"
             ; templates / "layout.html" ]
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

let create_articles =
  let where = is_markdown in
  Batch.iter_files ~where articles create_article

let compute_link source =
  let into = Path.abs [ "articles" ] in
  let path =
    source
    |> Path.move ~into
    |> Path.change_extension "html"
  in
  Path.(rel [base_url] / Path.to_string path)

let fetch_articles = 
  Archetype.Articles.fetch 
    ~where:is_markdown 
    ~compute_link
    (module Yocaml_yaml)
    articles

let create_index =
  let source = Path.(content / "index.md") in
  let index_path =
    source 
    |> Path.move ~into:www 
    |> Path.change_extension "html"
  in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ templates =
      Yocaml_jingoo.read_templates
        Path.
          [ templates / "index.html"
          ; templates / "page.html"
          ; templates / "layout.html"
          ]
    and+ articles = fetch_articles
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata
        (module Archetype.Page)
        source
    in
    let metadata = 
        Archetype.Articles.with_page
           ~page:metadata 
           ~articles
    in
    content 
    |> Yocaml_markdown.from_string_to_html
    |> templates (module Archetype.Articles) ~metadata
  in
  Action.Static.write_file index_path pipeline

module Feed = struct
  let path = "atom.xml"
  let title = "Joy's Beautiful Apple-themed Blog"
  let site_url = "https://Dev-JoyA.github.io/yocaml_blog"
  let feed_description = "My personal blog using YOCaml"
  
  let owner = 
    Yocaml_syndication.Person.make 
      ~uri:site_url 
      ~email:"joy.gold13@@gmail.com" 
      "Joy Aruku"
      
  let authors = Nel.singleton owner

  let article_to_entry (url, article) =
    let open Yocaml.Archetype in
    let open Yocaml_syndication in
    let page = Article.page article in
    let title = Article.title article
    and content_url = 
      site_url ^ Path.to_string url
      
    and updated = 
      Datetime.make (Article.date article)
      
    and categories = 
      List.map Category.make (Page.tags page)
      
    and summary = 
      Option.map Atom.text (Page.description page) 
    in
    
    let links =
      [ Atom.alternate content_url ~title ] 
    in
    Atom.entry 
      ~links 
      ~categories 
      ?summary 
      ~updated 
      ~id:content_url 
      ~title:(Atom.text title) ()

  let make entries =
    let open Yocaml_syndication in
    Atom.feed 
      ~title:(Atom.text title)
      ~subtitle:(Atom.text feed_description)
      ~updated:(Atom.updated_from_entries ())
      ~authors 
      ~id:site_url 
      article_to_entry 
      entries
end

let create_feed =
  let feed_path = Path.(www / Feed.path)
  and pipeline =
    let open Task in
    let+ () = track_binary
    and+ articles = fetch_articles in
    articles 
    |> Feed.make 
    |> Yocaml_syndication.Xml.to_string
  in
  Action.Static.write_file feed_path pipeline

let program () =
  let open Eff in
  let cache = Path.(www / ".cache") in
  Action.restore_cache cache 
  >>= copy_images
  >>= create_css
  >>= create_pages
  >>= create_articles
  >>= create_index
  >>= create_feed
  >>= Action.store_cache cache

let () =
  match Sys.argv.(1) with
  | "server" -> 
    Yocaml_unix.serve 
       ~level:`Info 
       ~target:www 
       ~port:8000 
       program
  | _ | (exception _) -> 
     Yocaml_unix.run 
       ~level:`Debug 
       program