#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUSIC_DIR="${SCRIPT_DIR}/music"
ORIGINALS_DIR="${MUSIC_DIR}/originals"
SEPARATED_DIR="${MUSIC_DIR}/separated"

API_BASE="https://api.replicate.com/v1"

# ─── Prerequisites ───────────────────────────────────────────────────────────

echo "Checking prerequisites..."

command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg not found. Install with: sudo apt install ffmpeg"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found. Install with: sudo apt install jq"; exit 1; }
[ -n "${REPLICATE_API_TOKEN:-}" ] || { echo "ERROR: REPLICATE_API_TOKEN not set"; exit 1; }

# Validate token
echo "Validating API token..."
ACCOUNT=$(curl -s -H "Authorization: Bearer ${REPLICATE_API_TOKEN}" "${API_BASE}/account")
USERNAME=$(echo "$ACCOUNT" | jq -r '.username // empty')
[ -n "$USERNAME" ] || { echo "ERROR: Invalid REPLICATE_API_TOKEN"; exit 1; }
echo "  Authenticated as: ${USERNAME}"

mkdir -p "$ORIGINALS_DIR" "$SEPARATED_DIR"

# ─── Helper: Run a Replicate prediction ──────────────────────────────────────

run_prediction() {
    local model_or_version="$1"
    local input_json="$2"

    echo "  Creating prediction for ${model_or_version}..." >&2

    local body endpoint
    if [[ "$model_or_version" == *:* ]]; then
        # version:ID format - use /v1/predictions with version
        local version="${model_or_version#*:}"
        body="{\"version\": \"${version}\", \"input\": ${input_json}}"
        endpoint="${API_BASE}/predictions"
    else
        # owner/model format - use /v1/models/.../predictions
        body="{\"input\": ${input_json}}"
        endpoint="${API_BASE}/models/${model_or_version}/predictions"
    fi

    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${REPLICATE_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Prefer: wait=60" \
        -d "$body" \
        "$endpoint")

    local status
    status=$(echo "$response" | jq -r '.status // empty')

    if [ "$status" = "succeeded" ]; then
        echo "$response"
        return 0
    elif [ "$status" = "failed" ] || [ "$status" = "canceled" ]; then
        echo "ERROR: Prediction failed: $(echo "$response" | jq -r '.error')" >&2
        return 1
    fi

    # Poll for completion
    local prediction_id
    prediction_id=$(echo "$response" | jq -r '.id // empty')
    if [ -z "$prediction_id" ]; then
        echo "ERROR: No prediction ID in response:" >&2
        echo "$response" >&2
        return 1
    fi

    echo "  Polling prediction ${prediction_id} (status: ${status})..." >&2

    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        sleep 5
        response=$(curl -s -H "Authorization: Bearer ${REPLICATE_API_TOKEN}" "${API_BASE}/predictions/${prediction_id}")
        status=$(echo "$response" | jq -r '.status')

        if [ "$status" = "succeeded" ]; then
            echo "$response"
            return 0
        elif [ "$status" = "failed" ] || [ "$status" = "canceled" ]; then
            echo "ERROR: Prediction ${prediction_id} ${status}: $(echo "$response" | jq -r '.error')" >&2
            return 1
        fi

        echo "  Still ${status}... (attempt $((attempt+1))/${max_attempts})" >&2
        attempt=$((attempt+1))
    done

    echo "ERROR: Prediction timed out after $((max_attempts * 5)) seconds" >&2
    return 1
}

# Helper: download a file and verify it's not empty
download_output() {
    local url="$1"
    local dest="$2"

    curl -s -L -o "$dest" "$url"
    [ -s "$dest" ] || { echo "ERROR: Downloaded file is empty: ${dest}" >&2; return 1; }
    echo "  Downloaded: ${dest}"
}

# ─── Step 1: Generate Orchestra with Cannons ─────────────────────────────────

echo ""
echo "=== Step 1/4: Generating orchestral music with cannons ==="

STABLE_AUDIO_VERSION="version:9aff84a639f96d0f7e6081cdea002d15133d0043727f849c40abdd166b7c75a8"

ORCHESTRA_RESULT=$(run_prediction "$STABLE_AUDIO_VERSION" '{
    "prompt": "epic orchestral music, 1812 overture style, dramatic strings and brass, cannon fire explosions, triumphant classical symphony",
    "seconds_total": 20,
    "steps": 100,
    "cfg_scale": 7
}')
ORCHESTRA_URL=$(echo "$ORCHESTRA_RESULT" | jq -r '.output // empty')
[ -n "$ORCHESTRA_URL" ] || { echo "ERROR: No output URL for orchestra"; exit 1; }
download_output "$ORCHESTRA_URL" "${ORIGINALS_DIR}/orchestra-cannons.wav"

# ─── Step 2: Generate Female Vocals ──────────────────────────────────────────

echo ""
echo "=== Step 2/4: Generating female vocals ==="

VOCALS_RESULT=$(run_prediction "$STABLE_AUDIO_VERSION" '{
    "prompt": "female opera singer, soprano vocals, classical singing, powerful voice, no instruments",
    "seconds_total": 20,
    "steps": 100,
    "cfg_scale": 7
}')
VOCALS_URL=$(echo "$VOCALS_RESULT" | jq -r '.output // empty')
[ -n "$VOCALS_URL" ] || { echo "ERROR: No output URL for vocals"; exit 1; }
download_output "$VOCALS_URL" "${ORIGINALS_DIR}/female-vocals.wav"

# ─── Step 3: Generate Drums/Percussion ───────────────────────────────────────

echo ""
echo "=== Step 3/4: Generating percussion ==="

DRUMS_RESULT=$(run_prediction "$STABLE_AUDIO_VERSION" '{
    "prompt": "orchestral percussion, timpani drums, dramatic drum rolls, classical percussion section",
    "seconds_total": 20,
    "steps": 100,
    "cfg_scale": 7
}')
DRUMS_URL=$(echo "$DRUMS_RESULT" | jq -r '.output // empty')
[ -n "$DRUMS_URL" ] || { echo "ERROR: No output URL for drums"; exit 1; }
download_output "$DRUMS_URL" "${ORIGINALS_DIR}/percussion.wav"

# ─── Step 4: Generate Bass/Low Strings ───────────────────────────────────────

echo ""
echo "=== Step 4/4: Generating bass section ==="

BASS_RESULT=$(run_prediction "$STABLE_AUDIO_VERSION" '{
    "prompt": "deep orchestral bass, cello and double bass, low strings, rich bass tones",
    "seconds_total": 20,
    "steps": 100,
    "cfg_scale": 7
}')
BASS_URL=$(echo "$BASS_RESULT" | jq -r '.output // empty')
[ -n "$BASS_URL" ] || { echo "ERROR: No output URL for bass"; exit 1; }
download_output "$BASS_URL" "${ORIGINALS_DIR}/bass-strings.wav"

# ─── Step 5: Mix all audio with ffmpeg ───────────────────────────────────────

echo ""
echo "=== Step 5: Mixing music with ffmpeg ==="

TARGET_DURATION=20

ffmpeg -y \
    -i "${ORIGINALS_DIR}/orchestra-cannons.wav" \
    -i "${ORIGINALS_DIR}/female-vocals.wav" \
    -i "${ORIGINALS_DIR}/percussion.wav" \
    -i "${ORIGINALS_DIR}/bass-strings.wav" \
    -filter_complex "
        [0:a]aresample=44100,aformat=sample_fmts=fltp,apad=whole_dur=${TARGET_DURATION},atrim=0:${TARGET_DURATION},volume=0.8[a0];
        [1:a]aresample=44100,aformat=sample_fmts=fltp,apad=whole_dur=${TARGET_DURATION},atrim=0:${TARGET_DURATION},volume=1.2[a1];
        [2:a]aresample=44100,aformat=sample_fmts=fltp,apad=whole_dur=${TARGET_DURATION},atrim=0:${TARGET_DURATION},volume=0.9[a2];
        [3:a]aresample=44100,aformat=sample_fmts=fltp,apad=whole_dur=${TARGET_DURATION},atrim=0:${TARGET_DURATION},volume=0.7[a3];
        [a0][a1][a2][a3]amix=inputs=4:duration=longest:normalize=0[out]
    " \
    -map "[out]" \
    -ar 44100 -ac 1 \
    "${MUSIC_DIR}/mixed.wav"

[ -s "${MUSIC_DIR}/mixed.wav" ] || { echo "ERROR: ffmpeg mixing failed"; exit 1; }
echo "  Created: ${MUSIC_DIR}/mixed.wav"

# ─── Step 6: Upload mixed audio to Replicate ─────────────────────────────────

echo ""
echo "=== Step 6: Uploading mixed music to Replicate ==="

UPLOAD_RESPONSE=$(curl -s -X POST \
    "${API_BASE}/files" \
    -H "Authorization: Bearer ${REPLICATE_API_TOKEN}" \
    -F "content=@${MUSIC_DIR}/mixed.wav;type=audio/wav;filename=mixed.wav")

FILE_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.urls.get // .url // empty')
if [ -z "$FILE_URL" ]; then
    echo "WARNING: Files API didn't return a URL, trying base64 data URI..."
    MIXED_B64=$(base64 -w0 "${MUSIC_DIR}/mixed.wav")
    FILE_URL="data:audio/wav;base64,${MIXED_B64}"
fi
echo "  Upload ready"

# ─── Step 7: Run Demucs separation ───────────────────────────────────────────

echo ""
echo "=== Step 7: Running Demucs separation ==="

DEMUCS_VERSION="version:25a173108cff36ef9f80f854c162d01df9e6528be175794b81158fa03836d953"

DEMUCS_RESULT=$(run_prediction "$DEMUCS_VERSION" "{
    \"audio\": \"${FILE_URL}\",
    \"model_name\": \"htdemucs\",
    \"output_format\": \"mp3\",
    \"shifts\": 2,
    \"overlap\": 0.25
}")

echo "  Demucs completed. Downloading stems..."

for stem in vocals bass drums other; do
    STEM_URL=$(echo "$DEMUCS_RESULT" | jq -r ".output.${stem} // empty")
    if [ -n "$STEM_URL" ] && [ "$STEM_URL" != "null" ]; then
        download_output "$STEM_URL" "${SEPARATED_DIR}/${stem}.mp3"
    else
        echo "  WARNING: No ${stem} stem in output"
    fi
done

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "========================================="
echo "  Music Separation Demo - Complete!"
echo "========================================="
echo ""
echo "Original tracks:"
ls -lh "${ORIGINALS_DIR}/"
echo ""
echo "Mixed music:"
ls -lh "${MUSIC_DIR}/mixed.wav"
echo ""
echo "Separated stems:"
ls -lh "${SEPARATED_DIR}/"
echo ""
echo "Open music-separation.html in a browser to view the demo."
