import ij.IJ;
import ij.Prefs;
import ij.ImagePlus;
import ij.macro.Interpreter;
import ij.measure.Calibration;
import ij.measure.ResultsTable;
import java.nio.file.Files;
import java.nio.file.Paths;

/** Test-only batch runner: needs AWT, but does not open a main ImageJ window. */
public class MacroCheck {
    public static void main(String[] args) throws Exception {
        ImagePlus init = IJ.createImage("init", "8-bit black", 1, 1, 1);
        IJ.run(init, "Grays", ""); // Initialize menus/preferences before the preference invariant.
        Interpreter interpreter = new Interpreter();
        interpreter.setIgnoreErrors(true);
        Prefs.blackBackground = false;
        Calibration calibration = new Calibration();
        calibration.pixelWidth = 0.37; calibration.pixelHeight = 0.53;
        calibration.setUnit("um"); init.setGlobalCalibration(calibration);
        ResultsTable results = ResultsTable.getResultsTable();
        results.incrementCounter(); results.setValue("sentinel", 0, 42);
        interpreter.run(Files.readString(Paths.get(args[0])), args[1]);
        String macroError = interpreter.getErrorMessage();
        if (interpreter.wasError() || (macroError != null && !macroError.isEmpty())) {
            System.err.println("Line " + interpreter.getLineNumber() + ": " + interpreter.getErrorMessage());
            System.exit(1);
        }
        if (Prefs.blackBackground) throw new AssertionError("BlackBackground preference changed");
        Calibration after = ImagePlus.getStaticGlobalCalibration();
        if (after == null || after.pixelWidth != 0.37 || after.pixelHeight != 0.53)
            throw new AssertionError("Global calibration changed");
        if (results.size() != 1 || results.getValue("sentinel", 0) != 42)
            throw new AssertionError("Existing Results data changed");
        System.out.println("ImageJ " + IJ.getVersion());
    }
}
