#!/bin/sh

set -xe

VIDEO="$1"
VIDEO_NAME="$(basename "${VIDEO}")"
VIDEO_DIR="$(dirname "${VIDEO}")"
THUMBNAIL="/tmp/thumbnail_${VIDEO_NAME}.png"
ffmpeg -i "${VIDEO}" -frames:v 1 "${THUMBNAIL}"

CROP=$(sarp --format '%w:%h:%x:%y' "${THUMBNAIL}")

ffmpeg -i "${VIDEO}" -vf "crop=${CROP}" "${VIDEO_DIR}/cropped_${VIDEO_NAME}"
