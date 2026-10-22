import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/platform_io_helper.dart';
import '../theme/app_theme.dart';

/// Dialog penampil foto bukti transfer ukuran penuh (bisa di-zoom)
void showTransferProofDialog(
  BuildContext context,
  String base64Image, {
  String title = 'Foto Bukti Transfer Bank',
  String? subtitle,
}) {
  Uint8List? bytes;
  try {
    final cleaned = base64Image.contains(',')
        ? base64Image.substring(base64Image.indexOf(',') + 1)
        : base64Image;
    bytes = base64Decode(cleaned);
  } catch (_) {}

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null && subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
          ],
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420, maxWidth: 360),
                child: InteractiveViewer(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.pastelPinkBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Gagal memuat pratinjau gambar bukti transfer.',
                style: TextStyle(fontSize: 12, color: AppTheme.dangerRed),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}

/// Widget Pemilih & Pratinjau Foto Bukti Transfer (Wajib Diisi Sebelum Konfirmasi)
class TransferProofPicker extends StatefulWidget {
  final String? initialBase64;
  final ValueChanged<String?> onChanged;
  final String label;

  const TransferProofPicker({
    super.key,
    this.initialBase64,
    required this.onChanged,
    this.label = 'Wajib Unggah Foto Bukti Transfer (Struk / Screenshot M-Banking)',
  });

  @override
  State<TransferProofPicker> createState() => _TransferProofPickerState();
}

class _TransferProofPickerState extends State<TransferProofPicker> {
  String? _base64Image;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _base64Image = widget.initialBase64;
  }

  Future<void> _pickPhoto() async {
    setState(() => _isLoading = true);
    try {
      final picked = await PlatformStorageHelper.pickImageAsBase64();
      if (picked != null && picked.isNotEmpty && mounted) {
        setState(() => _base64Image = picked);
        widget.onChanged(picked);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes;
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      try {
        final cleaned = _base64Image!.contains(',')
            ? _base64Image!.substring(_base64Image!.indexOf(',') + 1)
            : _base64Image!;
        previewBytes = base64Decode(cleaned);
      } catch (_) {}
    }

    final hasImage = previewBytes != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasImage ? AppTheme.pastelGreenBg : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasImage
              ? AppTheme.successGreen.withValues(alpha: 0.5)
              : AppTheme.warningOrange.withValues(alpha: 0.6),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasImage ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                size: 18,
                color: hasImage ? AppTheme.successGreen : AppTheme.warningOrange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasImage
                      ? '✅ Foto Bukti Transfer Sudah Dilampirkan'
                      : '📸 ${widget.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hasImage ? AppTheme.successGreen : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasImage) ...[
            GestureDetector(
              onTap: () => showTransferProofDialog(context, _base64Image!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  height: 140,
                  color: Colors.black12,
                  child: Image.memory(
                    previewBytes,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => showTransferProofDialog(context, _base64Image!),
                  icon: const Icon(Icons.zoom_in_rounded, size: 16),
                  label: const Text('Perbesar Foto', style: TextStyle(fontSize: 11.5)),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickPhoto,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Ganti Foto', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Tombol konfirmasi tidak dapat dilanjutkan sebelum Anda memilih foto struk / screenshot bukti transfer.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickPhoto,
                icon: _isLoading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Memuat Foto...' : 'Pilih Foto Bukti Transfer (Galeri / Kamera)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
