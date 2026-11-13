import 'dart:io';

// FinPlan: migrate transaction UI wiring to Riverpod while keeping
// TransactionController in main.dart for the legacy fallback.
// Run from the root FinPlan directory:
//   dart run lib/tool/migrate_transaction_ui_v4.dart

class _Source {
  _Source(this.path) : original = File(path).readAsStringSync() {
    content = original.replaceAll('\r\n', '\n');
  }

  final String path;
  final String original;
  late String content;

  void replaceExactlyOne(String pattern, String replacement) {
    final expression = RegExp(pattern, multiLine: true);
    final count = expression.allMatches(content).length;
    if (count != 1) {
      throw StateError(
        '$path: pola ditemukan $count kali (harus tepat 1).\n'
        'Pola: $pattern',
      );
    }
    content = content.replaceFirst(expression, replacement);
  }

  void require(String token) {
    if (!content.contains(token)) {
      throw StateError('$path: tidak menemukan "$token".');
    }
  }

  void forbid(String token) {
    if (content.contains(token)) {
      throw StateError('$path: referensi "$token" masih tersisa.');
    }
  }

  void backup() {
    final file = File('$path.before_transaction_ui_v4.bak');
    if (!file.existsSync()) file.writeAsStringSync(original);
  }

  void save() {
    final output = original.contains('\r\n')
        ? content.replaceAll('\n', '\r\n')
        : content;
    File(path).writeAsStringSync(output);
  }

  void restore() => File(path).writeAsStringSync(original);
}

void _migrateTransactions(_Source f) {
  f.require('transactionStateProvider');
  f.require('ConsumerStatefulWidget');

  // Accept single-line and multiline constructors.
  f.replaceExactlyOne(
    r'const\s+TransactionsPage\s*\(\s*\{\s*super\.key\s*,\s*'
    r'required\s+this\.controller\s*,?\s*\}\s*\)\s*;',
    'const TransactionsPage({super.key});',
  );
  f.replaceExactlyOne(
    r'^[ \t]*final\s+TransactionController\s+controller\s*;[ \t]*\n',
    '',
  );
  f.replaceExactlyOne(
    r"^[ \t]*import '../state/transaction_controller\.dart';[ \t]*\n",
    '',
  );
  f.replaceExactlyOne(
    r'controller\s*:\s*widget\.controller\s*,?',
    '',
  );

  f.require('AddTransactionPage(');
  f.forbid('widget.controller');
  f.forbid('TransactionController');
}

void _migrateAddTransaction(_Source f) {
  f.require('transactionStateProvider');
  f.require('ConsumerStatefulWidget');
  f.replaceExactlyOne(
    r'^[ \t]*required\s+this\.controller\s*,[ \t]*\n',
    '',
  );
  f.replaceExactlyOne(
    r'^[ \t]*final\s+TransactionController\s+controller\s*;[ \t]*\n',
    '',
  );
  f.replaceExactlyOne(
    r"^[ \t]*import '../state/transaction_controller\.dart';[ \t]*\n",
    '',
  );
  f.require('addTransaction(');
  f.require('updateTransaction(');
  f.forbid('widget.controller');
  f.forbid('TransactionController');
}

void _migrateShell(_Source f) {
  f.require('transactionStateProvider');
  f.replaceExactlyOne(
    r'^[ \t]*required\s+this\.transactionController\s*,[ \t]*\n',
    '',
  );
  f.replaceExactlyOne(
    r'^[ \t]*final\s+TransactionController\s+'
    r'transactionController\s*;[ \t]*\n',
    '',
  );
  f.replaceExactlyOne(
    r"^[ \t]*import '../../../state/transaction_controller\.dart';[ \t]*\n",
    '',
  );

  // The V3 failure happened here: V3 required a separate argument line.
  // This V4 pattern supports BOTH:
  //   TransactionsPage(controller: widget.transactionController)
  //   TransactionsPage(\n controller: widget.transactionController,\n )
  f.replaceExactlyOne(
    r'\bTransactionsPage\s*\(\s*controller\s*:\s*'
    r'widget\.transactionController\s*,?\s*\)',
    'TransactionsPage()',
  );
  f.forbid('widget.transactionController');
  f.forbid('TransactionController');
}

void _migrateMain(_Source f) {
  f.require('FinanceShell(');
  f.require('legacyTransactionControllerProvider');
  f.require('closeDatabase()');

  // Remove ONLY the forwarding argument to FinanceShell.
  // Keep the controller instance and disposal logic in main.dart.
  f.replaceExactlyOne(
    r'^[ \t]*transactionController\s*:\s*'
    r'widget\.transactionController\s*,[ \t]*\n',
    '',
  );
  f.require('legacyTransactionControllerProvider');
  f.require('TransactionController');
  f.require('closeDatabase()');
}

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('ERROR: Jalankan dari folder utama FinPlan.');
    exitCode = 1;
    return;
  }

  final paths = <String>[
    'lib/screens/transactions_page.dart',
    'lib/screens/add_transaction_page.dart',
    'lib/features/dashboard/presentation/finance_shell.dart',
    'lib/main.dart',
  ];
  final sources = <_Source>[];

  try {
    for (final path in paths) {
      if (!File(path).existsSync()) {
        throw StateError('File tidak ditemukan: $path');
      }
      sources.add(_Source(path));
    }

    // Validate and transform IN MEMORY. Nothing on disk changes yet.
    _migrateTransactions(sources[0]);
    _migrateAddTransaction(sources[1]);
    _migrateShell(sources[2]);
    _migrateMain(sources[3]);
    stdout.writeln('VALIDASI BERHASIL: seluruh pola cocok.');

    for (final source in sources) {
      source.backup();
    }
    try {
      for (final source in sources) {
        source.save();
        stdout.writeln('UPDATED: ${source.path}');
      }
    } catch (_) {
      for (final source in sources) {
        source.restore();
      }
      rethrow;
    }

    stdout.writeln('\nSUKSES: jalur UI Transaksi berhasil dirapikan.');
    stdout.writeln('Fallback TransactionController tetap ada di main.dart.');
    stdout.writeln('Database dan data pengguna tidak diubah.');
  } catch (error) {
    stderr.writeln('\nMIGRASI DIBATALKAN: $error');
    stderr.writeln('Jika gagal pada validasi, file aplikasi tidak diubah.');
    exitCode = 1;
  }
}
