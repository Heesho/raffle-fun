#!/usr/bin/env python3
"""
Pure-Python visual renderer for Slither Step 3 security diagrams (SVG, PDF, PNG).
Generates visual diagrams directly from Slither printer outputs when Graphviz `dot` CLI is unavailable.
"""
import html
import os
import re
import struct
import zlib
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# Minimal 5x7 ASCII bitmap font for PNG rasterization
FONT_5X7 = {
    ' ': [0x00,0x00,0x00,0x00,0x00,0x00,0x00],
    '!': [0x04,0x04,0x04,0x04,0x00,0x04,0x00],
    '"': [0x0A,0x0A,0x00,0x00,0x00,0x00,0x00],
    '#': [0x0A,0x1F,0x0A,0x0A,0x1F,0x0A,0x00],
    '$': [0x04,0x0F,0x14,0x0E,0x05,0x1E,0x04],
    '%': [0x18,0x19,0x02,0x04,0x08,0x13,0x03],
    '&': [0x0C,0x12,0x14,0x08,0x15,0x12,0x0D],
    "'": [0x04,0x04,0x00,0x00,0x00,0x00,0x00],
    '(': [0x02,0x04,0x08,0x08,0x08,0x04,0x02],
    ')': [0x08,0x04,0x02,0x02,0x02,0x04,0x08],
    '*': [0x00,0x04,0x15,0x0E,0x15,0x04,0x00],
    '+': [0x00,0x04,0x04,0x1F,0x04,0x04,0x00],
    ',': [0x00,0x00,0x00,0x00,0x04,0x04,0x08],
    '-': [0x00,0x00,0x00,0x1F,0x00,0x00,0x00],
    '.': [0x00,0x00,0x00,0x00,0x00,0x04,0x00],
    '/': [0x00,0x01,0x02,0x04,0x08,0x10,0x00],
    '0': [0x0E,0x11,0x13,0x15,0x19,0x11,0x0E],
    '1': [0x04,0x0C,0x04,0x04,0x04,0x04,0x0E],
    '2': [0x0E,0x11,0x01,0x02,0x04,0x08,0x1F],
    '3': [0x1F,0x02,0x04,0x02,0x01,0x11,0x0E],
    '4': [0x02,0x06,0x0A,0x12,0x1F,0x02,0x02],
    '5': [0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E],
    '6': [0x06,0x08,0x10,0x1E,0x11,0x11,0x0E],
    '7': [0x1F,0x01,0x02,0x04,0x08,0x08,0x08],
    '8': [0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E],
    '9': [0x0E,0x11,0x11,0x0F,0x01,0x02,0x0C],
    ':': [0x00,0x04,0x00,0x00,0x04,0x00,0x00],
    ';': [0x00,0x04,0x00,0x00,0x04,0x04,0x08],
    '<': [0x02,0x04,0x08,0x10,0x08,0x04,0x02],
    '=': [0x00,0x00,0x1F,0x00,0x1F,0x00,0x00],
    '>': [0x08,0x04,0x02,0x01,0x02,0x04,0x08],
    '?': [0x0E,0x11,0x01,0x02,0x04,0x00,0x04],
    '@': [0x0E,0x11,0x01,0x0D,0x15,0x15,0x0E],
    'A': [0x0E,0x11,0x11,0x11,0x1F,0x11,0x11],
    'B': [0x1E,0x11,0x11,0x1E,0x11,0x11,0x1E],
    'C': [0x0E,0x11,0x10,0x10,0x10,0x11,0x0E],
    'D': [0x1C,0x12,0x11,0x11,0x11,0x12,0x1C],
    'E': [0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F],
    'F': [0x1F,0x10,0x10,0x1E,0x10,0x10,0x10],
    'G': [0x0E,0x11,0x10,0x17,0x11,0x11,0x0F],
    'H': [0x11,0x11,0x11,0x1F,0x11,0x11,0x11],
    'I': [0x0E,0x04,0x04,0x04,0x04,0x04,0x0E],
    'J': [0x07,0x02,0x02,0x02,0x02,0x12,0x0C],
    'K': [0x11,0x12,0x14,0x18,0x14,0x12,0x11],
    'L': [0x10,0x10,0x10,0x10,0x10,0x10,0x1F],
    'M': [0x11,0x1B,0x15,0x15,0x11,0x11,0x11],
    'N': [0x11,0x11,0x19,0x15,0x13,0x11,0x11],
    'O': [0x0E,0x11,0x11,0x11,0x11,0x11,0x0E],
    'P': [0x1E,0x11,0x11,0x1E,0x10,0x10,0x10],
    'Q': [0x0E,0x11,0x11,0x11,0x15,0x12,0x0D],
    'R': [0x1E,0x11,0x11,0x1E,0x14,0x12,0x11],
    'S': [0x0F,0x10,0x10,0x0E,0x01,0x01,0x1E],
    'T': [0x1F,0x04,0x04,0x04,0x04,0x04,0x04],
    'U': [0x11,0x11,0x11,0x11,0x11,0x11,0x0E],
    'V': [0x11,0x11,0x11,0x11,0x11,0x0A,0x04],
    'W': [0x11,0x11,0x11,0x15,0x15,0x15,0x0A],
    'X': [0x11,0x11,0x0A,0x04,0x0A,0x11,0x11],
    'Y': [0x11,0x11,0x11,0x0A,0x04,0x04,0x04],
    'Z': [0x1F,0x01,0x02,0x04,0x08,0x10,0x1F],
    '[': [0x0E,0x08,0x08,0x08,0x08,0x08,0x0E],
    '\\': [0x00,0x10,0x08,0x04,0x02,0x01,0x00],
    ']': [0x0E,0x02,0x02,0x02,0x02,0x02,0x0E],
    '^': [0x04,0x0A,0x11,0x00,0x00,0x00,0x00],
    '_': [0x00,0x00,0x00,0x00,0x00,0x00,0x1F],
    '`': [0x08,0x04,0x00,0x00,0x00,0x00,0x00],
    '{': [0x02,0x04,0x04,0x08,0x04,0x04,0x02],
    '|': [0x04,0x04,0x04,0x04,0x04,0x04,0x04],
    '}': [0x08,0x04,0x04,0x02,0x04,0x04,0x08],
    '~': [0x00,0x00,0x08,0x15,0x02,0x00,0x00],
}

class Canvas:
    """Simultaneously records vector primitives (for SVG/PDF) and rasterizes onto an RGB buffer (for PNG)."""
    def __init__(self, width: int, height: int, bg=(250, 251, 253)):
        self.width = width
        self.height = height
        self.bg = bg
        self.pixels = bytearray(bg) * (width * height)
        self.svg_items = []
        self.pdf_items = []

    def set_pixel(self, x: int, y: int, color):
        if 0 <= x < self.width and 0 <= y < self.height:
            idx = (y * self.width + x) * 3
            self.pixels[idx] = color[0]
            self.pixels[idx + 1] = color[1]
            self.pixels[idx + 2] = color[2]

    def rect(self, x: int, y: int, w: int, h: int, fill=(255, 255, 255), stroke=(40, 50, 70), stroke_width=1):
        # Raster fill
        if fill is not None:
            x0, y0 = max(0, x), max(0, y)
            x1, y1 = min(self.width, x + w), min(self.height, y + h)
            row_bytes = bytes(fill) * max(0, x1 - x0)
            for py in range(y0, y1):
                start = (py * self.width + x0) * 3
                self.pixels[start:start + len(row_bytes)] = row_bytes
        # Raster stroke
        if stroke is not None and stroke_width > 0:
            for s in range(stroke_width):
                for px in range(x + s, x + w - s):
                    self.set_pixel(px, y + s, stroke)
                    self.set_pixel(px, y + h - 1 - s, stroke)
                for py in range(y + s, y + h - s):
                    self.set_pixel(x + s, py, stroke)
                    self.set_pixel(x + w - 1 - s, py, stroke)

        fill_hex = f"#{fill[0]:02x}{fill[1]:02x}{fill[2]:02x}" if fill else "none"
        stroke_hex = f"#{stroke[0]:02x}{stroke[1]:02x}{stroke[2]:02x}" if stroke else "none"
        self.svg_items.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{fill_hex}" stroke="{stroke_hex}" stroke-width="{stroke_width}"/>'
        )
        pdf_y = self.height - y - h
        cmds = []
        if fill:
            cmds.append(f"{fill[0]/255:.3f} {fill[1]/255:.3f} {fill[2]/255:.3f} rg")
        if stroke:
            cmds.append(f"{stroke[0]/255:.3f} {stroke[1]/255:.3f} {stroke[2]/255:.3f} RG {stroke_width} w")
        op = "B" if (fill and stroke) else ("f" if fill else "S")
        cmds.append(f"{x} {pdf_y} {w} {h} re {op}")
        self.pdf_items.append(" ".join(cmds))

    def line(self, x0: int, y0: int, x1: int, y1: int, color=(40, 50, 70), width=2, arrow=False):
        # Bresenham line
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        cx, cy = x0, y0
        while True:
            for ox in range(-width // 2, width // 2 + 1):
                for oy in range(-width // 2, width // 2 + 1):
                    self.set_pixel(cx + ox, cy + oy, color)
            if cx == x1 and cy == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                cx += sx
            if e2 <= dx:
                err += dx
                cy += sy

        color_hex = f"#{color[0]:02x}{color[1]:02x}{color[2]:02x}"
        marker = ' marker-end="url(#arrow)"' if arrow else ''
        self.svg_items.append(
            f'<line x1="{x0}" y1="{y0}" x2="{x1}" y2="{y1}" stroke="{color_hex}" stroke-width="{width}"{marker}/>'
        )
        py0 = self.height - y0
        py1 = self.height - y1
        self.pdf_items.append(
            f"{color[0]/255:.3f} {color[1]/255:.3f} {color[2]/255:.3f} RG {width} w {x0} {py0} m {x1} {py1} l S"
        )

    def text(self, x: int, y: int, s: str, color=(20, 25, 35), size=11, bold=False):
        # Rasterize text with 5x7 bitmap font
        cx = x
        for ch in s:
            glyph = FONT_5X7.get(ch.upper(), FONT_5X7['?'])
            for row_idx, row_bits in enumerate(glyph):
                for col_idx in range(5):
                    if (row_bits >> (4 - col_idx)) & 1:
                        self.set_pixel(cx + col_idx, y + row_idx, color)
                        if bold:
                            self.set_pixel(cx + col_idx + 1, y + row_idx, color)
            cx += 6

        color_hex = f"#{color[0]:02x}{color[1]:02x}{color[2]:02x}"
        weight = ' font-weight="bold"' if bold else ''
        esc = html.escape(s)
        self.svg_items.append(
            f'<text x="{x}" y="{y + 8}" font-family="monospace" font-size="{size}" fill="{color_hex}"{weight}>{esc}</text>'
        )
        pdf_esc = s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        pdf_y = self.height - (y + 8)
        font_name = "/F2" if bold else "/F1"
        self.pdf_items.append(
            f"BT {font_name} {size} Tf {color[0]/255:.3f} {color[1]/255:.3f} {color[2]/255:.3f} rg {x} {pdf_y} Td ({pdf_esc}) Tj ET"
        )

    def save_svg(self, path: Path):
        bg_hex = f"#{self.bg[0]:02x}{self.bg[1]:02x}{self.bg[2]:02x}"
        content = [
            f'<?xml version="1.0" encoding="UTF-8"?>',
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">',
            '<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#283246"/></marker></defs>',
            f'<rect width="100%" height="100%" fill="{bg_hex}"/>',
            *self.svg_items,
            '</svg>'
        ]
        path.write_text("\n".join(content), encoding="utf-8")

    def save_png(self, path: Path):
        raw_rows = bytearray()
        stride = self.width * 3
        for y in range(self.height):
            raw_rows.append(0)  # Filter type 0 (None)
            raw_rows.extend(self.pixels[y * stride:(y + 1) * stride])

        def chunk(chunk_type: bytes, data: bytes) -> bytes:
            crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
            return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

        ihdr = struct.pack(">IIBBBBB", self.width, self.height, 8, 2, 0, 0, 0)
        compressed = zlib.compress(bytes(raw_rows), level=6)
        png_bytes = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", compressed)
            + chunk(b"IEND", b"")
        )
        path.write_bytes(png_bytes)

    def save_pdf(self, path: Path):
        stream_data = "\n".join(self.pdf_items).encode("latin-1", errors="replace")
        objs = []
        objs.append(b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        objs.append(b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
        objs.append(
            f"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {self.width} {self.height}] "
            f"/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n".encode("ascii")
        )
        objs.append(b"4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n")
        objs.append(b"5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold >>\nendobj\n")
        objs.append(
            f"6 0 obj\n<< /Length {len(stream_data)} >>\nstream\n".encode("ascii")
            + stream_data
            + b"\nendstream\nendobj\n"
        )
        out = bytearray(b"%PDF-1.4\n")
        offsets = [0]
        for obj in objs:
            offsets.append(len(out))
            out.extend(obj)
        xref_pos = len(out)
        out.extend(f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode("ascii"))
        for off in offsets[1:]:
            out.extend(f"{off:010d} 00000 n \n".encode("ascii"))
        out.extend(
            f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n".encode("ascii")
        )
        path.write_bytes(bytes(out))


def render_inheritance_diagram():
    c = Canvas(1280, 760)
    c.rect(20, 15, 1240, 42, fill=(24, 36, 56), stroke=(24, 36, 56))
    c.text(36, 30, "SLITHER STEP 3: INHERITANCE GRAPH & C3 LINEARIZATION (raffle-fun Solidity 0.8.36)", color=(255, 255, 255), size=13, bold=True)

    # Nodes (x, y, w, h, title, lines, fill, border)
    nodes = {
        "Raffle": (460, 80, 360, 150, "Raffle (src/Raffle.sol) [Owned]", [
            "Inherits: ERC721, ReentrancyGuard,",
            "  VRFV2PlusWrapperConsumerBase, IRaffle, IERC721Receiver",
            "Overrides: name(), symbol(), _update(),",
            "  fulfillRandomWords()",
            "State Vars: 31 public + 2 private (_ticketRanges,",
            "  _requestInFlight)",
            "Zero state variable shadowing across 9 bases"
        ], (232, 244, 255), (20, 90, 160)),
        "ERC721": (40, 290, 260, 110, "ERC721 (OZ v5.1.0)", [
            "1: Context",
            "2: ERC165",
            "3: IERC721",
            "4: IERC721Metadata",
            "5: IERC721Errors"
        ], (255, 255, 255), (80, 90, 110)),
        "ReentrancyGuard": (330, 290, 250, 90, "ReentrancyGuard (OZ v5.1.0)", [
            "_status (NOT_ENTERED=1, ENTERED=2)",
            "nonReentrant modifier",
            "Note: clone starts at 0 (!= 2)"
        ], (255, 255, 255), (80, 90, 110)),
        "VRFWrapperBase": (610, 290, 310, 110, "VRFV2PlusWrapperConsumerBase", [
            "Immutable: i_vrfV2PlusWrapper",
            "Immutable: i_linkToken (via link())",
            "rawFulfillRandomWords -> fulfillRandomWords",
            "requestRandomnessPayInNative()"
        ], (255, 255, 255), (80, 90, 110)),
        "IRaffle": (950, 290, 290, 110, "IRaffle & IERC721Receiver", [
            "IRaffle (src/interfaces/IRaffle.sol)",
            "  Pure interface (Status enum, events,",
            "  errors, function signatures)",
            "IERC721Receiver (onERC721Received)"
        ], (232, 244, 255), (20, 90, 160)),
        "ERC721Bases": (40, 450, 260, 100, "Context & ERC165 -> IERC165", [
            "Context: _msgSender(), _msgData()",
            "ERC165: supportsInterface(bytes4)",
            "IERC721 / IERC721Metadata / IERC6093"
        ], (245, 247, 250), (120, 130, 145)),
        "RaffleFactory": (40, 590, 540, 135, "RaffleFactory (src/RaffleFactory.sol) [Owned]", [
            "Inherits: ReentrancyGuard (1), IRaffleFactory (2)",
            "Deploys: master Raffle implementation in constructor",
            "Clones: Clones.clone(raffleImplementation) in createRaffle()",
            "State: quoteToken, vrfWrapper, protocolTreasury, callbackGasLimit,",
            "  requestConfirmations, raffleCount, raffleById, idByRaffle, isRaffle"
        ], (232, 244, 255), (20, 90, 160)),
        "RaffleConstants": (610, 590, 630, 135, "RaffleConstants (src/libraries/RaffleConstants.sol) [Owned]", [
            "Standalone Library (no inheritance)",
            "ENTRY_PRICE = 1e6 | PROTOCOL_FEE_BPS = 100 | BPS_DENOMINATOR = 10_000",
            "MIN_SALE_DURATION = 1 hours | MAX_SALE_DURATION = 30 days",
            "DRAW_REQUEST_TIMEOUT = 2 days | DRAW_CALLBACK_TIMEOUT = 2 days",
            "MIN_CALLBACK_GAS_LIMIT = 200_000 | MAX_ENTRIES_PER_PURCHASE = 1_000",
            "MAX_REFUND_TICKET_BATCH_SIZE = 100"
        ], (235, 248, 238), (40, 120, 65)),
    }

    # Draw edges first
    edges = [
        ((540, 230), (170, 290)),
        ((600, 230), (455, 290)),
        ((680, 230), (765, 290)),
        ((740, 230), (1095, 290)),
        ((170, 400), (170, 450)),
        ((390, 590), (455, 380)),
    ]
    for (x0, y0), (x1, y1) in edges:
        c.line(x0, y0, x1, y1, color=(50, 70, 100), width=2, arrow=True)

    for key, (x, y, w, h, title, lines, fill, border) in nodes.items():
        c.rect(x, y, w, h, fill=fill, stroke=border, stroke_width=2)
        c.rect(x, y, w, 24, fill=border, stroke=border, stroke_width=1)
        c.text(x + 8, y + 7, title, color=(255, 255, 255), size=10, bold=True)
        for idx, line in enumerate(lines):
            c.text(x + 10, y + 32 + idx * 15, line, color=(25, 30, 40), size=9)

    for ext, fn in [("svg", c.save_svg), ("png", c.save_png), ("pdf", c.save_pdf)]:
        fn(BASE_DIR / f"inheritance-graph.{ext}")


def wrap_ascii_table(lines_list: list[str], max_col_width: int = 85) -> list[str]:
    """Re-formats wide Slither PrettyTable blocks by wrapping cells > max_col_width so nothing is clipped."""
    out = []
    i = 0
    while i < len(lines_list):
        line = lines_list[i]
        if line.startswith("+") and line.endswith("+") and "-" in line:
            # Collect contiguous table block
            block = []
            while i < len(lines_list) and (lines_list[i].startswith("+") or lines_list[i].startswith("|")):
                block.append(lines_list[i])
                i += 1
            # Parse rows
            parsed_rows = []
            for bl in block:
                if bl.startswith("+"):
                    parsed_rows.append(None)  # separator
                else:
                    cells = [c.strip() for c in bl.strip("|").split("|")]
                    parsed_rows.append(cells)
            # Compute column widths capped at max_col_width
            num_cols = max((len(r) for r in parsed_rows if r is not None), default=0)
            col_widths = [0] * num_cols
            for r in parsed_rows:
                if r is not None:
                    for c_idx, cell in enumerate(r):
                        col_widths[c_idx] = min(max_col_width, max(col_widths[c_idx], len(cell)))
            sep = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"
            for r in parsed_rows:
                if r is None:
                    out.append(sep)
                else:
                    wrapped_cells = []
                    max_sublines = 1
                    for c_idx, cell in enumerate(r):
                        w = max(1, col_widths[c_idx])
                        sub = [cell[j:j + w] for j in range(0, max(1, len(cell)), w)]
                        wrapped_cells.append(sub)
                        max_sublines = max(max_sublines, len(sub))
                    for s_idx in range(max_sublines):
                        row_str = "|" + "|".join(
                            " " + (wrapped_cells[c_idx][s_idx] if s_idx < len(wrapped_cells[c_idx]) else "").ljust(col_widths[c_idx]) + " "
                            for c_idx in range(len(r))
                        ) + "|"
                        out.append(row_str)
        else:
            out.append(line)
            i += 1
    return out


def render_text_table_diagram(title: str, lines_list: list[str], basename: str):
    wrapped = wrap_ascii_table(lines_list, max_col_width=85)
    max_len = max((len(l) for l in wrapped), default=120)
    height = max(720, 80 + len(wrapped) * 13)
    width = max(1480, 60 + max_len * 6)
    c = Canvas(width, height)
    c.rect(16, 12, width - 32, 38, fill=(24, 36, 56), stroke=(24, 36, 56))
    c.text(28, 25, title, color=(255, 255, 255), size=12, bold=True)
    c.rect(16, 56, width - 32, height - 70, fill=(255, 255, 255), stroke=(120, 130, 145), stroke_width=1)
    for idx, line in enumerate(wrapped):
        is_hdr = line.startswith("Contract ") or line.startswith("+---") or line.startswith("| Function ")
        color = (15, 65, 130) if is_hdr else (25, 30, 40)
        c.text(26, 66 + idx * 13, line, color=color, size=9, bold=is_hdr)

    for ext, fn in [("svg", c.save_svg), ("png", c.save_png), ("pdf", c.save_pdf)]:
        fn(BASE_DIR / f"{basename}.{ext}")


def main():
    render_inheritance_diagram()

    fn_lines = (BASE_DIR / "owned-function-summary.txt").read_text(encoding="utf-8").splitlines()
    # Keep owned contracts summary lines (skip blank padding)
    fn_compact = [l for l in fn_lines if l.strip()]
    render_text_table_diagram(
        "SLITHER STEP 3: FUNCTION SUMMARY (Raffle, RaffleFactory, IRaffle, IRaffleFactory, RaffleConstants)",
        fn_compact,
        "function-summary",
    )

    va_lines = (BASE_DIR / "owned-vars-and-auth.txt").read_text(encoding="utf-8").splitlines()
    va_compact = [l for l in va_lines if l.strip()]
    render_text_table_diagram(
        "SLITHER STEP 3: VARIABLES AND AUTHORIZATION (State Variable Writers & Access Controls)",
        va_compact,
        "vars-and-auth",
    )
    print("Generated SVG, PNG, and PDF diagrams in", BASE_DIR)


if __name__ == "__main__":
    main()
