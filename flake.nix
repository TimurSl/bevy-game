{
  description = "Minimal Bevy game: native (x86_64 / aarch64) and WebAssembly builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, crane, rust-overlay }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        lib = pkgs.lib;

        pname = "bevy-game";
        wasmTarget = "wasm32-unknown-unknown";

        rustTargets = {
          x86_64-linux = "x86_64-unknown-linux-gnu";
          aarch64-linux = "aarch64-unknown-linux-gnu";
        };

        # Linux libraries Bevy needs to build / run.
        buildLibs = p: with p; [
          alsa-lib
          udev
          vulkan-loader
          libxkbcommon
          wayland
          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
        ];

        # Native build for `targetSystem`; cross-compiles if it differs from the host.
        mkNative = targetSystem:
          let
            p =
              if targetSystem == system then pkgs
              else import nixpkgs {
                localSystem = system;
                crossSystem = targetSystem;
                inherit overlays;
              };
            rustTarget = rustTargets.${targetSystem};
            craneLib = (crane.mkLib p).overrideToolchain (pp:
              pp.pkgsBuildHost.rust-bin.stable.latest.minimal.override {
                targets = [ rustTarget ];
              });
            linkerVar = "CARGO_TARGET_${lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] rustTarget)}_LINKER";
            commonArgs = {
              inherit pname;
              version = "0.1.0";
              src = craneLib.cleanCargoSource ./.;
              strictDeps = true;
              doCheck = false;
              nativeBuildInputs = [ p.pkg-config p.makeWrapper ];
              buildInputs = buildLibs p;
              CARGO_BUILD_TARGET = rustTarget;
              HOST_CC = "${p.stdenv.cc.nativePrefix}cc";
              ${linkerVar} = "${p.stdenv.cc.targetPrefix}cc";
            };
            cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          in
          craneLib.buildPackage (commonArgs // {
            inherit cargoArtifacts;
            # Bevy dlopen()s these at runtime; make the binary self-contained on Nix.
            postInstall = ''
              wrapProgram $out/bin/${pname} \
                --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (buildLibs p)}
            '';
          });

        # --- WebAssembly -----------------------------------------------------
        wasmToolchain = pkgs.rust-bin.stable.latest.minimal.override {
          targets = [ wasmTarget ];
        };
        wasmCraneLib = (crane.mkLib pkgs).overrideToolchain wasmToolchain;

        wasmArgs = {
          inherit pname;
          version = "0.1.0";
          src = wasmCraneLib.cleanCargoSource ./.;
          strictDeps = true;
          doCheck = false;
          CARGO_BUILD_TARGET = wasmTarget;
          RUSTFLAGS = ''--cfg getrandom_backend="wasm_js"'';
        };

        wasmCrate = wasmCraneLib.buildPackage (wasmArgs // {
          cargoArtifacts = wasmCraneLib.buildDepsOnly wasmArgs;
          installPhaseCommand = ''
            mkdir -p $out
            cp target/${wasmTarget}/release/*.wasm $out/
          '';
        });

        # wasm-bindgen-cli must match the wasm-bindgen crate version in Cargo.lock exactly.
        lockedBindgen =
          (lib.findFirst (x: x.name == "wasm-bindgen") null
            (builtins.fromTOML (builtins.readFile ./Cargo.lock)).package).version;
        wasmBindgen =
          assert lib.assertMsg (pkgs.wasm-bindgen-cli.version == lockedBindgen) ''
            wasm-bindgen version mismatch: Cargo.lock has ${lockedBindgen}, nixpkgs ships ${pkgs.wasm-bindgen-cli.version}.
            Fix with: cargo update -p wasm-bindgen --precise ${pkgs.wasm-bindgen-cli.version}
          '';
          pkgs.wasm-bindgen-cli;

        # Static site: index.html + game.js + game_bg.wasm
        web = pkgs.runCommand "${pname}-web" { nativeBuildInputs = [ wasmBindgen ]; } ''
          mkdir -p $out
          wasm-bindgen --target web --no-typescript \
            --out-dir $out --out-name game \
            ${wasmCrate}/bevy_game.wasm
          cp ${./web/index.html} $out/index.html
        '';
      in
      {
        packages = {
          default = mkNative system;
          x86_64 = mkNative "x86_64-linux";
          aarch64 = mkNative "aarch64-linux";
          inherit web;
        };

        # `nix run .#web` -> http://localhost:8080
        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };
          web = {
            type = "app";
            program = toString (pkgs.writeShellScript "serve-web" ''
              exec ${pkgs.caddy}/bin/caddy file-server --root ${web} --listen :''${PORT:-8080}
            '');
          };
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            (pkgs.rust-bin.stable.latest.default.override {
              targets = [ wasmTarget ] ++ lib.attrValues rustTargets;
              extensions = [ "rust-src" "rust-analyzer" ];
            })
            pkgs.pkg-config
            pkgs.wasm-bindgen-cli
            pkgs.caddy
          ];
          buildInputs = buildLibs pkgs;
          LD_LIBRARY_PATH = lib.makeLibraryPath (buildLibs pkgs);
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}
