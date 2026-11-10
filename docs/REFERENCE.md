# Technical reference

## Segmentation and physical conversion

ImageJ converts the RGB photograph to HSB bytes on a 0-255 scale. A pixel is
foreground if it passes every inclusive interval. The default intervals are
H=32..83, S=60..255 and B=35..255. Hue wraparound is not supported. There is no
morphological cleanup, hole filling, learned model or automatic thresholding.

For reference length `C` in cm and line length `L` in pixels:

```text
scale_cm_per_px = C / L
area_cm2 = foreground_pixel_count * (C / L)^2
```

## Exact strip geometry

Points are sorted by x coordinate. Internal x boundaries are midpoints of adjacent
centers. Each outer boundary extends by the selected outer margin times the
reference length in pixels, clipped to the image bounds. Coordinates are rounded
once and shared by adjacent strips.

Every strip starts at y=0 and ends at the rounded largest point y coordinate.
Pixel membership is half-open: `[left,right)` by `[0,bottom)`. Coincident centers,
zero-width strips and a non-positive strip height are invalid. This geometry
does not follow individual leaves or an angled label row.

## Table fields

- `Image`, `Status`, `Width_px`, `Height_px`.
- `FrameLeaf_px`, `FrameLeaf_cm2`: full-frame foreground.
- `AnalyzedLeaf_px`, `AnalyzedLeaf_cm2`: foreground inside the strip union.
- `PotN_px`, `PotN_cm2`: each strip, left to right.
- `Mean_*`: arithmetic mean across strips.
- `SD_*`: sample standard deviation with denominator N-1.
- `SEM_*`: sample SD divided by sqrt(N).
- `ReferenceWidth_px`, `Scale_cm_per_px`.

Sample SD and SEM are NaN for N=1. Invalid points give `skipped_points`: strip
measurements are NaN while full-frame values remain available. Unsupported
grayscale/indexed input or stacks give `unsupported_rgb_or_stack`. Invalid or
missing reference/replay data stops processing instead of inventing a value.

Floating-point formatting does not imply corresponding measurement precision.

## Settings files

Copy `settings.example.properties` and supply existing absolute paths. Use forward
slashes and no `.` or `..` segments. Keys are case-sensitive; unknown keys are ignored.
Boolean values are 0 or 1. Accepted table formats are `TSV`, `CSV`, `Semicolon`.

Run from another ImageJ macro:

```javascript
runMacro("/absolute/path/WSA.ijm", "/absolute/path/local.properties");
```

If `annotations` is empty, reference lines and points are marked interactively.
For replay, set `annotations` to a previous run's annotation folder. The saved
`settings.properties` already includes that path. Source content, dimensions and
filenames must be unchanged; the macro does not verify image content hashes.

Command-line replay:

```text
java -Xmx2g -jar /path/to/ij.jar -batch /path/to/WSA.ijm /path/to/local.properties
```

ImageJ 1.x still requires Java AWT, including in batch mode. Linux needs a display
or virtual display. The developer runner needs Java 11+ for source-file launching.

## File handling

Each invocation writes a new `WSA_<timestamp>` folder. A numeric suffix resolves
a name collision. Existing runs are not overwritten. The input listing is not
recursive. Output must be outside input; the lexical folder check does not resolve
symbolic links, so choose genuinely separate folders.

Artifact filenames retain the input extension: `photo.jpg_mask.tif` and
`photo.png_mask.tif` remain distinct. Image-name table fields are quoted. TSV
uses `.tsv`, not an Excel binary extension. Decimal commas are incompatible with
comma-separated CSV and are rejected for that format.

The TIFF mask covers the whole frame, contains only 0/255 and is saved without
a residual strip selection. Existing source or global ImageJ calibration can
remain in TIFF metadata. Use the table's explicit manually measured scale for
physical calculations. The macro does not replace the user's global calibration.

QC PNGs show yellow boundaries and cyan reference lines. Source photographs are
not saved or modified. Existing Results and ROI Manager are not cleared. Only
images owned by the macro are closed. BlackBackground is not changed.

Completed rows are appended after that image's artifacts are saved. The run status
changes from `running` to `complete` at normal completion. Earlier completed
rows survive an abort; an interrupted image can have partial artifacts. There
is no automatic resume or recovery of an unfinished image.
