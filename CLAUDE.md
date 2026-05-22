# Nova CLI — Claude Code Generation Brief

You are on an Ubuntu dev server with **Go** and **printing-press v4.9.0+** already installed.
Your job is to generate, build, and install the **Nova CLI** — a full-featured terminal client
for the KIE.AI API — using the files in this directory.

---

## What's Here

| File | Purpose |
|------|---------|
| `kie-ai-openapi.yaml` | Complete KIE.AI OpenAPI 3.0 spec (all 4 API families, 100+ models) |
| `nova-brief.md` | Nova CLI design brief — commands, UX, polling strategy, model aliases |
| `setup-nova.sh` | Automated setup script (reference — you may run it or execute steps manually) |

---

## Your Goal

Generate a production-quality Go CLI called **`nova`** that wraps the entire KIE.AI API.
Nova's design philosophy: **outcome commands, not API wrappers**.
- Default: poll until done, print result URL, auto-download if `--out` is given
- Never return a raw task ID unless the user asked for one
- Local SQLite store for task history (`nova history`)
- `--json` flag for agent pipelines, `--quiet` for CI

Read `nova-brief.md` in full before generating — it defines the exact command surface.

---

## Step 1 — Generate the CLI

Run printing-press generate with the spec and brief as context:

```bash
cd ~/nova-setup

printing-press generate \
  --spec ./kie-ai-openapi.yaml \
  --name nova \
  --output ~/nova \
  --spec-source official
```

If `claude` CLI is available for the polish pass, add `--polish`:

```bash
printing-press generate \
  --spec ./kie-ai-openapi.yaml \
  --name nova \
  --output ~/nova \
  --spec-source official \
  --polish
```

**Expected output:** a Go project in `~/nova/` with `go.mod`, command files, and a working `main.go`.

---

## Step 2 — Inspect What Was Generated

```bash
ls -la ~/nova/
cat ~/nova/go.mod
find ~/nova -name "*.go" | head -20
```

Check that the generated commands match the Nova brief:
- `nova image`, `nova video`, `nova music`, `nova lyrics`
- `nova upscale`, `nova rmbg`, `nova stems`
- `nova status`, `nova wait`, `nova history`
- `nova credits`, `nova models`, `nova auth`

If key commands are missing, use `printing-press emboss` to do a second-pass improvement:

```bash
printing-press emboss --dir ~/nova
```

---

## Step 3 — Build the Binary

```bash
cd ~/nova

# If go.mod is at root:
go build -o ~/go/bin/nova .

# If main is under cmd/nova/:
go build -o ~/go/bin/nova ./cmd/nova/
```

Verify:
```bash
nova --help
nova --version
```

---

## Step 4 — Wire Into PATH

```bash
export PATH="$PATH:$(go env GOPATH)/bin"
# Make permanent:
echo 'export PATH="$PATH:$(go env GOPATH)/bin"' >> ~/.bashrc
```

---

## Step 5 — Set API Key

```bash
export KIE_API_KEY=your_api_key_here
# or:
nova auth your_api_key_here
```

Get a key at: https://kie.ai/api-key

---

## Step 6 — Smoke Test

```bash
nova models                                        # list all models + credit costs
nova credits                                       # check account balance
nova image "a red fox in snow, cinematic" --out fox.jpg
nova video "surfer catches a wave at sunset" --out surf.mp4
nova music "chill lo-fi hip hop for studying" --out track.mp3
```

---

## Key Design Requirements (verify these in the generated code)

### Polling
All KIE.AI tasks are async. Nova must poll transparently:
- Spinner with elapsed time during generation
- Exponential backoff: 2s → 4s → 8s → 16s → max 30s
- Timeout after 15 minutes with: "still running, check `nova status <id>`"
- On success: print result URL + auto-download if `--out` was given

### Model Aliases
Nova must resolve short aliases to full model strings:

| Alias | Resolves to |
|-------|------------|
| `flux-pro` | `flux-2/pro-text-to-image` |
| `flux` | `flux-2/flex-text-to-image` |
| `grok` | `grok-imagine/text-to-image` |
| `ideogram` | `ideogram/v3-text-to-image` |
| `imagen4` | `google/imagen4` |
| `seedream` | `seedream/4-5-text-to-image` |
| `kling` | `kling-2.6/text-to-video` |
| `kling3` | `kling-3.0/text-to-video` |
| `sora2` | `sora-2/text-to-video` |
| `wan` | `wan-2.7/text-to-video` |
| `hailuo` | `hailuo/02-text-to-video-pro` |

### Default Models
- `nova image` → `flux-2/pro-text-to-image`
- `nova video` → `kling-2.6/text-to-video`
- `nova video --from <image>` → `kling-2.6/image-to-video`
- `nova music` → Suno V4_5

### Auth
- API key from `KIE_API_KEY` env var or `~/.nova/config`
- All requests: `Authorization: Bearer <api_key>`
- Base URL: `https://api.kie.ai`

### SQLite History Store
Every task Nova submits should be saved locally:
- Fields: taskId, model, prompt, state, resultUrls, creditsConsumed, createTime, completeTime
- `nova history` queries this — no API call needed
- `nova download <taskId>` re-downloads from stored URL

---

## If Generation Needs Fixing

If the generated CLI is missing commands or has wrong behaviour, you can:

1. **Second-pass emboss:** `printing-press emboss --dir ~/nova`
2. **Hand-edit** specific command files in `~/nova/cmd/` or `~/nova/internal/`
3. **Re-generate with force:** `printing-press generate --spec ~/nova-setup/kie-ai-openapi.yaml --name nova --output ~/nova --force`

The nova-brief.md is the source of truth for what Nova should do. When in doubt, check it.
