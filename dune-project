(lang dune 3.0)
(name joy_blog)
(version 3ff454a-dirty)
(generate_opam_files true)

(package
 (name joy_blog)
 (synopsis "Joy's Beautiful Apple-themed Blog")
 (description "A static blog generated with YOCaml")
 (maintainers "Joy Aruku <joy.gold13@gmail.com>")
 (authors "Joy Aruku")
 (homepage "https://github.com/Dev-JoyA/yocaml_blog")
 (bug_reports "https://github.com/Dev-JoyA/yocaml_blog/issues")
 (license "MIT")
 (documentation "https://dev-joya.github.io/yocaml_blog")
 (source (github Dev-JoyA/yocaml_blog))
 (depends
  (ocaml (>= 5.3.0))
  (yocaml (>= 2.5.0))
  (yocaml_unix (>= 2.5.0))
  cmarkit 
  hilite
  textmate-language
  (yocaml_markdown (= 2.5.0))
  (yocaml_yaml (>= 2.5.0))
  (yocaml_jingoo (>= 2.5.0))
  (yocaml_syndication (>= 2.0.0))))