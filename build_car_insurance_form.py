#!/usr/bin/env python3
"""Build a fillable single-page A4 PDF for the car insurance information request."""

from __future__ import annotations

from pathlib import Path

import fitz
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas

PAGE_W, PAGE_H = A4
MARGIN_L = 18 * mm
MARGIN_R = 18 * mm
MARGIN_T = 16 * mm
MARGIN_B = 16 * mm
CONTENT_W = PAGE_W - MARGIN_L - MARGIN_R
COL_GAP = 8 * mm
HALF_W = (CONTENT_W - COL_GAP) / 2
COL2_X = MARGIN_L + HALF_W + COL_GAP

FONT = "Helvetica"
FONT_BOLD = "Helvetica-Bold"
BODY = 9.5
SMALL = 8
TITLE = 12
LEADING = 11
LABEL_LEAD = 11

FIELD_H = 6.5 * mm
FIELD_GAP = 2.5 * mm
ROW_GAP = 7.5 * mm
AFTER_LABEL = 3 * mm
SUB_LABEL_H = 9
AFTER_SUB_LABEL = 2.5 * mm

DATE_W = 12 * mm
DATE_GAP = 2.5 * mm


def wrap_text(text: str, width: float, font: str, size: float) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        trial = " ".join(current + [word]) if current else word
        if pdfmetrics.stringWidth(trial, font, size) <= width:
            current.append(word)
        else:
            if current:
                lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return lines or [""]


class FormBuilder:
    def __init__(self, output_path: Path) -> None:
        self.output_path = output_path
        self.c = canvas.Canvas(str(output_path), pagesize=A4)
        self.c.setTitle("Car Insurance Information Form")
        self.c.setAuthor("Generated fillable form")
        self.form = self.c.acroForm
        self.y = PAGE_H - MARGIN_T
        self._field_index = 0

    def _uniq(self, base: str) -> str:
        self._field_index += 1
        return f"{base}_{self._field_index}"

    def _draw_label_lines(self, text: str, x: float, y: float, *, width: float) -> float:
        """Draw a label block; return y below it."""
        self.c.setFont(FONT_BOLD, BODY)
        for line in wrap_text(text, width, FONT_BOLD, BODY):
            self.c.drawString(x, y, line)
            y -= LABEL_LEAD
        return y - AFTER_LABEL

    def _field(
        self,
        name: str,
        x: float,
        bottom_y: float,
        width: float,
        *,
        maxlen: int | None = None,
        comb: bool = False,
        tooltip: str = "",
    ) -> float:
        flags: list[str] = []
        if comb:
            if maxlen is None:
                raise ValueError(f"comb fields require maxlen (field: {name})")
            flags.append("comb")
        self.form.textfield(
            name=self._uniq(name),
            tooltip=tooltip or name,
            x=x,
            y=bottom_y,
            width=width,
            height=FIELD_H,
            borderStyle="underlined",
            borderColor=colors.HexColor("#333333"),
            fillColor=colors.HexColor("#F7FAFF"),
            textColor=colors.black,
            maxlen=maxlen if maxlen is not None else 100,
            fieldFlags=" ".join(flags),
        )
        return bottom_y - FIELD_H - FIELD_GAP

    def _choice(
        self, name: str, x: float, bottom_y: float, width: float, options: list[str], tooltip: str
    ) -> float:
        self.form.choice(
            name=self._uniq(name),
            tooltip=tooltip,
            value=options[0],
            options=options,
            x=x,
            y=bottom_y,
            width=width,
            height=FIELD_H,
            borderStyle="underlined",
            borderColor=colors.HexColor("#333333"),
            fillColor=colors.HexColor("#F7FAFF"),
            textColor=colors.black,
        )
        return bottom_y - FIELD_H - FIELD_GAP

    def _date_block(self, x: float, top_y: float, width: float, prefix: str, label: str, tooltip: str) -> float:
        y = self._draw_label_lines(label, x, top_y, width=width)

        lx = x
        for lbl in ("Day", "Month", "Year"):
            self.c.setFont(FONT, SMALL)
            self.c.drawString(lx, y, lbl)
            lx += DATE_W + DATE_GAP
        y -= SUB_LABEL_H + AFTER_SUB_LABEL

        fx = x
        bottom = y - FIELD_H
        for part, w, maxlen in (("day", DATE_W, 2), ("month", DATE_W, 2), ("year", DATE_W + 8 * mm, 4)):
            self._field(
                f"{prefix}_{part}",
                fx,
                bottom,
                w,
                maxlen=maxlen,
                comb=True,
                tooltip=f"{tooltip} — {part}",
            )
            fx += w + DATE_GAP
        return bottom - FIELD_GAP

    def _single_block(
        self,
        x: float,
        top_y: float,
        width: float,
        label: str,
        name: str,
        *,
        field_w: float | None = None,
        **field_kw,
    ) -> float:
        y = self._draw_label_lines(label, x, top_y, width=width)
        bottom = y - FIELD_H
        self._field(name, x, bottom, field_w or min(width, 30 * mm), **field_kw)
        return bottom - FIELD_GAP

    def _pair_row(self, left_fn, right_fn) -> None:
        row_top = self.y
        left_bottom = left_fn(MARGIN_L, row_top, HALF_W)
        right_bottom = right_fn(COL2_X, row_top, HALF_W)
        self.y = min(left_bottom, right_bottom) - ROW_GAP

    def build(self) -> None:
        c = self.c
        c.setFont(FONT_BOLD, TITLE)
        c.drawString(MARGIN_L, self.y, "Car Insurance — Information Request")
        self.y -= LEADING + 3
        c.setFont(FONT, BODY)
        intro = "Dear Client, please complete the fields below for your preliminary car insurance quotation."
        for line in wrap_text(intro, CONTENT_W, FONT, BODY):
            c.drawString(MARGIN_L, self.y, line)
            self.y -= LEADING
        self.y -= ROW_GAP

        self.y = self._draw_label_lines(
            "Your full address in Hungary (postcode, city, street, house no., floor, apt.)",
            MARGIN_L,
            self.y,
            width=CONTENT_W,
        )
        bottom = self.y - FIELD_H
        self._field("address_line_1", MARGIN_L, bottom, CONTENT_W, tooltip="Address line 1")
        self.y = bottom - FIELD_H - FIELD_GAP
        bottom = self.y - FIELD_H
        self._field("address_line_2", MARGIN_L, bottom, CONTENT_W, tooltip="Address line 2")
        self.y = bottom - FIELD_GAP - ROW_GAP

        self._pair_row(
            lambda x, y, w: self._date_block(x, y, w, "dob", "Date of birth", "Date of birth"),
            lambda x, y, w: self._date_block(x, y, w, "licence", "Driving licence date", "Driving licence date"),
        )
        self._pair_row(
            lambda x, y, w: self._single_block(
                x, y, w, "Vehicle year of manufacture", "vehicle_year",
                field_w=20 * mm, maxlen=4, comb=True, tooltip="Year of manufacture",
            ),
            lambda x, y, w: self._date_block(x, y, w, "purchase", "Vehicle purchase date", "Purchase date"),
        )
        self._pair_row(
            lambda x, y, w: self._date_block(x, y, w, "register_hu", "Register vehicle in Hungary", "Registration date"),
            lambda x, y, w: self._date_block(x, y, w, "inspection", "Last technical inspection", "Inspection date"),
        )
        self._pair_row(
            lambda x, y, w: self._single_block(
                x, y, w, "Current odometer (km)", "odometer_km", field_w=28 * mm, maxlen=7, tooltip="Odometer km",
            ),
            lambda x, y, w: self._single_block(
                x, y, w, "Annual mileage in Hungary (km)", "mileage_hu_km", field_w=28 * mm, maxlen=7, tooltip="Annual km in Hungary",
            ),
        )
        self._pair_row(
            lambda x, y, w: self._single_block(
                x, y, w, "Annual mileage outside Hungary (km)", "mileage_abroad_km", field_w=28 * mm, maxlen=7, tooltip="Annual km abroad",
            ),
            lambda x, y, w: self._single_block(
                x, y, w, "Number of drivers", "driver_count", field_w=14 * mm, maxlen=2, comb=True, tooltip="Number of drivers",
            ),
        )
        self._pair_row(
            lambda x, y, w: self._single_block(x, y, w, "Number of seats", "seats", field_w=16 * mm, maxlen=4, tooltip="Seats"),
            lambda x, y, w: self._single_block(x, y, w, "Number of doors", "doors", field_w=16 * mm, maxlen=4, tooltip="Doors"),
        )

        row_top = self.y
        y = self._draw_label_lines("Birth year — youngest / oldest driver", MARGIN_L, row_top, width=CONTENT_W)
        self.c.setFont(FONT, SMALL)
        self.c.drawString(MARGIN_L, y, "Youngest")
        self.c.drawString(COL2_X, y, "Oldest")
        y -= SUB_LABEL_H + AFTER_SUB_LABEL
        bottom = y - FIELD_H
        self._field("youngest_driver_year", MARGIN_L, bottom, 20 * mm, maxlen=4, comb=True, tooltip="Youngest birth year")
        self._field("oldest_driver_year", COL2_X, bottom, 20 * mm, maxlen=4, comb=True, tooltip="Oldest birth year")
        self.y = bottom - FIELD_GAP - ROW_GAP

        row_top = self.y
        left_y = self._draw_label_lines("Premium payment frequency", MARGIN_L, row_top, width=HALF_W)
        right_y = self._draw_label_lines("Steering wheel position", COL2_X, row_top, width=HALF_W)
        bottom = min(left_y, right_y) - FIELD_H
        self._choice("payment_frequency", MARGIN_L, bottom, HALF_W - 2 * mm, ["Annual", "Semi-annual"], "Payment frequency")
        self._choice("steering_wheel", COL2_X, bottom, HALF_W - 2 * mm, ["Left-hand drive", "Right-hand drive"], "Steering wheel")
        self.y = bottom - FIELD_GAP

        if self.y < MARGIN_B:
            raise RuntimeError(f"Form overflows single page (y={self.y:.1f}, margin={MARGIN_B:.1f})")

        self.c.save()


def add_numeric_validation(pdf_path: Path) -> None:
    """Reject non-digits in numeric fields (supported in Acrobat and some readers)."""
    numeric_js = (
        "var ok=/^[0-9]*$/;"
        "if(event.change&&!ok.test(event.change)){event.rc=false;}"
    )
    numeric_markers = (
        "_day",
        "_month",
        "_year",
        "vehicle_year",
        "odometer",
        "mileage",
        "driver_count",
        "driver_year",
    )
    doc = fitz.open(pdf_path)
    for page in doc:
        widget = page.first_widget
        while widget:
            name = (widget.field_name or "").lower()
            if any(marker in name for marker in numeric_markers):
                widget.script_stroke = numeric_js
                widget.update()
            widget = widget.next
    doc.saveIncr()
    doc.close()


def main() -> None:
    dropbox_dir = Path(
        "/Users/DuniaMBP/Library/CloudStorage/Dropbox/Financial/Hungary 🇭🇺"
    )
    project_dir = Path(__file__).resolve().parent
    out_name = "Form_Car_Insurance_fillable.pdf"

    for out in (dropbox_dir / out_name, project_dir / out_name):
        FormBuilder(out).build()
        add_numeric_validation(out)
        print(f"Wrote {out}")


if __name__ == "__main__":
    main()
