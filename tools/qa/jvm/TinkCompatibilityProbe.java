import com.google.crypto.tink.Aead;
import com.google.crypto.tink.BinaryKeysetReader;
import com.google.crypto.tink.BinaryKeysetWriter;
import com.google.crypto.tink.CleartextKeysetHandle;
import com.google.crypto.tink.DeterministicAead;
import com.google.crypto.tink.KeyTemplates;
import com.google.crypto.tink.KeysetHandle;
import com.google.crypto.tink.Mac;
import com.google.crypto.tink.RegistryConfiguration;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.daead.DeterministicAeadConfig;
import com.google.crypto.tink.mac.ChunkedMac;
import com.google.crypto.tink.mac.ChunkedMacComputation;
import com.google.crypto.tink.mac.ChunkedMacVerification;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.util.Arrays;

/** QA only. All key material is synthetic and is written only beneath a private build directory. */
public final class TinkCompatibilityProbe {
  private static final String MARKER = "BIL_QA_SYNTHETIC_TINK_ONLY_V1";
  private static final String[] ALGORITHMS = {
    "AES256_GCM", "AES256_SIV", "HMAC_SHA256_128BITTAG", "AES_CMAC"
  };
  private static final byte[][] VALUES = {
    utf8("synthetic meal / EN"), utf8("وجبة تركيبية / العربية"), new byte[0],
    utf8("mixed عربي café 🍎"), new byte[] {0, 1, (byte) 128, (byte) 255}
  };
  private static final byte[][] AADS = {new byte[0], utf8("owner=synthetic;namespace=qa")};
  private static final byte[] KEYSET_AAD = utf8("BIL-QA-synthetic-keyset-context");
  private static Path root;
  private static String phase;
  private static String active = "bootstrap";
  private static int passed;

  private interface Action { void run() throws Exception; }

  public static void main(String[] args) {
    try {
      if (args.length != 3 || !Arrays.asList("create", "peer", "return").contains(args[0])) {
        throw new IllegalArgumentException();
      }
      phase = args[0];
      root = Path.of(args[1]).toAbsolutePath().normalize();
      Path owned = Path.of(System.getProperty("bil.qa.private.root", "")).toRealPath();
      if (!root.startsWith(owned) || !root.toRealPath().equals(root)
          || !Files.readString(owned.resolve(".synthetic-only")).equals(MARKER)) {
        throw new SecurityException();
      }
      String jar = Path.of(Aead.class.getProtectionDomain().getCodeSource().getLocation().toURI())
          .getFileName().toString();
      if (!jar.equals("tink-android-" + args[2] + ".jar")) {
        throw new SecurityException();
      }
      AeadConfig.register();
      DeterministicAeadConfig.register();
      KeysetHandle masterHandle;
      if (phase.equals("create")) {
        masterHandle = KeysetHandle.generateNew(KeyTemplates.get("AES256_GCM"));
        save("master.bin", serialize(masterHandle));
      } else {
        masterHandle = raw(read("master.bin"));
      }
      Aead master = masterHandle.getPrimitive(RegistryConfiguration.get(), Aead.class);
      for (String algorithm : ALGORITHMS) {
        active = "keyset-" + algorithm;
        KeysetHandle handle;
        if (phase.equals("create")) {
          handle = KeysetHandle.generateNew(KeyTemplates.get(algorithm));
          save(algorithm + ".raw", serialize(handle));
          save(algorithm + ".wrapped", wrap(handle, master, KEYSET_AAD));
          save(algorithm + ".empty-aad", wrap(handle, master, new byte[0]));
        } else {
          handle = raw(read(algorithm + ".raw"));
        }
        byte[] expected = serialize(handle);
        String wrappedPrefix = phase.equals("return") ? ".peer" : "";
        byte[] wrapped = read(algorithm + wrappedPrefix + ".wrapped");
        check(Arrays.equals(expected, serialize(unwrap(wrapped, master, KEYSET_AAD))));
        check(Arrays.equals(expected, serialize(unwrap(
            read(algorithm + wrappedPrefix + ".empty-aad"), master, new byte[0]))));
        reject(() -> unwrap(wrapped, master, utf8("wrong-keyset-context")));
        byte[] damaged = tamperWrapped(wrapped);
        reject(() -> unwrap(damaged, master, KEYSET_AAD));
        if (phase.equals("peer")) {
          save(algorithm + ".peer.wrapped", wrap(handle, master, KEYSET_AAD));
          save(algorithm + ".peer.empty-aad", wrap(handle, master, new byte[0]));
        }
        if (algorithm.startsWith("AES256_")) {
          exerciseEncryption(algorithm, handle);
        } else {
          exerciseMac(algorithm, handle);
        }
      }
      System.out.println("{\"schema\":\"bil.qa.tink.jvm.phase.v1\",\"phase\":\"" + phase
          + "\",\"tink_version\":\"" + args[2] + "\",\"passed\":" + passed
          + ",\"failed\":0,\"constant_time_measured\":false}");
    } catch (Exception error) {
      // Exception messages, keysets, ciphertexts and keys never enter the public evidence log.
      System.err.println("TINK_QA_FAILED phase=" + phase + " case=" + active
          + " type=" + error.getClass().getSimpleName() + " passed=" + passed);
      System.exit(1);
    }
  }

  private static void exerciseEncryption(String algorithm, KeysetHandle handle) throws Exception {
    Aead aead = algorithm.equals("AES256_GCM")
        ? handle.getPrimitive(RegistryConfiguration.get(), Aead.class) : null;
    DeterministicAead siv = algorithm.equals("AES256_SIV")
        ? handle.getPrimitive(RegistryConfiguration.get(), DeterministicAead.class) : null;
    for (int v = 0; v < VALUES.length; v++) {
      for (int a = 0; a < AADS.length; a++) {
        active = algorithm + "-value" + v + "-aad" + a;
        byte[] value = VALUES[v];
        byte[] aad = AADS[a];
        String name = algorithm + "-v" + v + "-a" + a;
        byte[] cipher;
        if (phase.equals("create")) {
          cipher = encrypt(aead, siv, value, aad);
          save(name + ".origin", cipher);
        } else {
          cipher = read(name + (phase.equals("peer") ? ".origin" : ".peer"));
        }
        check(Arrays.equals(value, decrypt(aead, siv, cipher, aad)));
        byte[] damaged = flip(cipher);
        reject(() -> decrypt(aead, siv, damaged, aad));
        reject(() -> decrypt(aead, siv, cipher, utf8("different-associated-data")));
        if (siv != null) {
          check(Arrays.equals(cipher, encrypt(aead, siv, value, aad)));
        }
        if (phase.equals("peer")) {
          byte[] written = encrypt(aead, siv, value, aad);
          save(name + ".peer", written);
          check(Arrays.equals(value, decrypt(aead, siv, written, aad)));
        }
      }
    }
  }

  private static void exerciseMac(String algorithm, KeysetHandle handle) throws Exception {
    Mac mac = handle.getPrimitive(RegistryConfiguration.get(), Mac.class);
    ChunkedMac chunked = handle.getPrimitive(RegistryConfiguration.get(), ChunkedMac.class);
    for (int v = 0; v < VALUES.length; v++) {
      active = algorithm + "-value" + v;
      byte[] value = VALUES[v];
      String name = algorithm + "-v" + v;
      byte[] tag;
      if (phase.equals("create")) {
        tag = mac.computeMac(value);
        save(name + ".origin", tag);
      } else {
        tag = read(name + (phase.equals("peer") ? ".origin" : ".peer"));
      }
      mac.verifyMac(tag, value);
      check(true);
      verifyChunked(chunked, tag, value);
      check(true);
      check(Arrays.equals(tag, computeChunked(chunked, value)));
      byte[] damaged = flip(tag);
      reject(() -> mac.verifyMac(damaged, value));
      reject(() -> verifyChunked(chunked, damaged, value));
      byte[] different = Arrays.copyOf(value, value.length + 1);
      different[different.length - 1] = 42;
      reject(() -> verifyChunked(chunked, tag, different));
      if (phase.equals("peer")) {
        byte[] written = mac.computeMac(value);
        check(Arrays.equals(tag, written));
        save(name + ".peer", written);
      }
    }
  }

  private static byte[] computeChunked(ChunkedMac mac, byte[] value) throws Exception {
    ChunkedMacComputation computation = mac.createComputation();
    int split = value.length / 2;
    computation.update(ByteBuffer.wrap(value, 0, split));
    computation.update(ByteBuffer.wrap(value, split, value.length - split));
    return computation.computeMac();
  }

  private static void verifyChunked(ChunkedMac mac, byte[] tag, byte[] value) throws Exception {
    ChunkedMacVerification verification = mac.createVerification(tag);
    int split = value.length / 2;
    verification.update(ByteBuffer.wrap(value, 0, split));
    verification.update(ByteBuffer.wrap(value, split, value.length - split));
    verification.verifyMac();
  }

  private static byte[] encrypt(Aead aead, DeterministicAead siv, byte[] value, byte[] aad)
      throws Exception {
    return aead != null ? aead.encrypt(value, aad) : siv.encryptDeterministically(value, aad);
  }

  private static byte[] decrypt(Aead aead, DeterministicAead siv, byte[] value, byte[] aad)
      throws Exception {
    return aead != null ? aead.decrypt(value, aad) : siv.decryptDeterministically(value, aad);
  }

  private static byte[] serialize(KeysetHandle handle) throws Exception {
    ByteArrayOutputStream output = new ByteArrayOutputStream();
    CleartextKeysetHandle.write(handle, BinaryKeysetWriter.withOutputStream(output));
    return output.toByteArray();
  }

  private static KeysetHandle raw(byte[] data) throws Exception {
    return CleartextKeysetHandle.read(BinaryKeysetReader.withBytes(data));
  }

  private static byte[] wrap(KeysetHandle handle, Aead master, byte[] aad) throws Exception {
    ByteArrayOutputStream output = new ByteArrayOutputStream();
    handle.writeWithAssociatedData(BinaryKeysetWriter.withOutputStream(output), master, aad);
    return output.toByteArray();
  }

  private static KeysetHandle unwrap(byte[] data, Aead master, byte[] aad) throws Exception {
    return KeysetHandle.readWithAssociatedData(BinaryKeysetReader.withBytes(data), master, aad);
  }

  private static byte[] tamperWrapped(byte[] wrapped) throws Exception {
    byte[] cipher = BinaryKeysetReader.withBytes(wrapped).readEncrypted()
        .getEncryptedKeyset().toByteArray();
    for (int offset = 0; offset <= wrapped.length - cipher.length; offset++) {
      if (Arrays.equals(cipher, Arrays.copyOfRange(wrapped, offset, offset + cipher.length))) {
        byte[] damaged = wrapped.clone();
        damaged[offset + cipher.length / 2] ^= 1;
        return damaged;
      }
    }
    throw new IllegalStateException();
  }

  private static void reject(Action action) throws Exception {
    try {
      action.run();
    } catch (GeneralSecurityException expected) {
      passed++;
      return;
    }
    throw new IllegalStateException();
  }

  private static void check(boolean condition) {
    if (!condition) {
      throw new IllegalStateException();
    }
    passed++;
  }

  private static byte[] flip(byte[] data) {
    byte[] damaged = data.clone();
    damaged[damaged.length - 1] ^= 1;
    return damaged;
  }

  private static Path file(String name) {
    Path target = root.resolve(name).normalize();
    if (!target.getParent().equals(root) || Files.isSymbolicLink(target)) {
      throw new SecurityException();
    }
    return target;
  }

  private static void save(String name, byte[] data) throws Exception {
    Path target = file(name);
    if (Files.exists(target, LinkOption.NOFOLLOW_LINKS)) {
      throw new SecurityException();
    }
    Files.write(target, data);
  }

  private static byte[] read(String name) throws Exception {
    return Files.readAllBytes(file(name));
  }

  private static byte[] utf8(String text) {
    return text.getBytes(StandardCharsets.UTF_8);
  }
}
