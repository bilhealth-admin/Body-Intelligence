// Audit-only entrypoint; call the unchanged official Main.run and retain its
// exit code. An uncaught detector crash must not leave an AWT thread hanging.
public final class BilBoundedLintMain {
  public static void main(String[] args) {
    System.setProperty("java.awt.headless", "true");
    int exitCode = 2;
    try {
      exitCode = new com.android.tools.lint.Main().run(args);
    } catch (Throwable failure) {
      System.err.println("BIL GLOBAL lint did not complete: vendor/runtime failure.");
      failure.printStackTrace(System.err);
    } finally {
      System.out.flush();
      System.err.flush();
    }
    System.exit(exitCode);
  }
}
