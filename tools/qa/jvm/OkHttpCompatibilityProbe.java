import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Member;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.Principal;
import java.security.PublicKey;
import java.security.cert.X509Certificate;
import java.security.spec.RSAPublicKeySpec;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Set;
import javax.net.ssl.SSLPeerUnverifiedException;
import javax.security.auth.x500.X500Principal;
import okhttp3.CertificatePinner;
import okhttp3.Headers;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Protocol;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;
import okhttp3.internal.tls.OkHostnameVerifier;
import okio.Buffer;

/** Offline QA only: no sockets, TLS server, trust-store changes, private keys or real accounts. */
public final class OkHttpCompatibilityProbe {
  private static int passed;
  private static int failed;
  private static int symbolsChecked;
  private static final Set<String> failedNames = new java.util.HashSet<>();
  private static String active = "bootstrap";
  private interface Action { void run() throws Exception; }

  public static void main(String[] args) {
    try {
      if (args.length != 3 || !Arrays.asList("linkage", "functional").contains(args[0])) {
        throw new IllegalArgumentException();
      }
      String jar = Path.of(OkHttpClient.class.getProtectionDomain().getCodeSource()
          .getLocation().toURI()).getFileName().toString();
      if (!jar.equals("okhttp-" + args[1] + ".jar")) {
        throw new SecurityException();
      }
      if (args[0].equals("linkage")) {
        linkage(Path.of(args[2]));
      } else {
        functional(args[1].equals("3.0.0"));
      }
      System.out.println("{\"schema\":\"bil.qa.okhttp.jvm.v1\",\"mode\":\"" + args[0]
          + "\",\"version\":\"" + args[1] + "\",\"passed\":" + passed
          + ",\"failed\":" + failed + ",\"symbols_checked\":" + symbolsChecked
          + ",\"network_requests\":0,\"real_tls_chain_tested\":false}");
      if (args[0].equals("functional") && args[1].equals("3.0.0")) {
        if (failed != 2 || !failedNames.equals(Set.of("non-ascii-kelvin-host-must-reject",
            "non-ascii-kelvin-san-must-reject"))) {
          throw new IllegalStateException("Expected exactly two direct-verifier regressions");
        }
      } else if (failed != 0) {
        throw new IllegalStateException("Candidate/linkage failure");
      }
    } catch (Throwable error) {
      // Never print certificate/pin details or exception messages.
      System.err.println("OKHTTP_QA_FAILED case=" + active + " type="
          + error.getClass().getSimpleName() + " passed=" + passed + " failed=" + failed);
      System.exit(1);
    }
  }

  private static void linkage(Path path) throws Exception {
    for (String line : Files.readAllLines(path, StandardCharsets.UTF_8)) {
      symbolsChecked++;
      String[] symbol = line.split("\t", -1);
      active = String.join(" ", symbol);
      Class<?> owner = Class.forName(symbol[1].replace('/', '.'), false,
          OkHttpCompatibilityProbe.class.getClassLoader());
      require(Modifier.isPublic(owner.getModifiers()));
      if (symbol[0].equals("C")) {
        continue;
      }
      Member member;
      if (symbol[0].equals("F")) {
        Field field = field(owner, symbol[2], symbol[3]);
        member = field;
      } else if (symbol[2].equals("<init>")) {
        Constructor<?> found = null;
        for (Constructor<?> constructor : owner.getDeclaredConstructors()) {
          if (descriptor(constructor.getParameterTypes(), void.class).equals(symbol[3])) {
            found = constructor;
          }
        }
        if (found == null) {
          throw new NoSuchMethodException();
        }
        member = found;
      } else {
        member = method(owner, symbol[2], symbol[3]);
      }
      require(Modifier.isPublic(member.getModifiers()));
      if (!symbol[4].equals("unknown")) {
        boolean staticInstruction = symbol[4].equals("invokestatic")
            || symbol[4].equals("getstatic") || symbol[4].equals("putstatic");
        require(Modifier.isStatic(member.getModifiers()) == staticInstruction);
        if (symbol[4].equals("invokeinterface")) {
          require(owner.isInterface());
        }
      }
    }
  }

  private static Method method(Class<?> type, String name, String descriptor) throws Exception {
    for (Method candidate : type.getDeclaredMethods()) {
      if (candidate.getName().equals(name) && descriptor(
          candidate.getParameterTypes(), candidate.getReturnType()).equals(descriptor)) {
        return candidate;
      }
    }
    if (type.getSuperclass() != null) {
      try { return method(type.getSuperclass(), name, descriptor); }
      catch (NoSuchMethodException expected) { /* Search interfaces next. */ }
    }
    for (Class<?> parent : type.getInterfaces()) {
      try { return method(parent, name, descriptor); }
      catch (NoSuchMethodException expected) { /* Search remaining interfaces. */ }
    }
    throw new NoSuchMethodException();
  }

  private static Field field(Class<?> type, String name, String descriptor) throws Exception {
    for (Field candidate : type.getDeclaredFields()) {
      if (candidate.getName().equals(name) && typeDescriptor(candidate.getType()).equals(descriptor)) {
        return candidate;
      }
    }
    if (type.getSuperclass() != null) {
      try { return field(type.getSuperclass(), name, descriptor); }
      catch (NoSuchFieldException expected) { /* Search interfaces next. */ }
    }
    for (Class<?> parent : type.getInterfaces()) {
      try { return field(parent, name, descriptor); }
      catch (NoSuchFieldException expected) { /* Search remaining interfaces. */ }
    }
    throw new NoSuchFieldException();
  }

  private static String descriptor(Class<?>[] parameters, Class<?> result) {
    StringBuilder text = new StringBuilder("(");
    for (Class<?> parameter : parameters) {
      text.append(typeDescriptor(parameter));
    }
    return text.append(')').append(typeDescriptor(result)).toString();
  }

  private static String typeDescriptor(Class<?> type) {
    if (type.isArray()) {
      return type.getName().replace('.', '/');
    }
    if (!type.isPrimitive()) {
      return "L" + type.getName().replace('.', '/') + ";";
    }
    if (type == void.class) return "V";
    if (type == boolean.class) return "Z";
    if (type == byte.class) return "B";
    if (type == short.class) return "S";
    if (type == char.class) return "C";
    if (type == int.class) return "I";
    if (type == long.class) return "J";
    if (type == float.class) return "F";
    if (type == double.class) return "D";
    throw new IllegalArgumentException();
  }

  private static void functional(boolean affectedBaseline) throws Exception {
    X509Certificate normal = certificate("api.example.test", false);
    hostname("ascii-match", "api.example.test", normal, true);
    hostname("ascii-case", "API.EXAMPLE.TEST", normal, true);
    hostname("wrong-host", "wrong.example.test", normal, false);
    X509Certificate wildcard = certificate("*.example.test", false);
    hostname("wildcard-child", "a.example.test", wildcard, true);
    hostname("wildcard-apex-rejected", "example.test", wildcard, false);
    hostname("wildcard-multilevel-rejected", "a.b.example.test", wildcard, false);
    hostname("ipv4-match", "192.0.2.7", certificate("192.0.2.7", true), true);
    hostname("ipv4-mismatch", "192.0.2.8", certificate("192.0.2.7", true), false);
    hostname("ipv6-match", "2001:db8::1", certificate("2001:db8::1", true), true);
    hostname("ipv6-mismatch", "2001:db8::2", certificate("2001:db8::1", true), false);
    hostname("non-ascii-kelvin-host-must-reject", "\u212A.example.test",
        certificate("k.example.test", false), false);
    hostname("non-ascii-kelvin-san-must-reject", "k.example.test",
        certificate("\u212A.example.test", false), false);
    active = "certificate-pinner-matching-public-key";
    CertificatePinner pinner = new CertificatePinner.Builder()
        .add("api.example.test", CertificatePinner.pin(normal)).build();
    pinner.check("api.example.test", Collections.singletonList(normal));
    require(true);
    X509Certificate wrongKey = new SyntheticCertificate("api.example.test", false, 3);
    reject(() -> pinner.check("api.example.test", Collections.singletonList(wrongKey)));
    CertificatePinner wrongPin = new CertificatePinner.Builder()
        .add("api.example.test", CertificatePinner.pin(wrongKey)).build();
    reject(() -> wrongPin.check("api.example.test", Collections.singletonList(normal)));
    CertificatePinner wildcardPin = new CertificatePinner.Builder()
        .add("*.example.test", CertificatePinner.pin(normal)).build();
    wildcardPin.check("a.example.test", Collections.singletonList(normal));
    require(true);
    reject(() -> wildcardPin.check("a.example.test", Collections.singletonList(wrongKey)));
    active = "offline-request-body-headers-response-with-actual-okio";
    MediaType media = MediaType.parse("text/plain; charset=utf-8");
    String value = "synthetic EN / عربي / 🍎";
    RequestBody body = RequestBody.create(media, value);
    Buffer buffer = new Buffer();
    body.writeTo(buffer);
    require(buffer.readUtf8().equals(value));
    Request request = new Request.Builder().url("https://api.example.test/")
        .headers(new Headers.Builder().add("X-BIL-QA", "synthetic").build()).post(body).build();
    require(request.header("X-BIL-QA").equals("synthetic"));
    Response response = new Response.Builder().request(request).protocol(Protocol.HTTP_1_1)
        .code(200).message("QA").body(ResponseBody.create(media, value)).build();
    require(response.code() == 200 && response.body().string().equals(value));
    response.body().close();
    if (!affectedBaseline) {
      active = "offline-client-builder-newCall-no-execute";
      OkHttpClient client = new OkHttpClient.Builder()
          .connectTimeout(2, java.util.concurrent.TimeUnit.SECONDS)
          .readTimeout(2, java.util.concurrent.TimeUnit.SECONDS)
          .writeTimeout(2, java.util.concurrent.TimeUnit.SECONDS).build();
      require(client.newCall(request).request().url().host().equals("api.example.test"));
      client.connectionPool().evictAll();
      client.dispatcher().executorService().shutdown();
    }
  }

  private static void hostname(String name, String host, X509Certificate cert, boolean expected) {
    active = name;
    boolean actual = OkHostnameVerifier.INSTANCE.verify(host, cert);
    boolean result = actual == expected;
    if (result) {
      passed++;
    } else {
      failed++;
      failedNames.add(name);
    }
    System.out.println("CASE " + name + " expected=" + expected + " actual=" + actual
        + " " + (result ? "PASS" : "FAIL"));
  }

  private static void reject(Action action) throws Exception {
    try { action.run(); }
    catch (SSLPeerUnverifiedException expected) { passed++; return; }
    throw new IllegalStateException();
  }

  private static void require(boolean condition) {
    if (!condition) throw new IllegalStateException();
    passed++;
  }

  private static X509Certificate certificate(String name, boolean ip) throws Exception {
    return new SyntheticCertificate(name, ip, 1);
  }

  private static final class SyntheticCertificate extends X509Certificate {
    private final String name;
    private final boolean ip;
    private final PublicKey publicKey;
    SyntheticCertificate(String name, boolean ip, int discriminator) throws Exception {
      this.name = name;
      this.ip = ip;
      // Public RSA parameters only. No private key is created or persisted.
      BigInteger modulus = BigInteger.ONE.shiftLeft(2047).add(BigInteger.valueOf(65537 + discriminator * 2L));
      publicKey = KeyFactory.getInstance("RSA").generatePublic(
          new RSAPublicKeySpec(modulus, BigInteger.valueOf(65537)));
    }
    @Override public Collection<List<?>> getSubjectAlternativeNames() {
      return Collections.singletonList(Arrays.asList(ip ? 7 : 2, name));
    }
    @Override public X500Principal getSubjectX500Principal() { return new X500Principal("CN=ignored.invalid"); }
    @Override public Principal getSubjectDN() { return getSubjectX500Principal(); }
    @Override public Principal getIssuerDN() { return new X500Principal("CN=Synthetic-QA"); }
    @Override public PublicKey getPublicKey() { return publicKey; }
    @Override public void checkValidity() { }
    @Override public void checkValidity(Date date) { }
    @Override public int getVersion() { return 3; }
    @Override public BigInteger getSerialNumber() { return BigInteger.ONE; }
    @Override public Date getNotBefore() { return new Date(0); }
    @Override public Date getNotAfter() { return new Date(4102444800000L); }
    @Override public byte[] getTBSCertificate() { throw new UnsupportedOperationException(); }
    @Override public byte[] getSignature() { return new byte[0]; }
    @Override public String getSigAlgName() { return "NONE"; }
    @Override public String getSigAlgOID() { return "0.0"; }
    @Override public byte[] getSigAlgParams() { return null; }
    @Override public boolean[] getIssuerUniqueID() { return null; }
    @Override public boolean[] getSubjectUniqueID() { return null; }
    @Override public boolean[] getKeyUsage() { return null; }
    @Override public int getBasicConstraints() { return -1; }
    @Override public byte[] getEncoded() { throw new UnsupportedOperationException(); }
    @Override public void verify(PublicKey key) { throw new UnsupportedOperationException(); }
    @Override public void verify(PublicKey key, String provider) { throw new UnsupportedOperationException(); }
    @Override public Set<String> getCriticalExtensionOIDs() { return null; }
    @Override public Set<String> getNonCriticalExtensionOIDs() { return null; }
    @Override public byte[] getExtensionValue(String oid) { return null; }
    @Override public boolean hasUnsupportedCriticalExtension() { return false; }
    @Override public String toString() { return "Synthetic QA certificate; not a real TLS chain"; }
  }
}
