{ stdenv, bash, nix-exec, makeWrapper }:

stdenv.mkDerivation {
  name = "nix-app";

  src = ./.;

  buildInputs = [ bash makeWrapper ];

  installPhase = ''
    mkdir -p "$out"
    cp -r "$src"/{bin,lib,modules} $out/
    chmod u+w -R $out
    chmod +rX -R $out
    wrapProgram "$out/bin/nix-app" --prefix PATH : "${nix-exec}/bin"
  '';
}
