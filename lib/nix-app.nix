{ lib, args }:

let
  inherit (builtins) fromJSON elemAt readFile attrNames filter sort
    listToAttrs toFile tail isString toPath substring stringLength;

  paths = (
    let f = elemAt args 1;
    in if f == "" then {}
       else if stringLength f < 6 || (substring (stringLength f - 5) 5 f) != ".json" then import f
       else fromJSON (readFile f)
  ) // {
    nix-app = toString ./..;
  };

  module = elemAt args 2;

  app-args = tail (tail (tail args));

  io-defnix = lib.join (lib.map (src:
    import src lib {}
  ) (lib.builtins.fetchgit {
    url = "https://github.com/shlevy/defnix.git";
    rev = "f1bafa44406b7c5303d44c08e862e5bdefefe2d9";
  }));

  io-spawn = file: argv: lib.join (lib.map (defnix:
    defnix.nix-exec.spawn file argv
  ) io-defnix);

  io-fetch = lib.builtins.fetchgit;

  io-paths = lib.join (lib.map (defnix:
    defnix.lib.nix-exec.sequence (
      map (n:
        lib.map (p: { prefix = n; path = p; }) (
          let t = paths.${n}; in if isString t then lib.unit t else io-fetch t
        )
      ) (attrNames paths)
    )
  ) io-defnix);

  io-config = lib.map (paths:
    let
      overrides = {
        __nixPath = sort (p1: p2: p1.prefix > p2.prefix) (paths ++ __nixPath);
        import = fn: scopedImport overrides fn;
        scopedImport = attrs: fn: scopedImport (overrides // attrs) fn;
        builtins = builtins // overrides;
      };
    in let
      inherit (overrides) __nixPath;
      pkgs = scopedImport overrides <nixpkgs> {};
    in (pkgs.lib.evalModules {
      modules = [
        (scopedImport overrides module)
        ({lib, ...}: {
          options = {
            nix-app.args = lib.mkOption {
              type = with lib.types; listOf str;
            };
            nix-app.main = lib.mkOption {
              type = lib.types.path;
              default = throw "nix-app entrypoint missing";
            };
          };
          config = {
            _module.args = { inherit pkgs; };
            nix-app.args = app-args;
          };
        })
      ];
    }).config
  ) io-paths;

in lib.join (lib.map (config: io-spawn config.nix-app.main []) io-config)
