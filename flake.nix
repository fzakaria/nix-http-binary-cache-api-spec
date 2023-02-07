{
  description = "An OpenAPI specification for a Nix HTTP Binary Cache";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/22.11";
  inputs.dsf.url     = "github:cruel-intentions/devshell-files";
  inputs.dsf.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs: inputs.dsf.lib.shell inputs [ ./project.nix ];
}
