# 🍳 cookin 👩‍🍳
{
  description = "flake for HT_CAN sym file for dbc output creation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    nix-proto.url = "github:notalltim/nix-proto";
  };

  outputs = { self, nixpkgs, utils, nix-proto }@inputs:
    let
      makePackageSet = pkgs: {
        default = pkgs.ht_can_pkg;
        ht-proto-gen = pkgs.ht-proto-gen;
        py_dbc_proto_gen_pkg = pkgs.py_dbc_proto_gen_pkg;
        hytech_np_proto_cpp = pkgs.hytech_np_proto_cpp;
      };
      ht_can_dbc_overlay = final: prev: {
        ht_can_pkg = final.callPackage ./default.nix { }; # has the dbc file in it
      };
      dbc_to_proto_overlay = final: prev: {
        py_dbc_proto_gen_pkg = final.callPackage ./dbc_to_proto.nix { };
      };
      proto_file_gen_overlay = final: prev: {
        ht-proto-gen = final.callPackage ./proto_gen.nix { };
      };
      nix_protos_overlays = nix-proto.generateOverlays'
        {
          hytech_np = { ht-proto-gen }:
            nix-proto.mkProtoDerivation {
              name = "hytech_np";
              buildInputs = [ ht-proto-gen ];
              src = ht-proto-gen.out + "/proto";
              version = self.rev;
            };
        };
      my_overlays = [ ht_can_dbc_overlay dbc_to_proto_overlay proto_file_gen_overlay ] ++ nix-proto.lib.overlayToList nix_protos_overlays;
      pkgs = import nixpkgs {
        overlays = my_overlays;
        inherit system;
        config = {
          allowUnsupportedSystem = true;
        };
      };  

      system = builtins.currentSystem;
      x86_pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlays.default ];
      };

      arm_pkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [ self.overlays.default ];
      };

      arch64-darwin_pkgs = import nixpkgs {
        system = "aarch64-darwin";
        overlays = [ self.overlays.default ];
      };

      x86-darwin_pkgs = import nixpkgs {
        system = "x86_64-darwin";
        overlays = [ self.overlays.default ];
      };

      packageSets = {
        "x86_64-linux" = makePackageSet x86_pkgs;
        "aarch64-linux" = makePackageSet arm_pkgs;
        "x86_64-darwin" = makePackageSet x86-darwin_pkgs;
        "aarch64-darwin" = makePackageSet arch64-darwin_pkgs;
        # Add more systems as needed
      };
    in {

      overlays.default = nixpkgs.lib.composeManyExtensions my_overlays;

      packages = packageSets;
      devShells.x86_64-linux.default = x86_pkgs.mkShell rec {
        # Update the name to something that suites your project.
        name = "nix-devshell";
        packages = with x86_pkgs; [
          # Development Tools
          python311Packages.cantools
          # ht_can_pkg 
        ];
      };

      devShells.aarch64-linux.default = arm_pkgs.mkShell rec {
        # Update the name to something that suites your project.
        name = "nix-devshell";
        packages = with arm_pkgs; [
          # Development Tools
          python311Packages.cantools
          # ht_can_pkg 
        ];

      };

      devShells.aarch64-darwin.default = arch64-darwin_pkgs.mkShell rec {
        # Update the name to something that suites your project.
        name = "nix-devshell";
        packages = with arch64-darwin_pkgs; [
          # Development Tools
          #https://discourse.nixos.org/t/overriding-docheck-doesnt-work-with-python-package/14674
          (python311Packages.cantools.overridePythonAttrs (_: { doCheck = false; }))
          # ht_can_pkg 
        ];

      };

      devShells.x86_64-darwin.default = x86-darwin_pkgs.mkShell rec {
        # Update the name to something that suites your project.
        name = "nix-devshell";
        packages = with x86-darwin_pkgs; [
          # Development Tools
          (python311Packages.cantools.overridePythonAttrs (_: { doCheck = false; }))
          # ht_can_pkg 
        ];

      };

    };
}