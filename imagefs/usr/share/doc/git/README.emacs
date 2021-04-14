The git-el package previously provided the following modules for Emacs
support:

* git.el:

  Status manager that displayed the state of all the files of the
  project and provided access to the most frequently used Git
  commands. Its interface was modeled after the pcl-cvs mode.

  Modern alternatives include Magit, available from the elpa-magit
  package, and the VC-mode backend for Git that is part of standard
  Emacs distributions.

* git-blame.el:

  A wrapper for "git blame" written before Emacs's own vc-annotate
  mode, which can be invoked using C-x v g, learned to invoke
  "git blame".

* vc-git.el:

  This file used to contain the VC-mode backend for Git, but it is no
  longer distributed with Git. It is now maintained as part of Emacs
  and included in standard Emacs distributions.
