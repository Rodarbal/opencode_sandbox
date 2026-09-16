# opencode-sandbox

A locked-down Docker setup for running the [opencode](https://opencode.ai) agent so that:

- It can only see and modify one folder on your host (`AI_Project`), never the rest of your filesystem.
- It can only reach the network via a proxy that allowlists `*.openrouter.ai` — nothing else, no matter what the agent tries to do.
- Everything is defined in this repo, so the environment can always be blown away and rebuilt to a known-clean state.

## How the isolation works

- **Filesystem:** the container only has one bind mount from your real disk — `AI_PROJECT_PATH` → `/workspace`. Nothing else on your machine is mounted in, so the agent cannot read or write outside that folder, and destructive commands (`rm -rf`, etc.) are physically confined to what's mounted.
- **Network:** the `agent` service sits on a Docker network marked `internal: true`, which has *no* route to the internet at all — not "firewalled," but literally no gateway. The only other thing on that network is the `proxy` service, which also has a leg on a normal internet-facing network. Squid on the proxy is configured to allow `CONNECT`/HTTPS only to `.openrouter.ai` and deny everything else. Even if opencode or a subprocess it spawns ignores the `HTTP_PROXY`/`HTTPS_PROXY` env vars, it still has nowhere to go.
- **Reset:** nothing durable lives in the image or the container layer. `docker compose down -v && docker compose up --build` throws away the container, rebuilds it fresh from this Dockerfile, and clears opencode's own config/session volumes. The only thing that persists is `AI_Project` on your host, since that's yours, not the sandbox's.

## Setup

1. Copy the env template and fill in your key + path:
   ```bash
   cp .env.example .env
   # edit .env: set OPENROUTER_API_KEY and AI_PROJECT_PATH
   ```
2. Build and start:
   ```bash
   docker compose up --build
   ```
   The `agent` container's entrypoint is `opencode`, so this drops you into the opencode TUI with `/workspace` as the project root.

3. To run a one-off non-interactive command instead of the TUI:
   ```bash
   docker compose run --rm agent run "your prompt here"
   ```

## Usage
docker compose up -d --build

docker compose exec agent opencode

## Verifying the sandbox

- Confirm no host access: `docker compose exec agent ls /` should show only the container's own filesystem, and `ls /workspace` should show only your `AI_Project` contents.
- Confirm network lockdown: from inside the container, `curl https://google.com` should hang/fail, while opencode's own OpenRouter calls should work normally.

## Resetting to default

```bash
docker compose down -v   # removes the container AND opencode's config/session volumes
docker compose up --build
```

Your `AI_Project` folder is untouched by this, since it lives on your host, not in a volume.

## Notes / things to double check

- The Dockerfile installs opencode via the official install script and pins nothing — pin a version if you want fully reproducible builds (check `opencode --version` after build and consider adding `VERSION=x.y.z` to the install command per opencode's docs if they support it).
- If you want the agent to only *read* `AI_Project` and never write to it, change the volume line in `docker-compose.yml` to add `:ro`:
  ```yaml
  - ${AI_PROJECT_PATH}:/workspace:ro
  ```
- This setup doesn't protect `AI_Project` itself from an errant `rm -rf` — that's the folder you told it to work in, so it's writable by design. If you want to be able to undo agent changes there, keep that folder under its own git repo (or back it up) separately from this sandbox repo.
- Squid logs (`proxy/`) will accumulate inside the proxy container's own filesystem unless you mount a volume for them; they're not persisted by default here.
