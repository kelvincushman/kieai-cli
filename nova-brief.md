# Nova — Printing Press Brief for KIE.AI

## The Name
`nova` — a CLI for KIE.AI's unified AI creative platform.

## The Secret Identity
KIE.AI is not a model marketplace. It is a **creative studio on a single API key**.
One bearer token unlocks Flux-2, Kling, Sora2, Suno, Google Imagen, Ideogram, ElevenLabs,
Topaz, and 90+ more — all 30–80% cheaper than official APIs.

Nova's job is to make that feel like superpowers from your terminal, not HTTP juggling.
The agent or human calling `nova` should think in *outcomes*, not task IDs.

## The Killer Commands

Nova's design principle: **outcome commands, not API wrappers**.
Never return a raw task ID unless the user asked for one. Default: poll until done,
print the result URL (and download it if --out is given).

```bash
# Generate an image (smart default: flux-2/pro-text-to-image)
nova image "a fox in snow, cinematic lighting" --out fox.jpg

# Pick a different model
nova image "fox in snow" --model grok            # grok-imagine/text-to-image
nova image "fox in snow" --model ideogram        # ideogram/v3-text-to-image
nova image "fox in snow" --model imagen4         # google/imagen4
nova image "fox in snow" --model seedream        # seedream/4-5-text-to-image

# Image-to-image
nova image "make it look like a watercolor painting" --from photo.jpg --model flux-pro

# Generate a video (smart default: kling-2.6/text-to-video)
nova video "a surfer catches a wave at sunset" --out surf.mp4

# Animate an existing image
nova video "the cat slowly turns its head" --from cat.jpg --out animated.mp4

# Different video models
nova video "city timelapse" --model sora2        # sora-2/text-to-video
nova video "city timelapse" --model kling3       # kling-3.0/text-to-video
nova video "city timelapse" --model wan          # wan-2.7/text-to-video

# Generate music (Suno V4_5 by default)
nova music "a chill lo-fi hip hop track for studying"
nova music "epic orchestral theme for a fantasy battle" --instrumental --out battle.mp3
nova music "upbeat pop song about summer" --model V5 --out summer.mp3

# Custom music with style control
nova music "in the city lights at midnight" \
  --style "Indie Pop, Dreamy, Female Vocals" \
  --title "Neon Midnight" \
  --vocal-gender f \
  --out neon.mp3

# Generate lyrics first, then use them
nova lyrics "a love song about long-distance relationships" --out lyrics.txt
nova music --lyrics lyrics.txt --style "Folk, Acoustic Guitar" --title "Miles Apart"

# Extend a track
nova extend <task-id-or-last> --seconds 30

# Upscale media
nova upscale image.jpg --scale 4 --out image_4x.jpg
nova upscale video.mp4 --out video_hd.mp4

# Remove background
nova rmbg photo.jpg --out photo_nobg.png

# Check any task manually
nova status <task-id>
nova wait <task-id>        # poll until done, print result

# History (SQLite local store)
nova history               # list recent tasks
nova history --images      # images only
nova history --videos      # videos only
nova history --music       # music only
nova history --limit 20    # last 20
nova history --failed      # failed tasks to diagnose
nova open <task-id>        # open result in browser/player
nova download <task-id>    # re-download result to current dir

# Account
nova credits               # show remaining credits
nova models                # list all available models with estimated credit cost
```

## Model Aliases
Build smart aliases so users never have to type model strings:

| Alias | Resolves to |
|-------|------------|
| `flux-pro` | `flux-2/pro-text-to-image` |
| `flux` | `flux-2/flex-text-to-image` |
| `grok` | `grok-imagine/text-to-image` |
| `ideogram` | `ideogram/v3-text-to-image` |
| `imagen4` | `google/imagen4` |
| `imagen4-fast` | `google/imagen4-fast` |
| `seedream` | `seedream/4-5-text-to-image` |
| `kling` | `kling-2.6/text-to-video` |
| `kling3` | `kling-3.0/text-to-video` |
| `sora2` | `sora-2/text-to-video` |
| `sora2-pro` | `sora-2-pro/text-to-video` |
| `wan` | `wan-2.7/text-to-video` |
| `hailuo` | `hailuo/02-text-to-video-pro` |
| `bytedance` | `bytedance/seedance-2` |

## Polling Strategy
All KIE.AI tasks are async. Nova should poll transparently:
- Show a spinner with elapsed time during generation
- Image tasks: typically 10–45 seconds
- Video tasks: typically 2–10 minutes
- Music tasks: typically 30–90 seconds
- Exponential backoff: 2s → 4s → 8s → 16s → max 30s
- Timeout after 15 minutes with a "still running, check `nova status <id>`" message
- On success: print result URL + auto-download if `--out` was given

## Local SQLite Store
Every task Nova creates should be saved locally:
- taskId, model, prompt, state, resultUrls, creditsConsumed, createTime, completeTime
- `nova history` queries this store — no API call needed
- `nova download <taskId>` re-downloads result from stored URL
- Useful for: re-running prompts, building prompt libraries, tracking spend

## Auth Configuration
API key stored in environment variable `KIE_API_KEY` or config file `~/.nova/config`.
`nova auth <api-key>` sets it.
`nova credits` reads from https://api.kie.ai (common API endpoint).

## Agent-Native Output
With `--json` flag: emit clean JSON on stdout for agent pipelines.
Without: human-readable output with progress indicators.
Use `--quiet` to suppress spinner (useful in CI/scripts).

## Default Model Selection Logic
When the user doesn't specify a model:
- `nova image` → `flux-2/pro-text-to-image` (best quality/value for images)
- `nova video` → `kling-2.6/text-to-video` (best quality/value for video)
- `nova video --from <image>` → `kling-2.6/image-to-video`
- `nova music` → Suno V4_5 (best all-around music model)
- `nova music --instrumental` → Suno V4_5 instrumental

## The Compound Command Nova Should Champion
```bash
nova image "product photo: minimalist white coffee mug on marble" --out mug.jpg && \
nova video "the coffee mug slowly rotates" --from mug.jpg --out mug_rotate.mp4
```
Two commands, one creative pipeline. That's Nova's superpower.
