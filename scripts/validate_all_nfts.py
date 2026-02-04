#!/usr/bin/env python3
"""
Validate all 10,000 ClawPunks NFTs:
1. Each trait index is 0-22 (valid palette)
2. All 10,000 have unique color combinations
3. All SVG fill colors are from the 23-color palette

Usage:
  python scripts/validate_all_nfts.py

To validate against deployed contract tokenURIs (post-deploy):
  forge script script/PreviewTokenURI.s.sol --sig "run(uint256)" 0
  # Then decode base64 and compare SVG output
"""
import base64
import json
import re
import sys
from pathlib import Path

# Add project root
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# Must match ClawPunks.sol exactly (3 parts: background, body, eyes; 23 colors)
PALETTE = [
    "#000000", "#FFFFFF", "#D32F2F", "#FF6A00", "#FFD100",
    "#9AFF00", "#00B894", "#0B5D1E", "#00E5FF", "#42A5F5",
    "#0033A0", "#2E0066", "#7C3AED", "#FF2F92", "#FF8A80",
    "#6D1B1B", "#5A0000", "#C46210", "#7A8B00", "#6B7C8F",
    "#263238", "#F3E2B3", "#00FF9C",
]
PIXEL_MAP = [
    "00000000000000000000",
    "00000000000000000000",
    "01000000000000000010",
    "01100000011000000110",
    "01101000222200010110",
    "01111001111110011110",
    "01111111111111111110",
    "00111011111111011100",
    "00000011111111000000",
    "00000000111100000000",
    "00000000111100000000",
    "00000000111100000000",
    "00000000111100000000",
    "00000000111100000000",
    "00000001111110000000",
    "00000011111111000000",
    "00000001111110000000",
    "00000000111100000000",
    "00000000011000000000",
    "00000000000000000000",
]
MAX_SUPPLY = 10_000


def get_traits(token_id: int) -> tuple[int, int, int]:
    """Replicate contract _getTraits. Returns (bgIdx, bodyIdx, eyeIdx)."""
    bg_idx = token_id % 23
    body_idx = (token_id // 23) % 23
    # Eye: pick from 22 colors excluding bodyIdx. Ensures eye != body and uniqueness.
    eye_slot = (token_id // 529) % 22
    eye_idx = 0
    count = 0
    for c in range(23):
        if c != body_idx:
            if count == eye_slot:
                eye_idx = c
                break
            count += 1
    return (bg_idx, body_idx, eye_idx)


def get_color(pixel_type: int, token_id: int) -> str:
    """Replicate contract _getColor. 0=background, 1=body, 2=eye."""
    bg_idx, body_idx, eye_idx = get_traits(token_id)
    if pixel_type == 0:
        return PALETTE[bg_idx]
    if pixel_type == 1:
        return PALETTE[body_idx]
    if pixel_type == 2:
        return PALETTE[eye_idx]
    return PALETTE[bg_idx]


def build_svg(token_id: int) -> str:
    """Replicate contract _buildSVG."""
    w = h = 20 * 20
    rects = []
    for y in range(20):
        for x in range(20):
            c = int(PIXEL_MAP[y][x])
            fill = get_color(c, token_id)
            px, py = x * 20, y * 20
            rects.append(
                f'<rect x="{px}" y="{py}" width="20" height="20" fill="{fill}"/>'
            )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}" shape-rendering="crispEdges">'
        + "".join(rects)
        + "</svg>"
    )


def extract_fill_colors(svg: str) -> set[str]:
    """Extract all fill="..." values from SVG."""
    return set(re.findall(r'fill="([^"]+)"', svg))


def main() -> int:
    seen_combos: set[tuple[int, ...]] = set()
    violations: list[str] = []

    for token_id in range(MAX_SUPPLY):
        # 1. Trait validity (0-22)
        bg, body, eye = get_traits(token_id)
        for name, idx in [
            ("bg", bg),
            ("body", body),
            ("eye", eye),
        ]:
            if not 0 <= idx <= 22:
                violations.append(f"Token {token_id}: {name}Idx={idx} out of range")

        # 2. Eyes must not match body
        if eye == body:
            violations.append(f"Token {token_id}: eyes must not match body")

        # 3. Uniqueness
        combo = (bg, body, eye)
        if combo in seen_combos:
            violations.append(f"Token {token_id}: duplicate combo {combo}")
        seen_combos.add(combo)

        # 4. SVG colors from palette only
        svg = build_svg(token_id)
        fills = extract_fill_colors(svg)
        for f in fills:
            if f not in PALETTE:
                violations.append(f"Token {token_id}: non-palette color {f}")

    if violations:
        print("VALIDATION FAILED:")
        for v in violations[:50]:
            print(f"  {v}")
        if len(violations) > 50:
            print(f"  ... and {len(violations) - 50} more")
        return 1

    print("All 10,000 NFTs validated:")
    print("  - All trait indices in 0-22")
    print("  - All 10,000 color combinations unique")
    print("  - All SVG fill colors from 23-color palette")
    return 0


if __name__ == "__main__":
    sys.exit(main())
