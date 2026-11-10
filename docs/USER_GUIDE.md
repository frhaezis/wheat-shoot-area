# User guide

## 1. Prepare the photographs

Use the original RGB photographs at their original resolution. A plain background
that differs from the plant color works best. Include the whole plant if you want
its whole projected silhouette measured. A plant extending beyond the photograph
cannot be recovered by the macro.

Include a ruler or label of known length, approximately in the plant plane.
Perspective, a tilted reference or a reference far in front of/behind the plant
can distort the conversion to cm².

Put only the photographs to analyze in one folder. Nested folders are ignored.
Names containing `_mask` or `_qc` are also ignored, regardless of capitalization.

## 2. Run the macro

Open ImageJ, then choose **Plugins > Macros > Run...** and select
`WSA.ijm`. The settings dialog opens.

- **Reference width:** the actual physical length you will draw on the image.
  The default is 6 cm. Do not retain this value if your reference has another length.
- **Number of pots:** the number of adjacent plant strips, usually one per plant.
- **Outer margin:** how far the first and last strips extend beyond the outermost
  point, in multiples of the reference length measured on that image.
- **HSB thresholds:** the accepted color ranges. Leave the defaults for a first check.
- **Table format:** TSV is a tab-separated text table. It can be imported into
  Excel, LibreOffice or a data-analysis tool. CSV and semicolon formats are available.
- **Decimal comma:** use with TSV or semicolon format; comma-separated CSV requires a decimal point.
- **Save QC images:** keep enabled while checking the method on your photographs.

Choose an existing input folder, then a separate output parent folder outside it.

## 3. Mark the reference

For each image, use the selected straight-line tool to draw from one edge of the
reference to the other along the known length. Click OK. The macro measures the
line in pixels. Repeat separately on every image; it does not reuse the first
image's scale across the folder.

If no valid line is selected, the prompt appears again. Cancel stops the run.

## 4. Mark the plant strips

The multi-point tool is selected automatically. Add exactly the requested number
of points, one per plant:

- Place the horizontal position near the middle of the leaf spread, rather than
  assuming the label is centered under the whole canopy.
- Place the vertical position at the label/base-of-shoots line.
- Keep the points approximately level. Their largest y coordinate defines a
  common horizontal lower edge for every strip.

Click order does not matter. The macro sorts points from left to right. Alt+click
removes an extra point in ImageJ. There are four attempts to provide the requested
point count. If the points remain invalid, the macro records skipped strip areas
and continues. The whole-frame segmented pixel count remains available.

The strips are geometric regions, not separately recognized plants. A leaf crossing
into a neighbor's strip contributes to that neighbor's strip count.

## 5. Inspect the output

Open the `qc` images to check the reference line and strip boundaries. Then inspect
the corresponding binary masks:

- White pixels were accepted as plant-colored tissue.
- Black pixels were rejected.
- Missing parts of visible leaves indicate omissions.
- White regions on the background, labels or tray indicate unwanted inclusions.

The color thresholds can miss discolored or diseased tissue. An increased mask area is not
automatically an improvement; check both the leaves and background.

## 6. Read the table

Start with `Status`. `accepted` means the reference and strip geometry passed
the software checks; it does not certify biological segmentation accuracy.

- `AnalyzedLeaf_cm2`: total accepted area inside the strips.
- `Pot1_cm2` to `PotN_cm2`: left-to-right strip areas.
- `FrameLeaf_cm2`: accepted area across the entire photograph.
- `Scale_cm_per_px`: the manually measured per-image conversion factor.
- `Mean`, `SD`, `SEM`: descriptive statistics across the strips.

Do not pool different treatments into one group simply because they share a photo.
SD/SEM describe variation among strips; they are not segmentation uncertainty.

Zero is a valid measured area. `NaN` means a value is unavailable. SD and SEM are
undefined (`NaN`) when only one strip is requested.

## 7. Stop or repeat a run

Cancel a marking prompt to stop. Earlier completed rows and artifacts are retained.
`status.txt` says `complete` only when all selected images finished normally.
If it still says `running`, processing did not reach normal completion.

Every invocation creates a new folder. There is no automatic in-place resume.
An interrupted image can leave artifacts without a finished table row.

To replay an earlier run with unchanged source images, pass its saved
`settings.properties` to the macro as described in the technical reference.
Settings and annotation coordinates must match the same images and filenames.

## A safe first trial

Try a few representative images before processing a large collection. Check both
bright and shaded leaf surfaces, thin leaves and the background. Keep the selected
preset and manual coordinates with the results. A preset that works for one scene
may need adjustment for another camera or lighting setup.
