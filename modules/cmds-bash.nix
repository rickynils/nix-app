{ config, pkgs, lib, ... }:

with pkgs;
with lib;
with builtins;

let

  args = config.nix-app.args;

  command = filter (cs: cs != []) config.commands.${head args};

  seq-scripts = flip concatMapStrings command (ss:
    if length ss == 1 then ''
      xargs < $ARGFILE -d '\n' bash -c '${head ss} "$@" < /dev/tty' --
    '' else ''
      echo -e "${concatStringsSep ''\n'' ss}" | \
        parallel --gnu --will-cite -j0 --ungroup -n1 --halt now,fail=1 \
          "xargs < $ARGFILE -d '\n' bash -c '{} "$@"' --"
    ''
  );

in {
  imports = [ ./cmds-api.nix ];

  nix-app.main = writeScript "cmd-runner" ''
    #!${bash}/bin/bash
    set -eu
    set -o pipefail
    export SESSION="$(${libuuid}/bin/uuidgen)"
    export ARGFILE="${writeText "args" (concatStringsSep "\n" (tail args))}";
    PATH="${parallel}/bin:${findutils}/bin:${bash}/bin:$PATH"
    ${seq-scripts}
  '';
}
