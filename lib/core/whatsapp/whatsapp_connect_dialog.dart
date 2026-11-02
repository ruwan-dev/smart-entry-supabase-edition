import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'whatsapp_service.dart';

class WhatsAppConnectDialog extends StatefulWidget {
  const WhatsAppConnectDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const WhatsAppConnectDialog(),
    );
  }

  @override
  State<WhatsAppConnectDialog> createState() => _WhatsAppConnectDialogState();
}

class _WhatsAppConnectDialogState extends State<WhatsAppConnectDialog> {
  final WhatsAppService _service = WhatsAppService.instance;
  bool _isRestarting = false;

  @override
  void initState() {
    super.initState();
    // Refresh status when dialog opens
    if (!kIsWeb && Platform.isWindows) {
      _service.checkStatus();
    }
  }

  Future<void> _handleRestart() async {
    setState(() => _isRestarting = true);
    await _service.restartService();
    if (mounted) {
      setState(() => _isRestarting = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect WhatsApp?'),
        content: const Text(
          'Are you sure you want to unlink your WhatsApp account? You will need to scan the QR code again to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 12,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: ValueListenableBuilder<WhatsAppConnectionState>(
            valueListenable: _service.state,
            builder: (context, state, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Color(0xFF25D366),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WhatsApp Service',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            ValueListenableBuilder<String>(
                              valueListenable: _service.statusMessage,
                              builder: (_, msg, __) => Text(
                                msg,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // State-dependent Content
                  if (_isRestarting) ...[
                    _buildLoadingView('Restarting WhatsApp service...'),
                  ] else if (state == WhatsAppConnectionState.connected) ...[
                    _buildConnectedView(),
                  ] else if (state == WhatsAppConnectionState.pairing) ...[
                    _buildPairingView(),
                  ] else if (state == WhatsAppConnectionState.authenticated) ...[
                    _buildLoadingView('Authenticated! Syncing chats...'),
                  ] else ...[
                    _buildOfflineOrStartingView(state),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (state == WhatsAppConnectionState.connected) ...[
                        OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                          label: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: _isRestarting ? null : _handleRestart,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Restart'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedView() {
    return ValueListenableBuilder<String?>(
      valueListenable: _service.connectedPhone,
      builder: (context, phone, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 54,
              ),
              const SizedBox(height: 12),
              const Text(
                'WhatsApp is Connected!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 6),
              if (phone != null && phone.isNotEmpty) ...[
                Text(
                  '+$phone',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Ready to automatically send monthly invoices and tea collection receipts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPairingView() {
    return ValueListenableBuilder<String?>(
      valueListenable: _service.qrCode,
      builder: (context, qr, _) {
        if (qr == null || qr.isEmpty) {
          return _buildLoadingView('Generating QR code...');
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: qr,
                version: QrVersions.auto,
                size: 210.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To link your WhatsApp:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 4),
                  _stepRow('1', 'Open WhatsApp on your phone'),
                  _stepRow('2', 'Tap Menu (⋮) or Settings > Linked Devices'),
                  _stepRow('3', 'Tap Link a Device and point phone to this code'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$num. ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
        ],
      ),
    );
  }

  Widget _buildLoadingView(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF25D366),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineOrStartingView(WhatsAppConnectionState state) {
    final isStarting = state == WhatsAppConnectionState.starting;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isStarting ? const Color(0xFFF0F9FF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStarting ? const Color(0xFFBAE6FD) : const Color(0xFFFFEDD5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isStarting ? Icons.sync_rounded : Icons.signal_cellular_connected_no_internet_4_bar_rounded,
            color: isStarting ? const Color(0xFF0284C7) : const Color(0xFFEA580C),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            isStarting ? 'Starting WhatsApp Background Service...' : 'WhatsApp Service Offline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isStarting ? const Color(0xFF0369A1) : const Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isStarting
                ? 'Initializing browser engine and local socket. This takes only a few seconds.'
                : 'Click "Start Service" below to launch the background WhatsApp connection.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isStarting ? const Color(0xFF0284C7) : const Color(0xFFC2410C),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _handleRestart,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(isStarting ? 'Restart Service' : 'Start Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
