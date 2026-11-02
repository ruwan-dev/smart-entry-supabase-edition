import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class UpdateService {
  static const String _versionRowId = 'windows';
  static const String _dismissedKey = 'last_dismissed_update_version';

  /// Compares two semantic version strings like "1.2.0" vs "1.0.0".
  /// Returns true if [remote] is strictly newer than [current].
  static bool _isNewerVersion(String current, String remote) {
    try {
      final c = current.trim().split('.').map(int.parse).toList();
      final r = remote.trim().split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final cv = i < c.length ? c[i] : 0;
        final rv = i < r.length ? r[i] : 0;
        if (rv > cv) return true;
        if (rv < cv) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Gets the currently installed version string (e.g., '1.0.0').
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Call this once after the user logs in (from DashboardScreen.initState)
  /// or manually from Settings.
  /// If [showFeedbackIfUpToDate] is true, shows feedback if already up to date.
  /// Safe to call on Android/Web — exits gracefully.
  static Future<void> checkForUpdate(BuildContext context, {bool showFeedbackIfUpToDate = false}) async {
    // Only run on Windows Desktop, never on Android or Web
    if (kIsWeb || !Platform.isWindows) {
      if (showFeedbackIfUpToDate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-updates are supported on Windows Desktop.')),
        );
      }
      return;
    }

    try {
      // 1. Read current installed version from the app bundle
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.0.0"

      // 2. Fetch the latest version record from Supabase
      final response = await Supabase.instance.client
          .from('app_versions')
          .select()
          .eq('id', _versionRowId)
          .maybeSingle();

      if (response == null) {
        if (showFeedbackIfUpToDate && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No update information found on server.')),
          );
        }
        return;
      }

      final latestVersion = (response['version'] as String?) ?? '';
      final downloadUrl   = (response['download_url'] as String?) ?? '';
      final releaseNotes  = (response['release_notes'] as String?) ?? '';
      final isMandatory   = (response['is_mandatory'] as bool?) ?? false;

      debugPrint('[UpdateService] Installed: $currentVersion | Latest: $latestVersion');

      if (latestVersion.isEmpty || downloadUrl.isEmpty || !_isNewerVersion(currentVersion, latestVersion)) {
        if (showFeedbackIfUpToDate && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Smart Entry is up to date (v$currentVersion)'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        return;
      }

      // 3. Check if user already dismissed or postponed this specific version
      if (!isMandatory && !showFeedbackIfUpToDate) {
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getString(_dismissedKey);
        if (dismissed == latestVersion) {
          debugPrint('[UpdateService] Update v$latestVersion was already dismissed. Skipping popup.');
          return;
        }
      }

      // 4. A newer version exists — show the update dialog
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: !isMandatory,
          builder: (_) => _UpdateDialog(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            isMandatory: isMandatory,
          ),
        );
      }
    } catch (e) {
      debugPrint('[UpdateService] Check failed (non-critical): $e');
      if (showFeedbackIfUpToDate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update check error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Clears the dismissed version so the user can be prompted again
  static Future<void> resetDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Update Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  const _UpdateDialog({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Stage _stage = _Stage.prompt;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorText;

  static const Color _primary = Color(0xFF1976D2);

  Future<void> _dismiss() async {
    // Save to SharedPreferences so it doesn't ask again on every restart!
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UpdateService._dismissedKey, widget.latestVersion);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _stage = _Stage.downloading;
      _statusText = 'Connecting to update server…';
      _progress = 0.0;
      _errorText = null;
    });

    try {
      // 1. Download installer file
      final tempDir = await getTemporaryDirectory();
      final uri = Uri.parse(widget.downloadUrl);
      final isExe = uri.path.toLowerCase().endsWith('.exe');
      final fileName = isExe ? 'smart_entry_update.exe' : 'smart_entry_update.msix';
      final filePath = '${tempDir.path}\\$fileName';
      final file = File(filePath);
      if (file.existsSync()) file.deleteSync();

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'HTTP ${streamedResponse.statusCode} (${streamedResponse.reasonPhrase}).\n'
          'The installer file is not yet available at the download URL.',
        );
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = file.openWrite();

      setState(() => _statusText = 'Downloading update…');

      await streamedResponse.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _progress = receivedBytes / totalBytes);
        }
      }).asFuture();

      await sink.close();
      client.close();

      // Check downloaded file size
      if (!file.existsSync() || file.lengthSync() < 1024) {
        throw Exception('Downloaded file is invalid or empty.');
      }

      // 2. Install installer (supports both .msix and .exe)
      if (mounted) setState(() => _statusText = 'Installing update… App will restart.');

      if (isExe) {
        // Launch Inno Setup / EXE installer in detached mode
        await Process.start(
          filePath,
          ['/SILENT', '/NORESTART'],
          mode: ProcessStartMode.detached,
        );
      } else {
        // Install MSIX Package via PowerShell
        final result = await Process.run(
          'powershell',
          [
            '-ExecutionPolicy', 'Bypass',
            '-Command',
            'Add-AppxPackage -Path "$filePath" -ForceApplicationShutdown',
          ],
        );

        if (result.exitCode != 0) {
          String err = result.stderr.toString().trim();
          if (err.isEmpty) err = result.stdout.toString().trim();
          throw Exception(
            'Installation error: $err\n\n'
            '(Note: If testing in development mode, install the MSIX package first).',
          );
        }
      }

      // Save version so it never prompts again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(UpdateService._dismissedKey, widget.latestVersion);

      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    } catch (e) {
      debugPrint('[UpdateService] Install error: $e');
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _errorText = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_alt_rounded, color: _primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Update Available',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Version pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.currentVersion,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: _primary),
                  ),
                  Text(
                    widget.latestVersion,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Release notes
            if (widget.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "What's new:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  widget.releaseNotes,
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade700, height: 1.5),
                ),
              ),
            ],

            // Mandatory badge
            if (widget.isMandatory) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'This update is required to continue.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],

            // Progress section
            if (_stage == _Stage.downloading) ...[
              const SizedBox(height: 20),
              Text(_statusText, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey.shade200,
                  color: _primary,
                  minHeight: 6,
                ),
              ),
              if (_progress > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],

            // Error section
            if (_stage == _Stage.error && _errorText != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        if (!widget.isMandatory && _stage != _Stage.downloading)
          TextButton(
            onPressed: _dismiss,
            child: const Text('Later', style: TextStyle(color: Colors.blueGrey)),
          ),
        if (_stage != _Stage.downloading)
          ElevatedButton.icon(
            onPressed: _downloadAndInstall,
            icon: Icon(
              _stage == _Stage.error ? Icons.refresh_rounded : Icons.download_rounded,
              size: 18,
            ),
            label: Text(_stage == _Stage.error ? 'Retry' : 'Update Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
      ],
    );
  }
}

enum _Stage { prompt, downloading, error }
