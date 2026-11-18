import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// Dialog untuk mencatat Kas Keluar Operasional (Petty Cash: es batu, galon, gas).
class PettyCashDialog extends StatefulWidget {
  final Function(int amount, String notes) onRecorded;

  const PettyCashDialog({super.key, required this.onRecorded});

  @override
  State<PettyCashDialog> createState() => _PettyCashDialogState();
}

class _PettyCashDialogState extends State<PettyCashDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Pilihan cepat pengeluaran umum operasional resto
  final List<Map<String, dynamic>> _quickExpenses = [
    {'notes': 'Beli Es Batu Bal-balan', 'amount': 10000},
    {'notes': 'Beli Air Galon Isi Ulang', 'amount': 6000},
    {'notes': 'Beli Gas Elpiji 3kg', 'amount': 22000},
    {'notes': 'Beli Minyak Goreng / Bumbu', 'amount': 15000},
    {'notes': 'Token Listrik Darurat', 'amount': 25000},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyQuickExpense(String notes, int amount) {
    setState(() {
      _notesController.text = notes;
      _amountController.text = amount.toString();
    });
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final notes = _notesController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pengeluaran harus lebih dari 0')),
      );
      return;
    }

    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keterangan pengeluaran wajib diisi')),
      );
      return;
    }

    widget.onRecorded(amount, notes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.outbox, color: AppTheme.dangerRed, size: 28),
          SizedBox(width: 8),
          Text(
            'Catat Kas Keluar (Petty Cash)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Nominal Pengeluaran Kas',
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Keperluan / Keterangan',
                  hintText: 'Contoh: Beli es batu 2 bal...',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pengeluaran Harian Populer:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickExpenses.map((exp) {
                  return ActionChip(
                    label: Text(
                      '${exp['notes']} (${_currencyFormat.format(exp['amount'])})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.red.shade50,
                    side: BorderSide(color: Colors.red.shade200),
                    onPressed: () => _applyQuickExpense(
                      exp['notes'] as String,
                      exp['amount'] as int,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
          icon: const Icon(Icons.save),
          label: const Text('Simpan Kas Keluar'),
        ),
      ],
    );
  }
}
