import 'package:sqflite/sqflite.dart';

/// Current schema version. Bump on every schema change and add a step to
/// [migrate].
const int kSchemaVersion = 1;

const List<String> _schemaV1 = <String>[
  '''
CREATE TABLE wallets (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  account_type    TEXT NOT NULL CHECK (account_type IN ('CASH','E_WALLET','BANK','OTHER')),
  icon_identifier TEXT NOT NULL,
  balance_minor   INTEGER NOT NULL DEFAULT 0,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  created_at_ms   INTEGER NOT NULL,
  updated_at_ms   INTEGER NOT NULL
)
''',
  '''
CREATE TABLE categories (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('EXPENSE','INCOME')),
  icon_identifier TEXT NOT NULL,
  color_hex       TEXT NOT NULL,
  is_system       INTEGER NOT NULL DEFAULT 0,
  is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  sort_order      INTEGER NOT NULL DEFAULT 0,
  UNIQUE (name, type)
)
''',
  '''
CREATE TABLE transactions (
  id               TEXT PRIMARY KEY,
  amount_minor     INTEGER NOT NULL CHECK (amount_minor > 0),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('EXPENSE','INCOME','TRANSFER')),
  source_wallet_id TEXT NOT NULL REFERENCES wallets(id)    ON DELETE RESTRICT,
  target_wallet_id TEXT          REFERENCES wallets(id)    ON DELETE RESTRICT,
  category_id      TEXT          REFERENCES categories(id) ON DELETE RESTRICT,
  occurred_at_ms   INTEGER NOT NULL,
  local_date       TEXT NOT NULL,
  note             TEXT,
  created_at_ms    INTEGER NOT NULL,
  updated_at_ms    INTEGER NOT NULL,
  CHECK (transaction_type <> 'TRANSFER' OR target_wallet_id IS NOT NULL),
  CHECK (transaction_type =  'TRANSFER' OR category_id IS NOT NULL),
  CHECK (source_wallet_id <> target_wallet_id)
)
''',
  'CREATE INDEX idx_tx_occurred ON transactions(occurred_at_ms DESC)',
  'CREATE INDEX idx_tx_source ON transactions(source_wallet_id, occurred_at_ms DESC)',
  'CREATE INDEX idx_tx_target ON transactions(target_wallet_id, occurred_at_ms DESC)',
  'CREATE INDEX idx_tx_category ON transactions(category_id, occurred_at_ms DESC)',
  'CREATE INDEX idx_tx_local_date ON transactions(local_date)',
];

Future<void> createSchemaV1(Database db) async {
  for (final String statement in _schemaV1) {
    await db.execute(statement);
  }
}

/// Forward-only migrations. Called by sqflite when the stored `user_version`
/// is lower than [kSchemaVersion].
Future<void> migrate(Database db, int oldVersion, int newVersion) async {
  for (int version = oldVersion + 1; version <= newVersion; version++) {
    switch (version) {
      case 1:
        await createSchemaV1(db);
        break;
      default:
        throw StateError('No migration defined for schema version $version');
    }
  }
}