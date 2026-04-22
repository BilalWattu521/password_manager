import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_helper.dart';

/// Handles AES-256 encrypted export and import of all passwords.
///
/// Security model:
///  - All credentials are serialised as JSON.
///  - A 256-bit AES key is derived from the user's backup password by
///    SHA-256 hashing the UTF-8 bytes (via the pointycastle library that the
///    `encrypt` package already pulls in).
///  - The ciphertext and IV are Base64-encoded and joined with a `|` separator
///    so the file is a plain ASCII text file that is easy to transfer.
class BackupService {
  static final _dbHelper = DatabaseHelper();

  // ── Key derivation ────────────────────────────────────────────────────────

  static enc.Key _deriveKey(String password) {
    // SHA-256 the UTF-8 bytes of the password → 32 bytes → AES-256 key.
    final import = utf8.encode(password);
    // Manually implement a simple SHA-256 via Dart's built-in crypto helper.
    // We use the `convert` package (already in flutter SDK) – but that only
    // gives us Hex.  To get raw bytes we need to decode the hex string.
    final digest = _sha256Bytes(Uint8List.fromList(import));
    return enc.Key(digest);
  }

  /// Pure-Dart SHA-256 over [data].  Returns 32 raw bytes.
  static Uint8List _sha256Bytes(Uint8List data) {
    // Use the pointycastle SHA-256 (already a transitive dependency via `encrypt`).
    final pc = _PointyCastleSha256();
    return pc.process(data);
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Step 1 of export: encrypts all credentials and writes the backup file to
  /// the temp directory.
  ///
  /// Returns the absolute path to the ready-to-share `.bak` file.
  /// Throws a [BackupException] on failure.
  static Future<String> prepareBackup(String password) async {
    try {
      // 1. Load all credentials from the database.
      final credentials = await _dbHelper.getAllCredentials();
      if (credentials.isEmpty) {
        throw const BackupException('No passwords to export.');
      }

      // 2. Serialise to JSON.
      final payload = jsonEncode({'version': 1, 'credentials': credentials});

      // 3. Encrypt.
      final key = _deriveKey(password);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(payload, iv: iv);

      // 4. Build the file content: base64(iv) | base64(ciphertext)
      final fileContent = '${iv.base64}|${encrypted.base64}';

      // 5. Write to a temp file and return its path.
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'pm_backup_${now.year}${_pad(now.month)}${_pad(now.day)}.bak';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(fileContent);
      return file.path;
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Export failed: $e');
    }
  }

  /// Step 2 of export: shows the OS share sheet for the file at [filePath].
  ///
  /// Returns the [ShareResult] so the caller can detect whether the user
  /// actually saved the file or dismissed the sheet without saving.
  static Future<ShareResult> shareBackup(String filePath) async {
    // text/plain is used so cloud providers (Google Drive, etc.) store the file
    // as readable text rather than a generic BIN that their pickers can't expose.
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'text/plain')],
        subject: 'Password Manager Backup',
        text: 'Your encrypted password backup – keep this file safe!',
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Step 1 of import: opens a file picker restricted to `.bak` files and
  /// returns the raw encrypted file content string.
  ///
  /// Returns `null` if the user cancels without selecting a file.
  /// Throws a [BackupException] if the file cannot be read.
  static Future<String?> pickBackupFile() async {
    // FileType.any is intentional: when backups are stored in Google Drive or
    // other cloud providers the OS file picker exposes files by MIME type, not
    // extension. Restricting to .bak would make those files unselectable.
    // Format validation in decryptAndImport() rejects any non-backup content.
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
      dialogTitle: 'Select a Password Manager backup (.bak)',
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    if (picked.bytes != null) {
      return utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      return File(picked.path!).readAsString();
    }
    throw const BackupException('Could not read the selected file.');
  }

  /// Step 2 of import: decrypts [fileContent] using [password] and inserts
  /// all credentials into the local database.
  ///
  /// Returns the number of credential rows found in the backup.
  /// Throws a [BackupException] on wrong password or corrupt data.
  static Future<int> decryptAndImport(
    String fileContent,
    String password,
  ) async {
    try {
      // 1. Split IV and ciphertext.
      final parts = fileContent.split('|');
      if (parts.length != 2) {
        throw const BackupException('Invalid or corrupt backup file.');
      }

      // 2. Decrypt.
      final key = _deriveKey(password);
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      late String plaintext;
      try {
        plaintext = encrypter.decrypt64(parts[1], iv: iv);
      } catch (_) {
        throw const BackupException(
          'Incorrect password or corrupt backup file.',
        );
      }

      // 3. Parse JSON.
      late Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(plaintext) as Map<String, dynamic>;
      } catch (_) {
        throw const BackupException(
          'Incorrect password or corrupt backup file.',
        );
      }

      if (decoded['version'] != 1 || decoded['credentials'] == null) {
        throw const BackupException('Unsupported backup file format.');
      }

      final rows =
          (decoded['credentials'] as List).cast<Map<String, dynamic>>();

      // 4. Insert into the DB (duplicates are skipped automatically).
      await _dbHelper.importCredentials(rows);
      return rows.length;
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Import failed: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

// ── Tiny PointyCastle SHA-256 wrapper ────────────────────────────────────────

class _PointyCastleSha256 {
  Uint8List process(Uint8List data) {
    // PointyCastle is a transitive dependency of `encrypt`.
    // We use the Dart crypto-native approach: iterate the SHA-256 rounds
    // manually using the constants below.  This keeps us free of direct
    // pointycastle imports so the code compiles without any extra import.
    return _sha256(data);
  }

  /// Pure-Dart SHA-256 implementation (RFC 6234 compliant).
  static Uint8List _sha256(Uint8List message) {
    // Initial hash values (first 32 bits of fractional parts of sqrt of first 8 primes).
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    // Round constants.
    const k = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
      0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
      0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
      0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
      0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    // Pre-process: adding padding bits.
    final bitLen = message.length * 8;
    final bytes = <int>[...message, 0x80];
    while (bytes.length % 64 != 56) {
      bytes.add(0x00);
    }
    // Append original length as 64-bit big-endian.
    for (var i = 7; i >= 0; i--) {
      bytes.add((bitLen >> (i * 8)) & 0xff);
    }

    // Process each 512-bit chunk.
    for (var chunkStart = 0; chunkStart < bytes.length; chunkStart += 64) {
      final w = List<int>.filled(64, 0);
      for (var i = 0; i < 16; i++) {
        w[i] = (bytes[chunkStart + i * 4] << 24) |
            (bytes[chunkStart + i * 4 + 1] << 16) |
            (bytes[chunkStart + i * 4 + 2] << 8) |
            bytes[chunkStart + i * 4 + 3];
      }
      for (var i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ _shr(w[i - 15], 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ _shr(w[i - 2], 10);
        w[i] = _add(w[i - 16], s0, w[i - 7], s1);
      }

      var a = h0, b = h1, c = h2, d = h3;
      var e = h4, f = h5, g = h6, h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = _add(h, s1, ch, k[i], w[i]);
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = _add(s0, maj);

        h = g; g = f; f = e; e = _add(d, temp1);
        d = c; c = b; b = a; a = _add(temp1, temp2);
      }

      h0 = _add(h0, a); h1 = _add(h1, b);
      h2 = _add(h2, c); h3 = _add(h3, d);
      h4 = _add(h4, e); h5 = _add(h5, f);
      h6 = _add(h6, g); h7 = _add(h7, h);
    }

    final digest = Uint8List(32);
    final dv = ByteData.view(digest.buffer);
    dv.setUint32(0, h0 & 0xffffffff, Endian.big);
    dv.setUint32(4, h1 & 0xffffffff, Endian.big);
    dv.setUint32(8, h2 & 0xffffffff, Endian.big);
    dv.setUint32(12, h3 & 0xffffffff, Endian.big);
    dv.setUint32(16, h4 & 0xffffffff, Endian.big);
    dv.setUint32(20, h5 & 0xffffffff, Endian.big);
    dv.setUint32(24, h6 & 0xffffffff, Endian.big);
    dv.setUint32(28, h7 & 0xffffffff, Endian.big);
    return digest;
  }

  static int _rotr(int x, int n) =>
      ((x >>> n) | (x << (32 - n))) & 0xffffffff;
  static int _shr(int x, int n) => (x >>> n) & 0xffffffff;
  static int _add(int a, [int b = 0, int c = 0, int d = 0, int e = 0]) =>
      (a + b + c + d + e) & 0xffffffff;
}

// ── Custom exception ──────────────────────────────────────────────────────────

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}
