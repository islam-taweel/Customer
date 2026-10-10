import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/customer.dart';
import '../models/debt_transaction.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _init();

  // تعبير SQL لحساب الرصيد: الديون - الدفعات
  static const _signedAmount =
      "CASE WHEN t.type = 'debt' THEN t.amount ELSE -t.amount END";

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'debts.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await _createTransactionsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createTransactionsTable(db);
      },
    );
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        type TEXT NOT NULL,            -- 'debt' أو 'payment'
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_transactions_customer ON transactions (customer_id)');
  }

  // ---------------- العملاء ----------------

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return db.insert('customers', customer.toMap());
  }

  /// جلب العملاء مع رصيد كل عميل (محسوب)، مع إمكانية البحث بالاسم
  Future<List<Customer>> getCustomers({String query = ''}) async {
    final db = await database;
    final q = query.trim();
    final rows = await db.rawQuery('''
      SELECT c.id, c.name, c.phone,
        COALESCE((SELECT SUM($_signedAmount) FROM transactions t
                  WHERE t.customer_id = c.id), 0) AS current_balance
      FROM customers c
      ${q.isEmpty ? '' : 'WHERE c.name LIKE ?'}
      ORDER BY c.name COLLATE NOCASE ASC
    ''', q.isEmpty ? null : ['%$q%']);
    return rows.map(Customer.fromMap).toList();
  }

  /// رصيد عميل واحد
  Future<double> getCustomerBalance(int customerId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM($_signedAmount), 0) AS b
      FROM transactions t WHERE t.customer_id = ?
    ''', [customerId]);
    return (rows.first['b'] as num).toDouble();
  }

  /// إجمالي الديون = مجموع أرصدة العملاء الذين عليهم رصيد موجب
  Future<double> getTotalDebts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(b), 0) AS total FROM (
        SELECT SUM($_signedAmount) AS b
        FROM transactions t
        GROUP BY t.customer_id
        HAVING b > 0
      )
    ''');
    return (rows.first['total'] as num).toDouble();
  }

  // ---------------- المعاملات ----------------

  Future<int> insertTransaction(DebtTransaction tx) async {
    final db = await database;
    return db.insert('transactions', tx.toMap());
  }

  /// معاملات العميل من الأحدث إلى الأقدم
  Future<List<DebtTransaction>> getTransactions(int customerId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(DebtTransaction.fromMap).toList();
  }
}