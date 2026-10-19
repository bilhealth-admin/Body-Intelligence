import java.nio.file.*;
import java.util.jar.*;
import java.security.*;
import java.util.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;

// Audit-only bridge for the pinned Lint 32.0.1 GradleDetector context defect.
// Does not enter any APK/IPA, change an issue, or edit an official rule JAR.
// Repro: a deferred Kotlin cookie was passed to a later Groovy file Context.
// Bind a deferred AGP source cookie to the Context that created it.
public final class BilLintOriginContextCompat {
  public static void main(String[] args) throws Exception {
    String owner = "com/android/tools/lint/checks/GradleDetector";
    String context = "Lcom/android/tools/lint/detector/api/Context;";
    byte[] original;
    try (JarFile jar = new JarFile(args[0])) {
      original = jar.getInputStream(jar.getJarEntry(owner + ".class")).readAllBytes();
    }
    String originalHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(original));
    if (!originalHash.equals("f598123af6cae5b45efdbec98b846ce1f47ba45a71534b9e5892f091195c0d7f")) {
      throw new IllegalStateException("Unreviewed Lint detector bytecode: " + originalHash);
    }
    ClassNode node = new ClassNode();
    new ClassReader(original).accept(node, 0);
    if (node.fields.stream().anyMatch(f -> f.name.equals("bilAgpOriginContext"))) throw new IllegalStateException("Already patched");
    node.fields.add(new FieldNode(Opcodes.ACC_PRIVATE, "bilAgpOriginContext", context, null, null));
    int assignments = 0, methods = 0;
    for (MethodNode m : node.methods) {
      if (m.name.equals("checkDependency") && m.desc.startsWith("(" + context)) {
        for (AbstractInsnNode insn : m.instructions.toArray()) {
          if (insn instanceof FieldInsnNode f && f.getOpcode() == Opcodes.PUTFIELD && f.owner.equals(owner) && f.name.equals("agpVersionCheckInfo")) {
            InsnList add = new InsnList();
            add.add(new VarInsnNode(Opcodes.ALOAD, 0));
            add.add(new VarInsnNode(Opcodes.ALOAD, 1));
            add.add(new FieldInsnNode(Opcodes.PUTFIELD, owner, "bilAgpOriginContext", context));
            m.instructions.insert(insn, add);
            assignments++;
          }
        }
      }
      if (m.name.equals("maybeReportAgpVersionIssue") && m.desc.equals("(" + context + ")V")) {
        LabelNode keep = new LabelNode();
        InsnList add = new InsnList();
        add.add(new VarInsnNode(Opcodes.ALOAD, 0));
        add.add(new FieldInsnNode(Opcodes.GETFIELD, owner, "bilAgpOriginContext", context));
        add.add(new JumpInsnNode(Opcodes.IFNULL, keep));
        add.add(new VarInsnNode(Opcodes.ALOAD, 0));
        add.add(new FieldInsnNode(Opcodes.GETFIELD, owner, "bilAgpOriginContext", context));
        add.add(new VarInsnNode(Opcodes.ASTORE, 1));
        add.add(keep);
        m.instructions.insert(add);
        methods++;
      }
    }
    if (assignments != 1 || methods != 1) throw new IllegalStateException("Unexpected vendor ABI: " + assignments + "/" + methods);
    ClassWriter writer = new ClassWriter(ClassWriter.COMPUTE_MAXS | ClassWriter.COMPUTE_FRAMES);
    node.accept(writer);
    Path target = Path.of(args[1], owner + ".class");
    Files.createDirectories(target.getParent());
    String outputHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(writer.toByteArray()));
    if (!outputHash.equals("b7bfe1e781357b862a40f67df32805eaa77b03a031216834292edb5839ccd4ae")) {
      throw new IllegalStateException("Unexpected compatibility output: " + outputHash);
    }
    Files.write(target, writer.toByteArray());
    System.out.println("Patched class SHA256=" + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(writer.toByteArray())));
  }
  // Separate loaders prevent the original registry from masking the generated
  // class. Compare all issue IDs, default severities and implementation scopes.
  public static String registryMetadata(String prefix, String classpath) throws Exception {
    List<java.net.URL> urls = new ArrayList<>();
    if (!prefix.isEmpty()) urls.add(Path.of(prefix).toUri().toURL());
    for (String item : classpath.split(java.util.regex.Pattern.quote(java.io.File.pathSeparator))) {
      urls.add(Path.of(item).toUri().toURL());
    }
    ClassLoader previous = Thread.currentThread().getContextClassLoader();
    try (java.net.URLClassLoader loader = new java.net.URLClassLoader(urls.toArray(java.net.URL[]::new), ClassLoader.getPlatformClassLoader())) {
      Thread.currentThread().setContextClassLoader(loader);
      Class<?> client = loader.loadClass("com.android.tools.lint.client.api.LintClient");
      Object companion = client.getField("Companion").get(null);
      companion.getClass().getMethod("setClientName", String.class).invoke(companion, "gradle");
      Class<?> registry = loader.loadClass("com.android.tools.lint.checks.BuiltinIssueRegistry");
      Object instance = registry.getConstructor().newInstance();
      List<?> issues = (List<?>) registry.getMethod("getIssues").invoke(instance);
      List<String> rows = new ArrayList<>();
      for (Object issue : issues) {
        Class<?> type = issue.getClass();
        Object implementation = type.getMethod("getImplementation").invoke(issue);
        rows.add(type.getMethod("getId").invoke(issue) + "\t" +
            type.getMethod("getDefaultSeverity").invoke(issue) + "\t" +
            implementation.getClass().getMethod("getScope").invoke(implementation));
      }
      Collections.sort(rows);
      if (rows.size() != 509) throw new IllegalStateException("Unexpected builtin registry size: " + rows.size());
      return String.join("\n", rows) + "\n";
    } finally {
      Thread.currentThread().setContextClassLoader(previous);
    }
  }

}
