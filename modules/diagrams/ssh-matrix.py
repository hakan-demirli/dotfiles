#!/usr/bin/env python3

from __future__ import annotations

import json
import sys

import svgwrite

CELL_W = 1.4
CELL_H = 1.0
HEADER_ROW_H = 4.0     
ROW_HEADER_W = 4.5     
GROUP_GAP = 0.4        
PAD = 0.6
TITLE_H = 1.4

FLEET_PALETTE = [
    ("#dbeafe", "#1d4ed8"),
    ("#dcfce7", "#15803d"),
    ("#ffedd5", "#c2410c"),
    ("#ede9fe", "#6d28d9"),
    ("#fef9c3", "#a16207"),
    ("#fce7f3", "#be185d"),
    ("#d1fae5", "#047857"),
    ("#ffe4e6", "#be123c"),
    ("#e0f2fe", "#075985"),
    ("#fef3c7", "#92400e"),
]
SOLO_COLOR = ("#f1f5f9", "#64748b")

ROOT_FILL = "#dc2626"
ACCOUNT_FILL = "#1d4ed8"
TRUST_FILL = "#a16207"
VIOLATION_DOT = "#dc2626"


def main() -> None:
    facts = json.load(sys.stdin)
    hosts = facts["hosts"]
    clusters = facts["clusters"]
    users = facts["users"]
    hosts_by_cluster = facts["hostsByCluster"]
    ssh_grants = facts.get("sshGrants", [])
    violations = facts.get("intentViolations", [])

    live_cids = [
        cid for cid, c in clusters.items()
        if c.get("state") != "retired"
    ]
    multi_cids = sorted(
        [cid for cid in live_cids if len(hosts_by_cluster.get(cid, [])) > 1],
        key=lambda cid: (-len(hosts_by_cluster[cid]), cid),
    )
    solo_cids = sorted(
        [cid for cid in live_cids if len(hosts_by_cluster.get(cid, [])) <= 1]
    )

    color_of_cluster: dict[str, tuple[str, str]] = {}
    for i, cid in enumerate(multi_cids):
        color_of_cluster[cid] = FLEET_PALETTE[i % len(FLEET_PALETTE)]
    for cid in solo_cids:
        color_of_cluster[cid] = SOLO_COLOR

    columns: list[tuple[str, str]] = []
    for cid in multi_cids:
        for hid in sorted(hosts_by_cluster.get(cid, [])):
            columns.append((hid, cid))
    for cid in solo_cids:
        for hid in sorted(hosts_by_cluster.get(cid, [])):
            columns.append((hid, cid))

    groups: list[tuple[str, int, int]] = []
    if columns:
        start = 0
        cur_cid = columns[0][1]
        for i, (_, cid) in enumerate(columns):
            if cid != cur_cid:
                groups.append((cur_cid, start, i - start))
                cur_cid = cid
                start = i
        groups.append((cur_cid, start, len(columns) - start))

    rows: list[str] = sorted(
        [
            uid for uid, u in users.items()
            if u.get("username") and not u.get("archived", False)
        ]
    )

    cells: dict[tuple[str, str], dict] = {}
    for g in ssh_grants:
        if g.get("archived"):
            continue
        if not g.get("account"):
            continue
        key = (g["user"], g["host"])
        c = cells.setdefault(key, {"accounts": set(), "tiers": set(), "sources": set()})
        c["accounts"].add(g["account"])
        c["tiers"].add(g.get("tier"))
        c["sources"].add(g.get("source"))

    viol_by_cell: dict[tuple[str, str], list[dict]] = {}
    for v in violations:
        if v.get("user") and v.get("host"):
            viol_by_cell.setdefault((v["user"], v["host"]), []).append(v)

    cols_n = len(columns)
    if cols_n == 0 or len(rows) == 0:
        dwg = svgwrite.Drawing(size=("100%", "100%"), viewBox="0 0 20 6",
                               preserveAspectRatio="xMidYMid meet")
        dwg.add(dwg.rect(insert=(0, 0), size=(20, 6), fill="#ffffff"))
        dwg.add(dwg.text("no SSH grants in inventory",
                         insert=(10, 3), text_anchor="middle",
                         font_family="Helvetica, Arial, sans-serif",
                         font_size=0.9, fill="#374151"))
        sys.stdout.write(dwg.tostring())
        return

    col_x: list[float] = []
    x = ROW_HEADER_W
    prev_cid: str | None = None
    for (hid, cid) in columns:
        if prev_cid is not None and cid != prev_cid:
            x += GROUP_GAP
        col_x.append(x)
        x += CELL_W
        prev_cid = cid
    canvas_w = x + PAD + 6.0  
    canvas_h = TITLE_H + HEADER_ROW_H + len(rows) * CELL_H + PAD * 2 + 3.5  

    dwg = svgwrite.Drawing(
        size=("100%", "100%"),
        viewBox=f"0 0 {canvas_w:.4f} {canvas_h:.4f}",
        preserveAspectRatio="xMidYMid meet",
    )
    dwg.add(dwg.rect(insert=(0, 0), size=(canvas_w, canvas_h), fill="#ffffff"))

    dwg.add(
        dwg.text(
            "SSH access matrix  ·  users × hosts",
            insert=(PAD, TITLE_H - 0.4),
            font_family="Helvetica, Arial, sans-serif",
            font_size=0.8, font_weight="bold", fill="#1f2937",
        )
    )

    header_y0 = TITLE_H
    grid_y0 = header_y0 + HEADER_ROW_H

    for cid, start, count in groups:
        fill, border = color_of_cluster[cid]
        x0 = col_x[start]
        end_col_x = col_x[start + count - 1]
        w = end_col_x + CELL_W - x0
        dwg.add(
            dwg.rect(
                insert=(x0, header_y0),
                size=(w, 0.65),
                rx=0.12, ry=0.12,
                fill=fill, stroke=border, stroke_width=0.06,
            )
        )
        dwg.add(
            dwg.text(
                cid + f"  ({count})",
                insert=(x0 + 0.25, header_y0 + 0.45),
                font_family="Helvetica, Arial, sans-serif",
                font_size=0.36, font_weight="bold", fill=border,
            )
        )

    for i, (hid, cid) in enumerate(columns):
        fill, border = color_of_cluster[cid]
        dwg.add(
            dwg.rect(
                insert=(col_x[i], header_y0 + 0.75),
                size=(CELL_W, 0.10),
                fill=border,
            )
        )
        anchor_x = col_x[i] + CELL_W / 2
        anchor_y = header_y0 + HEADER_ROW_H - 0.3
        txt = dwg.text(
            hid,
            insert=(anchor_x, anchor_y),
            font_family="Helvetica, Arial, sans-serif",
            font_size=0.42, font_weight="bold", fill="#1f2937",
            text_anchor="start",
            transform=f"rotate(-55 {anchor_x:.3f} {anchor_y:.3f})",
        )
        dwg.add(txt)

    for ri, uid in enumerate(rows):
        row_y = grid_y0 + ri * CELL_H
        if ri % 2 == 0:
            dwg.add(
                dwg.rect(
                    insert=(0, row_y),
                    size=(canvas_w - 6.0, CELL_H),
                    fill="#f8fafc",
                )
            )

        u = users[uid]
        username = u.get("username") or uid
        cohort = u.get("cohort", "")
        is_admin = "admin" if False else ""  
        dwg.add(
            dwg.text(
                uid,
                insert=(PAD, row_y + 0.55),
                font_family="Helvetica, Arial, sans-serif",
                font_size=0.42, font_weight="bold", fill="#1f2937",
            )
        )
        dwg.add(
            dwg.text(
                f"{username} ({cohort})",
                insert=(PAD, row_y + 0.90),
                font_family="Helvetica, Arial, sans-serif",
                font_size=0.30, fill="#475569",
            )
        )

        for ci, (hid, cid) in enumerate(columns):
            cell_x = col_x[ci]
            cell_data = cells.get((uid, hid))
            fill, border = color_of_cluster[cid]

            dwg.add(
                dwg.rect(
                    insert=(cell_x, row_y),
                    size=(CELL_W, CELL_H),
                    fill="#ffffff",
                    stroke="#e2e8f0",
                    stroke_width=0.02,
                )
            )
            if not cell_data:
                continue

            has_root = "root" in cell_data["accounts"] or "is_root_anywhere" in cell_data["sources"]
            has_trust = "ssh_trust" in cell_data["sources"]
            has_regular = bool({a for a in cell_data["accounts"] if a != "root"})

            inner_pad = 0.12
            inner_w = CELL_W - 2 * inner_pad
            inner_h = CELL_H - 2 * inner_pad

            if has_root:
                dwg.add(
                    dwg.rect(
                        insert=(cell_x + inner_pad, row_y + inner_pad),
                        size=(inner_w, inner_h),
                        rx=0.10, ry=0.10,
                        fill=ROOT_FILL,
                    )
                )
                dwg.add(
                    dwg.text(
                        "R",
                        insert=(cell_x + CELL_W / 2, row_y + CELL_H / 2 + 0.2),
                        text_anchor="middle",
                        font_family="Helvetica, Arial, sans-serif",
                        font_size=0.62, font_weight="bold", fill="#ffffff",
                    )
                )
            elif has_regular:
                dwg.add(
                    dwg.rect(
                        insert=(cell_x + inner_pad, row_y + inner_pad),
                        size=(inner_w, inner_h),
                        rx=0.10, ry=0.10,
                        fill=fill, stroke=border, stroke_width=0.08,
                    )
                )
                tier = next(iter(cell_data["tiers"]), "?") or "?"
                glyph = "A" if tier else "A"
                dwg.add(
                    dwg.text(
                        glyph,
                        insert=(cell_x + CELL_W / 2, row_y + CELL_H / 2 + 0.18),
                        text_anchor="middle",
                        font_family="Helvetica, Arial, sans-serif",
                        font_size=0.50, font_weight="bold", fill=border,
                    )
                )
                if tier:
                    dwg.add(
                        dwg.text(
                            str(tier)[:6],
                            insert=(cell_x + CELL_W / 2, row_y + CELL_H - 0.10),
                            text_anchor="middle",
                            font_family="Helvetica, Arial, sans-serif",
                            font_size=0.22, fill="#1f2937",
                        )
                    )
            elif has_trust:
                dwg.add(
                    dwg.rect(
                        insert=(cell_x + inner_pad, row_y + inner_pad),
                        size=(inner_w, inner_h),
                        rx=0.10, ry=0.10,
                        fill="#ffffff",
                        stroke=TRUST_FILL, stroke_width=0.10,
                    )
                )
                dwg.add(
                    dwg.text(
                        "T",
                        insert=(cell_x + CELL_W / 2, row_y + CELL_H / 2 + 0.18),
                        text_anchor="middle",
                        font_family="Helvetica, Arial, sans-serif",
                        font_size=0.50, font_weight="bold", fill=TRUST_FILL,
                    )
                )

            if (uid, hid) in viol_by_cell:
                dwg.add(
                    dwg.circle(
                        center=(cell_x + CELL_W - 0.20, row_y + 0.20),
                        r=0.16,
                        fill=VIOLATION_DOT,
                        stroke="#ffffff",
                        stroke_width=0.04,
                    )
                )

    legend_x = canvas_w - 6.0 + 0.2
    legend_y = grid_y0 + 0.3
    LEGEND_W = 5.5
    LEGEND_H = canvas_h - legend_y - 0.6
    dwg.add(
        dwg.rect(
            insert=(legend_x, legend_y), size=(LEGEND_W, LEGEND_H),
            rx=0.3, ry=0.3, fill="#ffffff",
            stroke="#94a3b8", stroke_width=0.06,
        )
    )
    dwg.add(
        dwg.text(
            "Legend",
            insert=(legend_x + 0.3, legend_y + 0.6),
            font_family="Helvetica, Arial, sans-serif",
            font_size=0.42, font_weight="bold", fill="#1f2937",
        )
    )
    sample_x = legend_x + 0.3
    sample_y = legend_y + 1.1
    dwg.add(dwg.rect(insert=(sample_x, sample_y), size=(0.7, 0.7),
                     rx=0.10, ry=0.10, fill=ROOT_FILL))
    dwg.add(dwg.text("R", insert=(sample_x + 0.35, sample_y + 0.55),
                     text_anchor="middle",
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.45, font_weight="bold", fill="#ffffff"))
    dwg.add(dwg.text("root account",
                     insert=(sample_x + 1.0, sample_y + 0.45),
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.30, fill="#1f2937"))
    sample_y += 1.0
    dwg.add(dwg.rect(insert=(sample_x, sample_y), size=(0.7, 0.7),
                     rx=0.10, ry=0.10, fill="#dbeafe",
                     stroke="#1d4ed8", stroke_width=0.08))
    dwg.add(dwg.text("A", insert=(sample_x + 0.35, sample_y + 0.55),
                     text_anchor="middle",
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.45, font_weight="bold", fill="#1d4ed8"))
    dwg.add(dwg.text("user account (cluster grant)",
                     insert=(sample_x + 1.0, sample_y + 0.45),
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.30, fill="#1f2937"))
    sample_y += 1.0
    dwg.add(dwg.rect(insert=(sample_x, sample_y), size=(0.7, 0.7),
                     rx=0.10, ry=0.10, fill="#ffffff",
                     stroke=TRUST_FILL, stroke_width=0.10))
    dwg.add(dwg.text("T", insert=(sample_x + 0.35, sample_y + 0.55),
                     text_anchor="middle",
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.45, font_weight="bold", fill=TRUST_FILL))
    dwg.add(dwg.text("ssh_trust overlay",
                     insert=(sample_x + 1.0, sample_y + 0.45),
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.30, fill="#1f2937"))
    sample_y += 1.0
    dwg.add(dwg.circle(center=(sample_x + 0.35, sample_y + 0.35),
                       r=0.18, fill=VIOLATION_DOT,
                       stroke="#ffffff", stroke_width=0.04))
    dwg.add(dwg.text("headscale intent violation",
                     insert=(sample_x + 1.0, sample_y + 0.45),
                     font_family="Helvetica, Arial, sans-serif",
                     font_size=0.30, fill="#1f2937"))

    sys.stdout.write(dwg.tostring())


if __name__ == "__main__":
    main()
