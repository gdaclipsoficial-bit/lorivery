import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'lorica_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT NOT NULL UNIQUE,
          role TEXT CHECK(role IN ('client', 'driver', 'admin')) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
          id TEXT PRIMARY KEY,
          client_id TEXT NOT NULL,
          driver_id TEXT,
          pickup_address TEXT NOT NULL,
          dropoff_address TEXT NOT NULL,
          fare REAL NOT NULL,
          status TEXT CHECK(status IN ('pending_payment', 'pending_approval', 'searching_driver', 'accepted', 'in_progress', 'completed', 'cancelled')) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(client_id) REFERENCES users(id),
          FOREIGN KEY(driver_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
          id TEXT PRIMARY KEY,
          trip_id TEXT NOT NULL,
          amount REAL NOT NULL,
          payment_method TEXT NOT NULL,
          receipt_image_path TEXT,
          status TEXT CHECK(status IN ('pending', 'approved', 'rejected')) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(trip_id) REFERENCES trips(id)
      )
    ''');
    
    // Insert dummy data for testing
    await db.execute('''
      INSERT INTO users (id, name, phone, role) 
      VALUES ('client_1', 'Juan Perez', '3000000000', 'client')
    ''');
    
    await db.execute('''
      INSERT INTO trips (id, client_id, pickup_address, dropoff_address, fare, status) 
      VALUES ('trip_1', 'client_1', 'Parque Principal', 'Barrio Centro', 5500.0, 'pending_payment')
    ''');
  }

  Future<void> savePaymentReceipt(String tripId, String imagePath, double amount, String method) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('payments', {
        'id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
        'trip_id': tripId,
        'amount': amount,
        'payment_method': method,
        'receipt_image_path': imagePath,
        'status': 'pending',
      });
      
      await txn.update(
        'trips',
        {'status': 'pending_approval'},
        where: 'id = ?',
        whereArgs: [tripId],
      );
    });
  }
}

