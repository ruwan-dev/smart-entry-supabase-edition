import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/app_state.dart';

class WhatsAppBatchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> bills;

  const WhatsAppBatchDialog({super.key, required this.bills});

  static Future<void> show(BuildContext context, List<Map<String, dynamic>> bills) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WhatsAppBatchDialog(bills: bills),
    );
  }

  @override
  State<WhatsAppBatchDialog> createState() => _WhatsAppBatchDialogState();
}

class _WhatsAppBatchDialogState extends State<WhatsAppBatchDialog> {
  late io.Socket socket;
  int current = 0;
  int total = 0;
  String status = "Connecting to background service...";
  bool isCompleted = false;
  bool isError = false;
  String? qrCodeData;
  bool isWhatsAppReady = false;
  bool batchStarted = false;

  @override
  void initState() {
    super.initState();
    total = widget.bills.length;
    _initSocket();
  }

  void _initSocket() {
    socket = io.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      if (mounted) {
        setState(() {
          status =
              "Connected to background service. Checking WhatsApp status...";
          isError = false;
        });
      }
    });

    socket.on('qr_code', (data) {
      if (mounted) {
        setState(() {
          qrCodeData = data['qr'];
          status = "Please scan the QR code using WhatsApp on your phone.";
          isWhatsAppReady = false;
        });
      }
    });

    socket.on('authenticated', (data) {
      if (mounted) {
        setState(() {
          qrCodeData = null;
          status = data['status'];
        });
      }
    });

    socket.on('ready', (data) {
      if (mounted) {
        setState(() {
          qrCodeData = null;
          isWhatsAppReady = true;
          status = "WhatsApp is ready. Starting to send bills...";
        });
        if (!batchStarted) {
          batchStarted = true;
          _startBatchRequest();
        }
      }
    });

    socket.on('message_sent', (data) async {
      if (data != null && data['success'] == true && data['id'] != null) {
        try {
          String billId = data['id'].toString();
          
          var response = await Supabase.instance.client
              .from('finalized_bills')
              .select('billData').eq('organization_id', AppState.currentOrganizationId.value ?? '')
              .eq('id', billId)
              .maybeSingle();

          if (response != null && response['billData'] != null) {
            Map<String, dynamic> billData = Map<String, dynamic>.from(response['billData'] as Map);
            billData['whatsapp_sent'] = true;

            await Supabase.instance.client
                .from('finalized_bills')
                .update({'billData': billData}).eq('organization_id', AppState.currentOrganizationId.value ?? '')
                .eq('id', billId);
          }
        } catch (e) {
          debugPrint("Error updating whatsapp_sent status: $e");
        }
      }
    });

    socket.on('progress', (data) {
      if (mounted) {
        setState(() {
          current = data['current'] as int;
          total = data['total'] as int;
          status = data['status'] as String;
        });
      }
    });

    socket.on('completed', (data) {
      if (mounted) {
        setState(() {
          status = data['status'] as String;
          current = total;
          isCompleted = true;
        });
        socket.disconnect();
      }
    });

    socket.on('disconnected', (data) {
      if (mounted) {
        setState(() {
          status = data['status'] as String;
          isWhatsAppReady = false;
          qrCodeData = null;
        });
      }
    });

    socket.onConnectError((_) {
      if (mounted && !isCompleted) {
        setState(() {
          status =
              "Failed to connect to local server. Make sure node server.js is running.";
          isError = true;
          // We don't mark completed yet, maybe they will start the server.
          // But allow closing the dialog to try again.
          isCompleted = true;
        });
      }
    });
  }

  Future<void> _startBatchRequest() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/batch-send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bills': widget.bills}),
      );

      if (response.statusCode != 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            status = "Error: ${decoded['error']}";
            isError = true;
            isCompleted = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          status = "Error sending data to server: $e";
          isError = true;
          isCompleted = true;
        });
      }
    }
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = total == 0 ? 0 : (current / total);

    return PopScope(
      canPop: isCompleted || isError,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCompleted && !isError ? 'Completed!' : 'WhatsApp Automation',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (qrCodeData != null) ...[
              const Text(
                "Link Device",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: qrCodeData!,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  status,
                  style: TextStyle(
                    color: isError ? Colors.red : Colors.blueGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isWhatsAppReady || batchStarted) ...[
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: Colors.grey.shade200,
                  color: isError ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$current / $total',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else if (!isError) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
              ],
            ],
          ],
        ),
        actions: [
          if (isCompleted || isError)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isError ? Colors.grey : Colors.green,
              ),
              child: Text(
                isError ? 'Close' : 'Done',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
