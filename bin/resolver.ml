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
  
  (* Assets *)
  let assets r = Path.(source r / "assets")
  let images r = Path.(assets r / "images")
  let css r = Path.(assets r / "css")
  let templates r = Path.(assets r / "templates")
  
  (* Content *)
  let content r = Path.(source r / "content")
  let pages r = Path.(content r / "pages")
  let articles r = Path.(content r / "articles")
  let index r = Path.(content r / "index.md")
end

module Target = struct 
  (* Target is always _www - files are built here *)
  let target { target; _ } = target
    
  let cache r = 
    Path.(target r / ".cache")
    
  let images r = 
    Path.(target r / "images")
    
  let style_css r = 
    Path.(target r / "style.css")
    
  let page r ~source =
    let into = target r in
    source 
    |> Path.move ~into
    |> Path.change_extension "html"
    
  let article r ~source =
    let into = Path.(target r / "articles") in
    source 
    |> Path.move ~into
    |> Path.change_extension "html"
    
  let index r = 
    Path.(target r / "index.html")
    
  let atom r = 
    Path.(target r / "atom.xml")
end

module Server = struct 
  let server { server_root; _ } = server_root
  
  (* Compute server URL for an article *)
  let article_link r ~source =
    let into = Path.(server r / "articles") in
    source
    |> Path.move ~into
    |> Path.change_extension "html"
end