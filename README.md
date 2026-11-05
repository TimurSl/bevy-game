# Bevy Game

> "If you know the enemy and know yourself, you need not fear the result of a hundred battles. If you know yourself but not the enemy, for every victory gained you will also suffer a defeat. If you know neither the enemy nor yourself, you will succumb in every battle."

Minimal [Bevy](https://bevy.org) project: an empty window. Builds with Nix for
x86_64, aarch64 and WebAssembly.

## Layout

| Path             | Purpose                                         |
|------------------|-------------------------------------------------|
| `src/main.rs`    | The game (window + 2D camera)                   |
| `web/index.html` | Page that hosts the wasm build                  |
| `flake.nix`      | Dev shell and all build targets                 |

## First-time setup

Flakes only see git-tracked files, and `Cargo.lock` must exist:

```sh
git init
nix develop -c cargo generate-lockfile
git add -A
```

## Develop

```sh
nix develop          # Rust toolchain + system libs
cargo run            # native window
```

## Build

```sh
nix build .#x86_64     # x86_64 Linux binary  -> result/bin/bevy-game
nix build .#aarch64    # aarch64 Linux binary (cross-compiled on x86_64)
nix build .#web        # static site          -> result/{index.html,game.js,game_bg.wasm}
nix build              # native for the current machine
```

Try the web build locally: `nix run .#web` then open <http://localhost:8080>
(`PORT=3000 nix run .#web` to change the port).

## Deploy to the x86 VPS

The web build is just static files. On the VPS (or copy over):

```sh
nix build .#web
rsync -rL result/ user@vps:/var/www/bevy-game/
```

Serve that directory with any web server (Caddy, nginx, ...). Make sure `.wasm`
is served as `application/wasm` (default in both). Browser needs WebGPU or WebGL2.

## Notes

- **wasm-bindgen mismatch:** the flake fails with a clear message if the
  `wasm-bindgen` version in `Cargo.lock` differs from nixpkgs' `wasm-bindgen-cli`;
  it prints the `cargo update -p wasm-bindgen --precise ...` command to fix it.
- Add assets later in an `assets/` dir; for the web build copy them next to
  `index.html` in the `web` derivation in `flake.nix`.
