(lang dune 3.0)
(name joy_blog)
(version 0.1.0)
(generate_opam_files true)

(package
 (name joy_blog)
 (synopsis "Joy's Beautiful Apple-themed Blog")
 (description "A static blog generated with YOCaml")
 (depends
  (ocaml (>= 5.3.0))
  (yocaml (>= 2.5.0))
  (yocaml_unix (>= 2.5.0))
  cmarkit 
  hilite
  (yocaml_markdown (= 2.5.0))
  (yocaml_yaml (>= 2.5.0))
  (yocaml_jingoo (>= 2.5.0))
  (yocaml_syndication (>= 2.0.0))))