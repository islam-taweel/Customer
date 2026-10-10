import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import '../models/debt_transaction.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final _db = DatabaseHelper.instance;

  double _balance = 0;
  List<DebtTransaction> _transactions = [];
  bool _loading = true;

  int get _customerId => widget.customer.id!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final balance = await _db.getCustomerBalance(_customerId);
    final txs = await _db.getTransactions(_customerId);
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _transactions = txs;
      _loading = false;
    });
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _showTransactionDialog(TransactionType type) async {
    final tx = await showDialog<DebtTransaction>(
      context: context,
      builder: (_) => _TransactionDialog(type: type, customerId: _customerId),
    );

    if (tx != null) {
      await _db.insertTransaction(tx);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDebt = _balance > 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.customer.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // بطاقة الرصيد
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      if (widget.customer.phone.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text(widget.customer.phone),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Text('الرصيد', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        _balance.toStringAsFixed(2),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasDebt
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // زرّا الدين والدفعة
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () =>
                              _showTransactionDialog(TransactionType.debt),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة دين'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () =>
                              _showTransactionDialog(TransactionType.payment),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('إضافة دفعة'),
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'المعاملات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // قائمة المعاملات (الأحدث أولاً)
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('لا توجد معاملات بعد'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _transactions.length,
                          itemBuilder: (context, i) {
                            final t = _transactions[i];
                            final isDebt = t.type == TransactionType.debt;
                            final color = isDebt
                                ? Colors.red.shade700
                                : Colors.green.shade700;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.12),
                                  child: Icon(
                                    isDebt
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: color,
                                  ),
                                ),
                                title: Text(isDebt ? 'دين' : 'دفعة'),
                                subtitle: Text(
                                  t.note.isEmpty
                                      ? _formatDate(t.date)
                                      : '${t.note}\n${_formatDate(t.date)}',
                                ),
                                isThreeLine: t.note.isNotEmpty,
                                trailing: Text(
                                  '${isDebt ? '+' : '-'}${t.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: color,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}


/// نافذة إضافة دين/دفعة. تملك الـ controllers وتتخلص منها في dispose()
/// بعد انتهاء حركة الإغلاق لتجنب خطأ "wrong build scope".
class _TransactionDialog extends StatefulWidget {
  final TransactionType type;
  final int customerId;
  const _TransactionDialog({required this.type, required this.customerId});

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isDebt => widget.type == TransactionType.debt;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// تحويل الأرقام العربية/الهندية إلى إنجليزية ليقبلها double.parse
  double? _parseAmount(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var s = input.trim().replaceAll('٫', '.').replaceAll(',', '.');
    for (var i = 0; i < arabic.length; i++) {
      s = s.replaceAll(arabic[i], '$i');
    }
    return double.tryParse(s);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      DebtTransaction(
        customerId: widget.customerId,
        type: widget.type,
        amount: _parseAmount(_amountCtrl.text)!,
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isDebt ? 'إضافة دين' : 'إضافة دفعة'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _isDebt ? 'المبلغ المستحق' : 'المبلغ المدفوع',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              validator: (v) {
                final value = _parseAmount(v ?? '');
                if (value == null || value <= 0) {
                  return 'الرجاء إدخال مبلغ صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}