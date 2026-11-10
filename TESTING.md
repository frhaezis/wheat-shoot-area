# Testing

Run the ImageJ integration checks from the repository root:

```text
python -m pip install numpy "Pillow>=10.1"
python tests/check_macro.py --ij-jar /absolute/path/to/ij.jar
```

Requirements: Python 3.10+, Java 11+ JDK, ImageJ 1.54f+ and Java AWT. Use
`--java /path/to/java` if Java is not on PATH. Linux requires a display or virtual display.

The script regenerates the synthetic example and verifies:

- Pixel counts, physical area conversion and left-to-right strip ordering.
- Mean, sample SD and SEM against NumPy calculations.
- Full-size binary masks and QC exports.
- Configurable saturation thresholds on a pale plant-colored rectangle.
- Replay from saved coordinates and separate output folders.
- Same-basename files, quoted CSV names, decimal commas and table structure.
- Unsupported input, empty masks, one strip and invalid point geometry.
- Inclusive threshold limits and rejected invalid or non-finite settings.
- Preservation of completed output after an interrupted run.
- Unchanged source data, existing Results, BlackBackground and global calibration.

The synthetic fixture tests software behavior and arithmetic. It does not measure
segmentation accuracy on camera photographs. Mask quality must be evaluated
on representative labeled data for the intended imaging conditions.
