#!/usr/bin/env python3
"""
Validate all 10,000 ClawPunks NFTs:
1. Each trait index is 0-6 (valid palette)
2. All 10,000 have unique color combinations
3. All SVG fill colors are from the 7-color palette

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

# Must match ClawPunks.sol exactly
PALETTE = [
    "#000000", "#ffffff", "#e53935", "#ffeb3b", "#00897b", "#2196f3", "#8e24aa",
]
PIXEL_MAP = [
    "00000000000000000000",
    "00000000000000000000",
    "01000000000000000010",
    "01100000044000000110",
    "01101000244200010110",
    "01111004444440011110",
    "01111144444444111110",
    "00111044444444011100",
    "00000044444444000000",
    "00000000433400000000",
    "00000000433400000000",
    "00000000433400000000",
    "00000000433400000000",
    "00000000433400000000",
    "00000004444440000000",
    "00000044444444000000",
    "00000004444440000000",
    "00000000444400000000",
    "00000000044000000000",
    "00000000000000000000",
]
MAX_SUPPLY = 10_000


def get_traits(token_id: int) -> tuple[int, int, int, int, int]:
    """Replicate contract _getTraits. Returns (bgIdx, bodyIdx, torsoIdx, clawIdx, eyeIdx)."""
    bg_idx = token_id % 7
    body_idx = (token_id // 7) % 7
    torso_idx = (token_id // 49) % 7
    claw_idx = (token_id // 343) % 7
    eye_idx = (token_id // 2401) % 7
    return (bg_idx, body_idx, torso_idx, claw_idx, eye_idx)


def get_color(pixel_type: int, token_id: int) -> str:
    """Replicate contract _getColor."""
    bg_idx, body_idx, torso_idx, claw_idx, eye_idx = get_traits(token_id)
    if pixel_type == 0:
        return PALETTE[bg_idx]
    if pixel_type == 1:
        return PALETTE[claw_idx]
    if pixel_type == 2:
        return PALETTE[eye_idx]
    if pixel_type == 3:
        return PALETTE[torso_idx]
    if pixel_type == 4:
        return PALETTE[body_idx]
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
        # 1. Trait validity (0-6)
        bg, body, torso, claw, eye = get_traits(token_id)
        for name, idx in [
            ("bg", bg),
            ("body", body),
            ("torso", torso),
            ("claw", claw),
            ("eye", eye),
        ]:
            if not 0 <= idx <= 6:
                violations.append(f"Token {token_id}: {name}Idx={idx} out of range")

        # 2. Uniqueness
        combo = (bg, body, torso, claw, eye)
        if combo in seen_combos:
            violations.append(f"Token {token_id}: duplicate combo {combo}")
        seen_combos.add(combo)

        # 3. SVG colors from palette only
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
    print("  - All trait indices in 0-6")
    print("  - All 10,000 color combinations unique")
    print("  - All SVG fill colors from 7-color palette")
    return 0


if __name__ == "__main__":
    sys.exit(main())
