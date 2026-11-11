#!/usr/bin/env bash
# Downloads the Poly Haven (CC0) assets used by the project at 1K resolution.
# Re-runnable: existing files are skipped. Requires curl.
#
#   bash tools/fetch_polyhaven_assets.sh
#
# Every asset here is CC0 (https://polyhaven.com/license). See docs/ASSET_LICENSES.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/assets/third_party/polyhaven"
RES="1k"

TEXTURES=(castle_wall_slates rock_tile_floor rock_wall_08)
TEXTURE_MAPS=(diff nor_gl rough ao)
MODELS=(large_castle_door large_iron_gate stone_fire_pit kite_shield antique_estoc rock_07)

fetch() { # url target
	if [[ -s "$2" ]]; then return; fi
	mkdir -p "$(dirname "$2")"
	curl -sfL --retry 3 -m 120 -o "$2" "$1" || { echo "FAILED: $1" >&2; rm -f "$2"; return 1; }
	echo "  $(basename "$2")  ($(wc -c < "$2") bytes)"
}

for id in "${TEXTURES[@]}"; do
	echo "texture $id"
	for map in "${TEXTURE_MAPS[@]}"; do
		fetch "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/$RES/$id/${id}_${map}_${RES}.jpg" \
			"$DEST/textures/$id/${id}_${map}_${RES}.jpg"
	done
done

for id in "${MODELS[@]}"; do
	echo "model $id"
	json="$(curl -sf -m 60 "https://api.polyhaven.com/files/$id")"
	gltf_url="https://dl.polyhaven.org/file/ph-assets/Models/gltf/$RES/$id/${id}_${RES}.gltf"
	fetch "$gltf_url" "$DEST/models/$id/${id}_${RES}.gltf"
	# Textures the glTF references: "textures/<name>_<RES>.jpg":{...,"url":...}.
	grep -oE "\"textures/[^\"]+_${RES}\.jpg\":\{[^{}]*\"url\":\"[^\"]+\"" <<< "$json" \
		| sed -E 's/^"([^"]+)":\{.*"url":"([^"]+)".*/\1 \2/' | sort -u \
		| while read -r rel url; do fetch "$url" "$DEST/models/$id/$rel"; done
	# The geometry buffer is shared by every resolution (hosted under any of them).
	bin_url="$(grep -oE "\"$id\.bin\":\{[^{}]*\"url\":\"[^\"]+\"" <<< "$json" | head -1 | sed -E 's/.*"url":"([^"]+)".*/\1/')"
	if [[ -n "$bin_url" ]]; then fetch "$bin_url" "$DEST/models/$id/$id.bin"; else echo "  no .bin listed for $id" >&2; fi
done
echo "done"
