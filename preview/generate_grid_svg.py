# generate_grid_svg.py
# Generates a 20x20 SVG grid (columns A..T, rows 1..20) with specified colored cells.
# Run: python generate_grid_svg.py

from string import ascii_uppercase

# Configuration
COLUMNS = list(ascii_uppercase[:20])  # A..T
ROWS = list(range(1, 21))             # 1..20
PIXEL = 20                            # size of each square in pixels
SVG_WIDTH = PIXEL * len(COLUMNS)
SVG_HEIGHT = PIXEL * len(ROWS)

# Helper functions
def col_index(col_letter):
    return COLUMNS.index(col_letter.upper())

def parse_cell(cell):
    """Parse a single cell like 'B3' -> ('B', 3)."""
    cell = cell.strip().upper()
    # split letters and digits
    letters = ''.join([c for c in cell if c.isalpha()])
    digits = ''.join([c for c in cell if c.isdigit()])
    return (letters, int(digits))

def expand_range(range_str):
    """
    Expand a range like 'G7=>N7' or 'I10=>I14' into a list of cell strings.
    If input is a single cell (no =>) returns that single cell.
    """
    range_str = range_str.strip().upper()
    if '=>' not in range_str:
        return [range_str]
    left, right = [s.strip() for s in range_str.split('=>')]
    colL, rowL = parse_cell(left)
    colR, rowR = parse_cell(right)
    # If same row, expand columns
    if rowL == rowR:
        start = col_index(colL)
        end = col_index(colR)
        step = 1 if end >= start else -1
        return [f"{COLUMNS[c]}{rowL}" for c in range(start, end + step, step)]
    # If same column, expand rows
    if colL == colR:
        start = rowL
        end = rowR
        step = 1 if end >= start else -1
        return [f"{colL}{r}" for r in range(start, end + step, step)]
    # If both differ, expand rectangle (columns then rows)
    start_c = col_index(colL)
    end_c = col_index(colR)
    start_r = rowL
    end_r = rowR
    step_c = 1 if end_c >= start_c else -1
    step_r = 1 if end_r >= start_r else -1
    cells = []
    for c in range(start_c, end_c + step_c, step_c):
        for r in range(start_r, end_r + step_r, step_r):
            cells.append(f"{COLUMNS[c]}{r}")
    return cells

def expand_list(items):
    """Given a list of cell strings and ranges, return a flat set of cell names."""
    out = set()
    for it in items:
        for c in expand_range(it):
            out.add(c)
    return out

# User-provided color lists (strings and ranges allowed)
green_list = [
    "B3","B4","B5","B6","B7",
    "C4","C5","C6","C7","C8",
    "D6","D7","D8",
    "E5","E6","E7","E8",
    "F7",
    "S3","S4","S5","S6","S7",
    "R4","R5","R6","R7","R8",
    "Q6","Q7","Q8",
    "P5","P6","P7","P8",
    "O7"
]

yellow_list = ["I5","L5"]

pink_list = [
    "J10","J11","J12","J13","J14",
    "K10","K11","K12","K13","K14"
]

# Red list includes explicit cells and ranges using => notation as provided
red_list = [
    "J4","K4","J5","K5",
    "H6=>M6",
    # ranges across columns for rows 7-9
    "G7=>N7", "G8=>N8", "G9=>N9",
    # ranges for other rows
    "H15=>M15",
    "G16=>N16",
    "H17=>M17",
    "I18=>L18",
    "J19","K19",
    # note: user specified I10=>I14 and L10=>L14 as red
    "I10=>I14",
    "L10=>L14"
]

# Expand all lists into sets of cell names
green_cells = expand_list(green_list)
yellow_cells = expand_list(yellow_list)
pink_cells = expand_list(pink_list)
red_cells = expand_list(red_list)

# If any cell appears in multiple lists, priority order: red > pink > yellow > green
def cell_color(cell):
    if cell in red_cells:
        return "#e53935"   # red
    if cell in pink_cells:
        return "#ff80ab"   # pink
    if cell in yellow_cells:
        return "#fdd835"   # yellow
    if cell in green_cells:
        return "#43a047"   # green
    return "#ffffff"       # white (default)

# Build SVG content
svg_parts = []
svg_parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{SVG_WIDTH}" height="{SVG_HEIGHT}" viewBox="0 0 {SVG_WIDTH} {SVG_HEIGHT}">')
svg_parts.append(f'  <rect width="100%" height="100%" fill="#ffffff"/>')

for r in ROWS:
    for ci, col in enumerate(COLUMNS):
        cell = f"{col}{r}"
        color = cell_color(cell)
        x = ci * PIXEL
        y = (r - 1) * PIXEL
        svg_parts.append(f'  <rect x="{x}" y="{y}" width="{PIXEL}" height="{PIXEL}" fill="{color}" stroke="#cccccc" stroke-width="0.5"/>')

svg_parts.append('</svg>')

svg_content = "\n".join(svg_parts)

# Write to file
with open("grid.svg", "w", encoding="utf-8") as f:
    f.write(svg_content)

print("Wrote grid.svg (20x20). Each cell is", PIXEL, "px. Adjust PIXEL to scale.")
