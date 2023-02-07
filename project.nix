{ 
  files.yaml."/api.yaml" = import ./api.nix;
  # if you don't have direnv run: `nix develop --build`
  files.direnv.enable    = true;
  # create .gitignore
  files.gitignore.enable = true;
  files.gitignore.pattern.".direnv"          = true;
  files.gitignore.template."Global/Archives" = true;
  files.gitignore.template."Global/Backup"   = true;
  files.gitignore.template."Global/Diff"     = true;
  # copy contents from https://github.com/github/gitignore
  # to our .gitignore
}
