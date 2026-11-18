import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Dialog untuk menambahkan catatan khusus pesanan resto (Modifiers).
class CustomNotesDialog extends StatefulWidget {
  final String productName;
  final String initialNotes;

  const CustomNotesDialog({
    super.key,
    required this.productName,
    this.initialNotes = '',
  });

  @override
  State<CustomNotesDialog> createState() => _CustomNotesDialogState();
}

class _CustomNotesDialogState extends State<CustomNotesDialog> {
  late final TextEditingController _controller;

  // Catatan cepat favorit pelanggan resto
  final List<String> _quickNotes = [
    'Pedas Sedang',
    'Pedas Banget',
    'Tidak Pedas',
    'Pisah Kuah / Sambal',
    'Sedikit Minyak',
    'Tanpa MSG',
    'Nasi Setengah',
    'Es Batu Sedikit',
    'Tanpa Es (Hangat)',
    'Gula Sedikit',
    'Bungkus (Take Away)',
    'Makan di Tempat (Dine In)',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addQuickNote(String note) {
    if (_controller.text.isEmpty) {
      _controller.text = note;
    } else {
      if (!_controller.text.contains(note)) {
        _controller.text = '${_controller.text}, $note';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note, color: AppTheme.primaryCoffee, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Catatan: ${widget.productName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Contoh: Manis sedikit, es banyak...',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilihan Cepat Resto:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickNotes.map((note) {
                return ActionChip(
                  label: Text(note, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.brown.shade50,
                  side: BorderSide(color: Colors.brown.shade200),
                  onPressed: () => _addQuickNote(note),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Simpan Catatan'),
        ),
      ],
    );
  }
}
