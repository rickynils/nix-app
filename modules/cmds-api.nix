{ config, lib, ... }:

with lib;

let

  failedAssertions = map (x: "- ${x.message}") (
    filter (x: !x.assertion) config.assertions
  );

in {
  options = {
    commands = mkOption {
      type = with types; attrsOf (listOf (listOf path));
      default = {};
    };

    assertions = mkOption {
      default = [];
      type = with types; listOf (submodule ({...}: {
        options = {
          assertion = mkOption { type = types.bool; };
          message = mkOption { type = types.str; };
        };
      }));
    };
  };

  config = {
    nix-app.main = mkIf (failedAssertions != []) (
      throw "Failed assertions:\n${concatStringsSep "\n" failedAssertions}"
    );

    assertions = [
      { assertion = config.nix-app.args != [];
        message = "No command specified"; }
      { assertion = hasAttr (head config.nix-app.args) config.commands;
        message = "Unknown command specified"; }
    ];
  };
}
