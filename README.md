![deploy](https://github.com/WGBH-MLA/whisper-bot/actions/workflows/CD.yml/badge.svg)

# whisper-bot

This repository provides a pre-built docker image for OpenAI's Whisper model.

## Usage

To use the model, you can pull the pre-built docker image, or build the image yourself.

### Pre-built image

```bash
docker pull ghcr.io/wgbh-mla/whisper-bot:latest
```

### Build the image

```bash
docker build -t whisper-bot .
```

## Running Whisper

```bash
docker run --rm -itv $(pwd):/root -v $HOME/.cache/whisper/:/root/.cache/whisper/ ghcr.io/wgbh-mla/whisper-bot:latest whisper [WHISPER_ARGS] FILENAME
```

### Whisper Arguments

- `--model`: The model to use. Defaults to `base`.
  - Options: `tiny`, `base`, `small`, `medium`, `large`
- `--language`: The language to use. Defaults to `en`.

The full list of arguments can be found by running `whisper --help`

## ARM Support

If you are running on an ARM machine (including the Mac M series processors), use the `arm64-main` tag to get an ARM optimized image.

## Distributed whisper-bot

See the [whisper-bot](whisper-bot) directory for an example of running whisper-bot in a distributed system.

**Note**: _This script is specific to the GBH MLA environment and should only be used an an example._

## Credits

Created by [GBH Media Library & Archives](https://www.wgbh.org/foundation/archives)
