import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import 'customer_details_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Customer> _customers = [];
  double _totalDebts = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final customers = await _db.getCustomers(query: _searchController.text);
    final total = await _db.getTotalDebts();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _totalDebts = total;
      _loading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => const _AddCustomerDialog(),
    );

    if (customer != null) {
      await _db.insertCustomer(customer);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('العملاء')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة عميل'),
      ),
      body: Column(
        children: [
          // إجمالي الديون
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
                Text('إجمالي الديون', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  _totalDebts.toStringAsFixed(2),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),

          // البحث بالاسم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // قائمة العملاء
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('لا يوجد عملاء'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        itemCount: _customers.length,
                        itemBuilder: (context, i) {
                          final c = _customers[i];
                          final hasDebt = c.balance > 0;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(c.name.characters.first),
                              ),
                              title: Text(c.name),
                              subtitle: Text(c.phone),
                              trailing: Text(
                                c.balance.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: hasDebt
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerDetailsScreen(customer: c),
                                  ),
                                );
                                // تحديث الأرصدة وإجمالي الديون عند الرجوع
                                _load();
                              },
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

/// نافذة إضافة عميل.
/// هي StatefulWidget مستقلة كي تملك الـ controllers وتتخلص منها
/// في dispose() بعد انتهاء حركة إغلاق النافذة (هذا يحل خطأ
/// "Tried to build dirty widget in the wrong build scope").
class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog();

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // الاسم: حروف ومسافات فقط (عربي/إنجليزي)، بلا أرقام ولا رموز
  static final _nameAllowed = RegExp(r'[\p{L}\p{M}\s]', unicode: true);
  static final _nameFull = RegExp(r'^[\p{L}\p{M}\s]+$', unicode: true);

  // الهاتف: أرقام فقط (إنجليزية أو عربية)
  static final _phoneAllowed = RegExp(r'[0-9٠-٩]');
  static final _phoneFull = RegExp(r'^[0-9٠-٩]+$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// تحويل الأرقام العربية إلى إنجليزية قبل الحفظ
  String _normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var s = input;
    for (var i = 0; i < arabic.length; i++) {
      s = s.replaceAll(arabic[i], '$i');
    }
    return s;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Customer(
        name: _nameCtrl.text.trim(),
        phone: _normalizeDigits(_phoneCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة عميل'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_nameAllowed),
              ],
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'الرجاء إدخال الاسم';
                if (!_nameFull.hasMatch(value)) {
                  return 'الاسم يجب أن يحتوي على حروف فقط';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_phoneAllowed),
              ],
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'الرجاء إدخال رقم الهاتف';
                if (!_phoneFull.hasMatch(value)) {
                  return 'رقم الهاتف يجب أن يحتوي على أرقام فقط';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}