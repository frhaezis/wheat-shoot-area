"""End-to-end checks using ImageJ itself, not a reimplementation of HSB.

Requires Python 3.10+, Pillow, NumPy, Java and an official ImageJ ij.jar.
Usage: python tests/check_macro.py --ij-jar /absolute/path/to/ij.jar
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def make_example() -> dict:
    folder = ROOT / "examples"
    (folder / "input").mkdir(exist_ok=True)
    (folder / "annotations").mkdir(exist_ok=True)
    image = Image.new("RGB", (600, 360), (70, 65, 60))
    draw = ImageDraw.Draw(image)
    areas = []
    # Half-open rectangles: widths 20, 25, 30, 35, 40; height 80.
    for index, center in enumerate((100, 200, 300, 400, 500)):
        width = 20 + 5 * index
        left = center - width // 2
        color = (150, 182, 128) if index == 0 else (60, 160, 40)
        draw.rectangle((left, 80, left + width - 1, 159), fill=color)
        areas.append(width * 80)
    # Foreground outside the analyzed strips (below the shared y=240 cutoff).
    draw.rectangle((10, 300, 19, 309), fill=(60, 160, 40))
    # Colored distractors and a 60 px reference, none passing the segmentation gate.
    draw.rectangle((40, 180, 59, 199), fill=(180, 30, 30))
    draw.rectangle((540, 180, 559, 199), fill=(30, 30, 180))
    draw.rectangle((270, 270, 329, 279), fill=(245, 245, 245))
    image.save(folder / "input" / "synthetic.png")
    (folder / "annotations" / "synthetic.png.annotations.txt").write_text(
        "status=accepted\nscale_x1=270\nscale_y1=270\nscale_x2=330\nscale_y2=270\n"
        "points_x=500,100,400,200,300\npoints_y=240,240,240,240,240\n",
        encoding="utf-8",
    )
    expected = {"pot_px": areas, "analyzed_px": sum(areas),
                "frame_px": sum(areas) + 100, "scale_cm_per_px": 0.1}
    (folder / "expected.json").write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    return expected


def invoke(java: str, jar: Path, config: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [java, "-Djava.awt.headless=false", "-Xmx512m", "-cp", str(jar),
         str(ROOT / "tests" / "MacroCheck.java"), str(ROOT / "WSA.ijm"), str(config)],
        capture_output=True, text=True, timeout=90,
    )


def run_macro(java: str, jar: Path, parent: Path, inputs: Path, annotations: Path,
              **settings) -> tuple[Path, list[dict]]:
    parent.mkdir(exist_ok=True, parents=True)
    config = parent / "test.properties"
    params = {"input": inputs.resolve().as_posix(), "output": parent.resolve().as_posix(),
              "annotations": annotations.resolve().as_posix(), **settings}
    config.write_text("".join(f"{key}={value}\n" for key, value in params.items()), encoding="utf-8")
    before = set(parent.glob("WSA_*"))
    process = invoke(java, jar, config)
    if process.returncode:
        raise AssertionError(process.stdout + process.stderr)
    created = set(parent.glob("WSA_*")) - before
    assert len(created) == 1, (process.stdout, process.stderr, created)
    result = created.pop()
    assert (result / "status.txt").read_text().startswith("complete\n"), (process.stdout, process.stderr)
    delimiter = {"TSV": "\t", "CSV": ",", "Semicolon": ";"}[settings.get("table_format", "TSV")]
    suffix = ".tsv" if delimiter == "\t" else ".csv"
    with (result / f"results{suffix}").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream, delimiter=delimiter))
    return result, rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ij-jar", required=True, type=Path)
    parser.add_argument("--java", default="java")
    args = parser.parse_args()
    expected = make_example()
    source = ROOT / "examples" / "input"
    annotations = ROOT / "examples" / "annotations"
    source_hash = hashlib.sha256((source / "synthetic.png").read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="wsa-check-") as tmp:
        temp = Path(tmp)
        result, rows = run_macro(args.java, args.ij_jar, temp / "runs", source, annotations)
        assert len(rows) == 1
        row = rows[0]
        assert row["Status"] == "accepted", row
        assert float(row["FrameLeaf_px"]) == expected["frame_px"], row
        assert float(row["AnalyzedLeaf_px"]) == expected["analyzed_px"], row
        for index, area in enumerate(expected["pot_px"], 1):
            assert float(row[f"Pot{index}_px"]) == area
            assert abs(float(row[f"Pot{index}_cm2"]) - area * 0.01) < 1e-6
        counts = np.array(expected["pot_px"])
        assert abs(float(row["SD_px"]) - counts.std(ddof=1)) < 1e-6
        assert abs(float(row["SEM_px"]) - counts.std(ddof=1) / np.sqrt(5)) < 1e-6
        # A stricter configurable saturation floor excludes the pale fixture.
        _, strict = run_macro(args.java, args.ij_jar, temp / "strict", source, annotations,
                               saturation_min=100)
        assert float(strict[0]["Pot1_px"]) == 0
        assert float(strict[0]["FrameLeaf_px"]) == expected["frame_px"] - expected["pot_px"][0]
        mask = np.array(Image.open(result / "masks" / "synthetic.png_mask.tif"))
        assert mask.shape == (360, 600)
        assert set(np.unique(mask)) == {0, 255}
        assert int((mask == 255).sum()) == expected["frame_px"]
        assert Image.open(result / "qc" / "synthetic.png_QC.png").size == (600, 360)
        # Keep the actual ImageJ output as the published synthetic walkthrough.
        example_output = ROOT / "examples" / "output"
        example_output.mkdir(exist_ok=True)
        for src, dst in [(result / "masks" / "synthetic.png_mask.tif", "synthetic_mask.tif"),
                         (result / "qc" / "synthetic.png_QC.png", "synthetic_QC.png"),
                         (result / "results.tsv", "results.tsv")]:
            (example_output / dst).write_bytes(src.read_bytes())
        Image.fromarray(mask).save(example_output / "synthetic_mask.png")
        panel = Image.new("RGB", (1200, 720), "white")
        panel.paste(Image.open(source / "synthetic.png"), (0, 0))
        panel.paste(Image.fromarray(mask).convert("RGB"), (600, 0))
        panel.paste(Image.open(result / "qc" / "synthetic.png_QC.png"), (0, 360))
        draw = ImageDraw.Draw(panel)
        draw.text((620, 390), "SYNTHETIC EXAMPLE (not a camera photograph)\n\n"
                  "Per-pot leaf area: 16, 20, 24, 28, 32 cm2\n"
                  "Analyzed leaf area: 120 cm2\n"
                  "Full-frame leaf area: 121 cm2\n\n"
                  "Yellow: pot-strip boundaries\nCyan: 6 cm reference line\n"
                  "Foreground patch below the cutoff is excluded from pot areas.", fill="black",
                  font=ImageFont.load_default(size=17), spacing=6)
        panel.save(ROOT / "examples" / "synthetic_walkthrough.png")
        # Replay saved annotations/settings, and verify outputs do not overwrite.
        second, repeated = run_macro(args.java, args.ij_jar, temp / "runs", source,
                                     result / "annotations")
        assert second != result and repeated == rows
        # Same basename, quoted delimiter in filename, unsupported grayscale, zero foreground.
        cases = temp / "cases"; cases.mkdir()
        marks = temp / "marks"; marks.mkdir()
        annotation = (annotations / "synthetic.png.annotations.txt").read_text()
        for name in ("same.png", "same.bmp", "comma,name.png", "zero.png", "gray.png"):
            image = Image.open(source / "synthetic.png")
            if name == "zero.png": image = Image.new("RGB", image.size, (70, 65, 60))
            if name == "gray.png": image = image.convert("L")
            image.save(cases / name)
            (marks / f"{name}.annotations.txt").write_text(annotation)
        multi, multi_rows = run_macro(args.java, args.ij_jar, temp / "multi", cases, marks, table_format="CSV")
        by_name = {r["Image"]: r for r in multi_rows}
        assert len(by_name) == 5
        assert all(None not in r and None not in r.values() for r in multi_rows)
        assert by_name["gray.png"]["Status"] == "unsupported_rgb_or_stack"
        assert by_name["zero.png"]["AnalyzedLeaf_px"] == "0"
        assert len(list((multi / "masks").glob("same*"))) == 2
        assert float(by_name["comma,name.png"]["FrameLeaf_px"]) == expected["frame_px"]
        # N=1 must report undefined sample SD/SEM; missing/duplicate points must skip.
        (marks / "synthetic.png.annotations.txt").write_text(annotation.replace(
            "points_x=500,100,400,200,300\npoints_y=240,240,240,240,240", "points_x=300\npoints_y=240"))
        _, one = run_macro(args.java, args.ij_jar, temp / "one", source, marks,
                           pots=1, table_format="Semicolon", decimal_comma=1, save_qc=0)
        assert one[0]["SD_px"] == "NaN" and one[0]["SEM_px"] == "NaN"
        assert "," in one[0]["Scale_cm_per_px"]
        (marks / "synthetic.png.annotations.txt").write_text(annotation.replace("500,100,400,200,300", "100,100,400,200,300"))
        _, invalid = run_macro(args.java, args.ij_jar, temp / "invalid", source, marks)
        assert invalid[0]["Status"] == "skipped_points"
        assert invalid[0]["AnalyzedLeaf_px"] == "NaN"
        assert float(invalid[0]["FrameLeaf_cm2"]) == 121
        # Inclusive extreme thresholds must admit every pixel, including zero-valued HSB.
        _, all_pixels = run_macro(args.java, args.ij_jar, temp / "all", source, annotations,
                                   hue_min=0, hue_max=255, saturation_min=0,
                                   saturation_max=255, brightness_min=0, brightness_max=255)
        assert float(all_pixels[0]["FrameLeaf_px"]) == 600 * 360
        # Stop on a missing second annotation, preserving the completed first image.
        interrupted_input = temp / "interrupted_input"; interrupted_input.mkdir()
        interrupted_marks = temp / "interrupted_marks"; interrupted_marks.mkdir()
        interrupted_output = temp / "interrupted_output"; interrupted_output.mkdir()
        for name in ("a.png", "b.png"):
            (interrupted_input / name).write_bytes((source / "synthetic.png").read_bytes())
        (interrupted_marks / "a.png.annotations.txt").write_text(annotation)
        config = temp / "interrupt.properties"
        config.write_text(f"input={interrupted_input.as_posix()}\n"
                          f"output={interrupted_output.as_posix()}\n"
                          f"annotations={interrupted_marks.as_posix()}\n")
        stopped = invoke(args.java, args.ij_jar, config)
        assert stopped.returncode != 0
        assert "Missing annotation" in stopped.stdout + stopped.stderr
        partial = next(interrupted_output.glob("WSA_*"))
        assert (partial / "status.txt").read_text().strip() == "running"
        with (partial / "results.tsv").open(newline="") as stream:
            saved = list(csv.DictReader(stream, delimiter="\t"))
        assert len(saved) == 1 and saved[0]["Image"] == "a.png"
        assert (partial / "masks" / "a.png_mask.tif").exists()
        # Invalid settings must fail before any run folder is created.
        invalid_output = temp / "invalid_config"; invalid_output.mkdir()
        config.write_text(f"input={source.as_posix()}\noutput={invalid_output.as_posix()}\n"
                          f"annotations={annotations.as_posix()}\nhue_min=90\nhue_max=20\n")
        rejected = invoke(args.java, args.ij_jar, config)
        assert rejected.returncode != 0 and not list(invalid_output.glob("WSA_*"))
        # Reject overflow without relying on an undefined macro-language constant.
        config.write_text(f"input={source.as_posix()}\noutput={invalid_output.as_posix()}\n"
                          f"annotations={annotations.as_posix()}\nlabel_width_cm=1e309\n")
        overflow = invoke(args.java, args.ij_jar, config)
        assert overflow.returncode != 0 and not list(invalid_output.glob("WSA_*"))
        assert "must be finite and positive" in overflow.stdout + overflow.stderr
    assert hashlib.sha256((source / "synthetic.png").read_bytes()).hexdigest() == source_hash
    print("PASS: ImageJ counts, scale, sample statistics, full masks, replay, output isolation, "
          "filename collisions/CSV quoting, unsupported input, zero area, N=1, skipped points, "
          "inclusive extremes, interrupted-run persistence and invalid settings.")


if __name__ == "__main__":
    main()

