// WSA (Wheat Shoot Area) 2.18.1
// Projected leaf area in RGB photographs, with manually defined pot strips.
// Run normally for dialogs, or pass an absolute settings-file path as argument.
requires("1.54f");

VERSION = "2.18.1";
config = "";
argument = getArgument();
if (argument != "") {
    if (!File.exists(argument)) exit("Settings file does not exist: " + argument);
    config = File.openAsString(argument);
}
labelCm = numberSetting("label_width_cm", 6);
pots = numberSetting("pots", 5);
margin = numberSetting("outer_margin_label_widths", 2);
hMin = numberSetting("hue_min", 32); hMax = numberSetting("hue_max", 83);
sMin = numberSetting("saturation_min", 60); sMax = numberSetting("saturation_max", 255);
bMin = numberSetting("brightness_min", 35); bMax = numberSetting("brightness_max", 255);
format = setting("table_format", "TSV");
decimalComma = numberSetting("decimal_comma", 0);
saveQC = numberSetting("save_qc", 1);
input = setting("input", ""); output = setting("output", "");
annotations = setting("annotations", "");
replay = (annotations != "");

if (argument == "") {
    Dialog.create("WSA " + VERSION);
    Dialog.addNumber("Reference width (cm)", labelCm);
    Dialog.addNumber("Number of pots", pots);
    Dialog.addNumber("Outer margin (reference widths)", margin);
    Dialog.addNumber("Hue minimum (0-255)", hMin);
    Dialog.addNumber("Hue maximum (0-255)", hMax);
    Dialog.addNumber("Saturation minimum (0-255)", sMin);
    Dialog.addNumber("Saturation maximum (0-255)", sMax);
    Dialog.addNumber("Brightness minimum (0-255)", bMin);
    Dialog.addNumber("Brightness maximum (0-255)", bMax);
    Dialog.addChoice("Table format", newArray("TSV", "CSV", "Semicolon"), format);
    Dialog.addCheckbox("Decimal comma", decimalComma);
    Dialog.addCheckbox("Save QC images", saveQC);
    Dialog.show();
    labelCm = Dialog.getNumber(); pots = Dialog.getNumber(); margin = Dialog.getNumber();
    hMin = Dialog.getNumber(); hMax = Dialog.getNumber();
    sMin = Dialog.getNumber(); sMax = Dialog.getNumber();
    bMin = Dialog.getNumber(); bMax = Dialog.getNumber();
    format = Dialog.getChoice(); decimalComma = Dialog.getCheckbox(); saveQC = Dialog.getCheckbox();
}
positive(labelCm, "Reference width"); positive(pots, "Number of pots");
if (pots != floor(pots)) exit("Number of pots must be an integer.");
positive(margin, "Outer margin");
checkRange(hMin, hMax, "Hue"); checkRange(sMin, sMax, "Saturation"); checkRange(bMin, bMax, "Brightness");
if (format != "TSV" && format != "CSV" && format != "Semicolon") exit("Unknown table_format.");
if (decimalComma != 0 && decimalComma != 1) exit("decimal_comma must be 0 or 1.");
if (saveQC != 0 && saveQC != 1) exit("save_qc must be 0 or 1.");
SEP = "\t"; extension = ".tsv";
if (format == "CSV") { SEP = ","; extension = ".csv"; }
if (format == "Semicolon") { SEP = ";"; extension = ".csv"; }
if (format == "CSV" && decimalComma) exit("Use TSV or Semicolon for decimal commas.");
if (input == "") input = getDirectory("Choose input images folder");
if (output == "") output = getDirectory("Choose output parent folder");
input = folder(input); output = folder(output);
if (!File.isDirectory(input) || !File.isDirectory(output)) exit("Input and output folders must already exist.");
// Compare normalized absolute paths; no source files are ever rewritten.
inputCanonical = normalizedFolder(input); outputCanonical = normalizedFolder(output);
if (startsWith(outputCanonical, inputCanonical)) exit("Output must be outside the input folder.");
if (replay) {
    annotations = folder(annotations);
    if (!File.isDirectory(annotations)) exit("Annotation folder does not exist.");
}
list = getFileList(input); Array.sort(list);
count = 0;
for (i = 0; i < list.length; i++) if (isInputImage(list[i])) count++;
if (count == 0) exit("No supported image files in the input folder.");

stamp = d2s(getTime(), 0);
runDir = output + "WSA_" + stamp;
suffix = 1;
while (File.exists(runDir)) { runDir = output + "WSA_" + stamp + "_" + suffix; suffix++; }
runDir = folder(runDir); File.makeDirectory(runDir);
File.makeDirectory(runDir + "annotations");
File.makeDirectory(runDir + "masks");
if (saveQC) File.makeDirectory(runDir + "qc");
File.saveString("running\n", runDir + "status.txt");
settingsText = "# WSA " + VERSION + "\nimagej_version=" + getVersion() + "\n";
settingsText += "input=" + input + "\noutput=" + output + "\nannotations=" + runDir + "annotations/\n";
settingsText += "label_width_cm=" + labelCm + "\npots=" + pots + "\nouter_margin_label_widths=" + margin + "\n";
settingsText += "hue_min=" + hMin + "\nhue_max=" + hMax + "\nsaturation_min=" + sMin + "\nsaturation_max=" + sMax;
settingsText += "\nbrightness_min=" + bMin + "\nbrightness_max=" + bMax + "\ntable_format=" + format;
settingsText += "\ndecimal_comma=" + decimalComma + "\nsave_qc=" + saveQC + "\n";
File.saveString(settingsText, runDir + "settings.properties");
header = "Image" + SEP + "Status" + SEP + "Width_px" + SEP + "Height_px";
header += SEP + "FrameLeaf_px" + SEP + "FrameLeaf_cm2" + SEP + "AnalyzedLeaf_px" + SEP + "AnalyzedLeaf_cm2";
for (p = 1; p <= pots; p++) header += SEP + "Pot" + p + "_px" + SEP + "Pot" + p + "_cm2";
header += SEP + "Mean_px" + SEP + "SD_px" + SEP + "SEM_px" + SEP + "Mean_cm2" + SEP + "SD_cm2" + SEP + "SEM_cm2";
header += SEP + "ReferenceWidth_px" + SEP + "Scale_cm_per_px\n";
resultsPath = runDir + "results" + extension;
File.saveString(header, resultsPath);
// Results and ROI Manager are intentionally left alone. Only owned image IDs are closed.
if (replay) setBatchMode(true);
processed = 0;
for (i = 0; i < list.length; i++) {
    if (!isInputImage(list[i])) continue;
    processImage(list[i]);
    processed++;
    showProgress(processed, count);
}
if (replay) setBatchMode(false);
File.saveString("complete\nprocessed=" + processed + "\n", runDir + "status.txt");
print("WSA: " + processed + " image(s). Output: " + runDir);
if (!replay) showMessage("WSA complete", "Processed " + processed + " image(s).\n" + runDir);

function setting(key, fallback) {
    rows = split(config, "\n");
    for (r = 0; r < rows.length; r++) {
        row = trim(rows[r]);
        if (startsWith(row, "#")) continue;
        eq = indexOf(row, "=");
        if (eq < 0) continue;
        if (trim(substring(row, 0, eq)) == key) return trim(substring(row, eq + 1));
    }
    return fallback;
}
function numberSetting(key, fallback) { return parseFloat(setting(key, "" + fallback)); }
function positive(value, name) {
    if (isNaN(value) || value <= 0 || isNaN(value - value)) exit(name + " must be finite and positive.");
}
function checkRange(lo, hi, name) {
    if (isNaN(lo) || isNaN(hi) || lo < 0 || hi > 255 || lo > hi || lo != floor(lo) || hi != floor(hi))
        exit(name + " must be integer bounds with 0 <= minimum <= maximum <= 255.");
}
function folder(path) {
    path = replace(path, "\\\\", "/");
    if (!endsWith(path, "/")) path += "/";
    return path;
}
function normalizedFolder(path) {
    path = folder(path);
    absolute = (startsWith(path, "/") || matches(path, "[A-Za-z]:/.*"));
    if (!absolute || indexOf(path, "/../") >= 0 || indexOf(path, "/./") >= 0)
        exit("Use absolute folder paths without dot segments.");
    return toLowerCase(path);
}
function isInputImage(name) {
    if (File.isDirectory(input + name)) return false;
    low = toLowerCase(name);
    if (indexOf(low, "_mask") >= 0 || indexOf(low, "_qc") >= 0) return false;
    if (endsWith(low, ".jpg")) return true;
    if (endsWith(low, ".jpeg")) return true;
    if (endsWith(low, ".png")) return true;
    if (endsWith(low, ".tif")) return true;
    if (endsWith(low, ".tiff")) return true;
    if (endsWith(low, ".bmp")) return true;
    return false;
}
function fmt(value, decimals) {
    text = d2s(value, decimals);
    if (decimalComma) text = replace(text, "\\.", ",");
    return text;
}
function field(text) { return "\"" + replace(text, "\"", "\"\"") + "\""; }
function annotationValue(text, key, fallback) {
    savedConfig = config; config = text;
    value = "" + setting(key, fallback);
    config = savedConfig;
    return value;
}
function thresholdSlice(stackId, slice, lo, hi, title) {
    selectImage(stackId); setSlice(slice);
    run("Duplicate...", "title=" + title);
    channelId = getImageID();
    setThreshold(lo, hi);
    run("Create Mask");
    maskId = getImageID();
    // Create Mask keeps white=255 foreground regardless of BlackBackground.
    // Normalize only this image's LUT, without changing global preferences.
    run("Grays"); resetThreshold(); rename(title + "_mask");
    selectImage(channelId); close();
    return maskId;
}
function processImage(filename) {
    open(input + filename); source = getImageID();
    w = getWidth(); h = getHeight();
    // Ordinary, single-frame, 8-bit/channel RGB photographs only.
    getDimensions(dw, dh, dc, dz, dt);
    if (bitDepth() != 24 || dz != 1 || dt != 1 || dc != 1) {
        close();
        File.append(field(filename) + SEP + "unsupported_rgb_or_stack" + emptyFields(2 * pots + 14) + "\n", resultsPath);
        return;
    }
    lx1 = NaN; ly1 = NaN; lx2 = NaN; ly2 = NaN;
    mx = newArray(0); my = newArray(0); accepted = false;
    if (replay) {
        annotationPath = annotations + filename + ".annotations.txt";
        if (!File.exists(annotationPath)) exit("Missing annotation: " + annotationPath);
        text = File.openAsString(annotationPath);
        lx1 = parseFloat(annotationValue(text, "scale_x1", "NaN"));
        ly1 = parseFloat(annotationValue(text, "scale_y1", "NaN"));
        lx2 = parseFloat(annotationValue(text, "scale_x2", "NaN"));
        ly2 = parseFloat(annotationValue(text, "scale_y2", "NaN"));
        xs = split(annotationValue(text, "points_x", ""), ",");
        ys = split(annotationValue(text, "points_y", ""), ",");
        mx = newArray(xs.length); my = newArray(ys.length);
        for (j = 0; j < xs.length; j++) mx[j] = parseFloat(xs[j]);
        for (j = 0; j < ys.length; j++) my[j] = parseFloat(ys[j]);
        annotationStatus = "" + annotationValue(text, "status", "accepted");
        accepted = (annotationStatus == "accepted");
    } else {
        selectImage(source); run("Select None"); setTool("line");
        lengthPx = 0;
        while (lengthPx <= 0) {
            waitForUser("Reference: " + filename, "Draw a STRAIGHT line along the " + labelCm + " cm reference.\nPress OK to accept, or Cancel to stop the run.");
            if (selectionType() == 5) {
                getLine(lx1, ly1, lx2, ly2, lineWidth);
                lengthPx = sqrt(pow(lx2-lx1, 2) + pow(ly2-ly1, 2));
            }
        }
        run("Select None"); setTool("multipoint");
        for (attempt = 0; attempt < 4; attempt++) {
            waitForUser("Pot points: " + filename,
                "Place exactly " + pots + " points, one per pot. Order does not matter.\n" +
                "X: middle of the plant's leaf spread, NOT the label center.\n" +
                "Y: label/base-of-shoots line, at approximately equal heights.\n" +
                "Alt+click removes an extra point. Attempt " + (attempt+1) + " of 4.\n" +
                "After four invalid attempts, pot measurements are marked skipped.");
            mx = newArray(0); my = newArray(0);
            if (selectionType() == 10) getSelectionCoordinates(mx, my);
            if (mx.length == pots) { accepted = true; break; }
        }
    }
    lengthPx = sqrt(pow(lx2-lx1, 2) + pow(ly2-ly1, 2));
    if (isNaN(lengthPx) || lengthPx <= 0) exit("Invalid reference line for " + filename);
    if (!inside(lx1, ly1, w, h) || !inside(lx2, ly2, w, h)) exit("Reference line outside image: " + filename);
    scale = labelCm / lengthPx; k2 = scale * scale;
    if (mx.length != pots || my.length != pots) accepted = false;
    if (accepted) {
        for (j = 0; j < pots; j++) if (!inside(mx[j], my[j], w, h)) accepted = false;
    }
    // Preserve raw click order in the sidecar; sort a copy for left-to-right strips.
    annotationText = "status=";
    if (accepted) annotationText += "accepted\n"; else annotationText += "skipped\n";
    annotationText += "scale_x1=" + lx1 + "\nscale_y1=" + ly1 + "\nscale_x2=" + lx2 + "\nscale_y2=" + ly2;
    annotationText += "\npoints_x=" + join(mx) + "\npoints_y=" + join(my) + "\n";
    bounds = newArray(pots + 1); roiHeight = 0;
    if (accepted) {
        Array.sort(mx, my);
        for (j = 1; j < pots; j++) if (mx[j] <= mx[j-1]) accepted = false;
        for (j = 0; j < pots; j++) roiHeight = maxOf(roiHeight, my[j]);
        roiHeight = minOf(h, round(roiHeight));
        bounds[0] = maxOf(0, round(mx[0] - margin * lengthPx));
        for (j = 1; j < pots; j++) bounds[j] = round((mx[j-1] + mx[j]) / 2);
        bounds[pots] = minOf(w, round(mx[pots-1] + margin * lengthPx));
        for (j = 0; j < pots; j++) if (bounds[j+1] <= bounds[j]) accepted = false;
        if (roiHeight <= 0) accepted = false;
    }
    if (!accepted) annotationText = replace(annotationText, "status=accepted", "status=skipped");
    annotationText += "roi_height_px=" + roiHeight + "\nroi_bounds_x=" + join(bounds) + "\n";
    File.saveString(annotationText, runDir + "annotations/" + filename + ".annotations.txt");

    selectImage(source); run("Select None");
    token = "WSA_" + stamp + "_" + i;
    run("Duplicate...", "title=" + token + "_hsb");
    run("HSB Stack"); hsb = getImageID();
    hm = thresholdSlice(hsb, 1, hMin, hMax, token + "_h");
    sm = thresholdSlice(hsb, 2, sMin, sMax, token + "_s");
    bm = thresholdSlice(hsb, 3, bMin, bMax, token + "_b");
    imageCalculator("AND create", hm, sm); hs = getImageID();
    imageCalculator("AND create", hs, bm); mask = getImageID();
    selectImage(hm); close(); selectImage(sm); close(); selectImage(bm); close();
    selectImage(hs); close(); selectImage(hsb); close();
    selectImage(mask); rename(token + "_mask"); run("Grays");
    run("Select None"); getHistogram(values, counts, 256); framePx = counts[255];
    potPx = newArray(pots); analyzed = NaN; meanPx = NaN; sdPx = NaN; semPx = NaN;
    for (j = 0; j < pots; j++) potPx[j] = NaN;
    if (accepted) {
        analyzed = 0;
        for (j = 0; j < pots; j++) {
            makeRectangle(bounds[j], 0, bounds[j+1]-bounds[j], roiHeight);
            getHistogram(values, counts, 256); potPx[j] = counts[255]; analyzed += potPx[j];
        }
        meanPx = analyzed / pots;
        if (pots > 1) {
            ss = 0; for (j = 0; j < pots; j++) ss += pow(potPx[j]-meanPx, 2);
            sdPx = sqrt(ss / (pots-1)); semPx = sdPx / sqrt(pots);
        }
    }
    // Save the full-frame mask with no lingering strip ROI. Do not alter global calibration.
    run("Select None");
    saveAs("Tiff", runDir + "masks/" + filename + "_mask.tif"); close();
    if (saveQC) {
        selectImage(source); run("Select None"); run("Duplicate...", "title=" + token + "_qc");
        setColor(255, 255, 0); setLineWidth(maxOf(1, round(w/500)));
        fontSize = maxOf(12, round(w/40)); setFont("SansSerif", fontSize, "bold");
        if (accepted) {
            for (j = 0; j < pots; j++) {
                drawRect(bounds[j], 0, bounds[j+1]-bounds[j], roiHeight);
                drawString("" + (j+1), bounds[j]+4, fontSize+4);
            }
        } else { setColor(255, 0, 0); drawString("SKIPPED: invalid pot points", 4, fontSize+4); }
        setColor(0, 255, 255); drawLine(lx1, ly1, lx2, ly2);
        run("Select None"); saveAs("PNG", runDir + "qc/" + filename + "_QC.png"); close();
    }
    row = "" + field(filename) + SEP;
    if (accepted) row += "accepted"; else row += "skipped_points";
    row += SEP + w + SEP + h + SEP + fmt(framePx,0) + SEP + fmt(framePx*k2,6);
    row += SEP + fmt(analyzed,0) + SEP + fmt(analyzed*k2,6);
    for (j = 0; j < pots; j++) row += SEP + fmt(potPx[j],0) + SEP + fmt(potPx[j]*k2,6);
    row += SEP + fmt(meanPx,6) + SEP + fmt(sdPx,6) + SEP + fmt(semPx,6);
    row += SEP + fmt(meanPx*k2,6) + SEP + fmt(sdPx*k2,6) + SEP + fmt(semPx*k2,6);
    row += SEP + fmt(lengthPx,9) + SEP + fmt(scale,12) + "\n";
    // File.append opens/closes the file on each image, keeping completed rows on abort.
    File.append(row, resultsPath);
    selectImage(source); close();
}
function inside(x, y, w, h) { return (!isNaN(x) && !isNaN(y) && x >= 0 && x < w && y >= 0 && y < h); }
function join(array) {
    text = "";
    for (j = 0; j < array.length; j++) { if (j > 0) text += ","; text += d2s(array[j], 9); }
    return text;
}
function emptyFields(n) {
    text = ""; for (j = 0; j < n; j++) text += SEP + "NaN";
    return text;
}
