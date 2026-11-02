import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

enum WhatsAppConnectionState {
  offline, // Local server is offline or unreachable
  starting, // Server is starting / connecting socket
  pairing, // QR code ready to be scanned by phone
  authenticated, // QR code scanned, loading chats
  connected, // Fully connected and ready to send bills
}

class WhatsAppService {
  static final WhatsAppService instance = WhatsAppService._internal();

  factory WhatsAppService() => instance;

  WhatsAppService._internal();

  static const String serverUrl = 'http://127.0.0.1:3333';

  final ValueNotifier<WhatsAppConnectionState> state =
      ValueNotifier<WhatsAppConnectionState>(WhatsAppConnectionState.offline);
  final ValueNotifier<String?> qrCode = ValueNotifier<String?>(null);
  final ValueNotifier<String?> connectedPhone = ValueNotifier<String?>(null);
  final ValueNotifier<String?> connectedName = ValueNotifier<String?>(null);
  final ValueNotifier<String> statusMessage =
      ValueNotifier<String>('WhatsApp service offline');

  io.Socket? _socket;
  Process? _nodeProcess;
  Timer? _healthCheckTimer;
  bool _isInitializing = false;

  /// Initialize service on Windows startup
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) return;
    if (_isInitializing) return;
    _isInitializing = true;

    _log('Initializing WhatsAppService...');
    await _ensureServerRunning();
    _connectSocket();

    // Start periodic health check every 15 seconds
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkStatus();
    });

    _isInitializing = false;
  }

  /// Check if the local Node.js server is already responding
  Future<bool> isServerResponding() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/status'))
          .timeout(const Duration(milliseconds: 1500));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ensure Node server process is running
  Future<void> _ensureServerRunning() async {
    final responding = await isServerResponding();
    if (responding) {
      _log('Node server is already running and responding.');
      state.value = WhatsAppConnectionState.starting;
      statusMessage.value = 'Connecting to background service...';
      return;
    }

    _log('Node server not responding. Starting node process...');
    state.value = WhatsAppConnectionState.starting;
    statusMessage.value = 'Starting WhatsApp background service...';
    await _startNodeProcess();
  }

  /// Start the node process directly
  Future<void> _startNodeProcess() async {
    try {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      
      // Determine node.exe path
      String nodeExe = '$appDir\\node.exe';
      if (!File(nodeExe).existsSync()) {
        // Fallback for development mode
        final devNode = '${Directory.current.path}\\node.exe';
        if (File(devNode).existsSync()) {
          nodeExe = devNode;
        } else {
          nodeExe = 'node';
        }
      }

      // Determine server working directory and script
      String serverDir = '$appDir\\whatsapp_server';
      if (!Directory(serverDir).existsSync()) {
        serverDir = '${Directory.current.path}\\whatsapp_server';
      }

      final scriptFile = '$serverDir\\server.js';
      _log('Launching Node process: $nodeExe $scriptFile in $serverDir');

      _nodeProcess = await Process.start(
        nodeExe,
        ['server.js', '--parent-pid', pid.toString()],
        workingDirectory: serverDir,
        runInShell: false,
      );

      _nodeProcess?.stdout.transform(utf8.decoder).listen((data) {
        _log('[Node stdout] $data');
      });

      _nodeProcess?.stderr.transform(utf8.decoder).listen((data) {
        _log('[Node stderr] $data');
      });

      _nodeProcess?.exitCode.then((code) {
        _log('Node process exited with code $code');
        if (state.value != WhatsAppConnectionState.offline) {
          state.value = WhatsAppConnectionState.offline;
          statusMessage.value = 'WhatsApp server stopped';
        }
      });

      _log('Node process started successfully with PID: ${_nodeProcess?.pid}');

      // Wait briefly for server to bind port
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await isServerResponding()) {
          _log('Server responded after ${(i + 1) * 500}ms');
          break;
        }
      }
    } catch (e) {
      _log('Error starting node process: $e');
      state.value = WhatsAppConnectionState.offline;
      statusMessage.value = 'Failed to start WhatsApp server';
    }
  }

  /// Connect or reconnect Socket.IO
  void _connectSocket() {
    _socket?.dispose();

    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.onConnect((_) {
      _log('Connected to WhatsApp server socket');
      checkStatus();
    });

    _socket?.on('status', (data) {
      final msg = data is Map ? (data['status'] ?? '') : data.toString();
      _log('Socket status: $msg');
      statusMessage.value = msg;
    });

    _socket?.on('qr_code', (data) {
      _log('Socket received QR code');
      if (data is Map && data['qr'] != null) {
        qrCode.value = data['qr'].toString();
        state.value = WhatsAppConnectionState.pairing;
        statusMessage.value = 'Scan QR code with WhatsApp';
      }
    });

    _socket?.on('authenticated', (data) {
      _log('Socket received authenticated');
      qrCode.value = null;
      state.value = WhatsAppConnectionState.authenticated;
      statusMessage.value = 'Authenticated! Loading chats...';
    });

    _socket?.on('ready', (data) {
      _log('Socket received ready');
      qrCode.value = null;
      state.value = WhatsAppConnectionState.connected;
      statusMessage.value = 'Connected';
      if (data is Map) {
        connectedPhone.value = data['phone']?.toString();
        connectedName.value = data['name']?.toString();
      }
    });

    _socket?.on('disconnected', (data) {
      _log('Socket received disconnected');
      state.value = WhatsAppConnectionState.starting;
      qrCode.value = null;
      statusMessage.value = 'Reconnecting WhatsApp...';
    });

    _socket?.onConnectError((err) {
      _log('Socket connect error: $err');
      if (state.value != WhatsAppConnectionState.connected) {
        state.value = WhatsAppConnectionState.offline;
        statusMessage.value = 'Server offline. Click Connect to start.';
      }
    });

    _socket?.onDisconnect((_) {
      _log('Socket disconnected');
      if (state.value != WhatsAppConnectionState.offline) {
        state.value = WhatsAppConnectionState.offline;
        statusMessage.value = 'Disconnected from server';
      }
    });

    _socket?.connect();
  }

  /// Query server status via REST API
  Future<void> checkStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$serverUrl/api/status'))
          .timeout(const Duration(milliseconds: 2000));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final bool ready = data['ready'] == true;
        final String? qr = data['qr']?.toString();
        final String? phone = data['phone']?.toString();
        final String? name = data['name']?.toString();

        connectedPhone.value = phone;
        connectedName.value = name;

        if (ready) {
          state.value = WhatsAppConnectionState.connected;
          statusMessage.value = 'Connected';
          qrCode.value = null;
        } else if (qr != null && qr.isNotEmpty) {
          state.value = WhatsAppConnectionState.pairing;
          qrCode.value = qr;
          statusMessage.value = 'Scan QR code with WhatsApp';
        } else {
          state.value = WhatsAppConnectionState.starting;
          statusMessage.value = 'Initializing WhatsApp...';
        }
      }
    } catch (_) {
      // If server is not responding, mark offline
      if (state.value != WhatsAppConnectionState.starting) {
        state.value = WhatsAppConnectionState.offline;
        statusMessage.value = 'Server offline';
      }
    }
  }

  /// Restart the entire WhatsApp server & client
  Future<void> restartService() async {
    _log('Restarting WhatsApp service requested');
    state.value = WhatsAppConnectionState.starting;
    statusMessage.value = 'Restarting WhatsApp service...';
    qrCode.value = null;

    try {
      // If server is alive, tell it to restart client
      final responding = await isServerResponding();
      if (responding) {
        await http
            .post(Uri.parse('$serverUrl/api/restart'))
            .timeout(const Duration(seconds: 3));
      } else {
        // Kill existing process and restart
        _nodeProcess?.kill();
        await Future.delayed(const Duration(milliseconds: 500));
        await _startNodeProcess();
      }
    } catch (_) {
      _nodeProcess?.kill();
      await Future.delayed(const Duration(milliseconds: 500));
      await _startNodeProcess();
    }

    _connectSocket();
    await checkStatus();
  }

  /// Logout and clear credentials
  Future<bool> logout() async {
    try {
      final res = await http
          .post(Uri.parse('$serverUrl/api/logout'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        state.value = WhatsAppConnectionState.starting;
        connectedPhone.value = null;
        connectedName.value = null;
        qrCode.value = null;
        statusMessage.value = 'Logged out. Preparing new QR...';
        return true;
      }
    } catch (e) {
      _log('Logout error: $e');
    }
    return false;
  }

  /// Kill the server on application close
  void killServer() {
    _healthCheckTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    if (_nodeProcess != null) {
      _log('Killing WhatsApp Node process PID: ${_nodeProcess?.pid}');
      _nodeProcess?.kill();
      _nodeProcess = null;
    }
  }

  void _log(String message) {
    debugPrint('[WhatsAppService] $message');
    try {
      final appData = Platform.environment['APPDATA'] ?? '';
      if (appData.isNotEmpty) {
        final logDir = Directory('$appData${Platform.pathSeparator}Smart Entry');
        if (!logDir.existsSync()) {
          logDir.createSync(recursive: true);
        }
        final logFile = File('${logDir.path}${Platform.pathSeparator}node_launcher.log');
        if (logFile.existsSync() && logFile.lengthSync() > 2 * 1024 * 1024) {
          logFile.writeAsStringSync('');
        }
        final time = DateTime.now().toIso8601String();
        logFile.writeAsStringSync('[$time] $message\n', mode: FileMode.append);
      }
    } catch (_) {}
  }
}
