class JournalEntry {
  final int? id;
  final DateTime date;
  final String description;
  final String? referenceType;
  final int? referenceId;
  final DateTime createdAt;
  final List<JournalEntryLine> lines;

  JournalEntry({
    this.id,
    required this.date,
    required this.description,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
    this.lines = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, {List<JournalEntryLine> lines = const []}) {
    return JournalEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      referenceType: map['reference_type'],
      referenceId: map['reference_id'],
      createdAt: DateTime.parse(map['created_at']),
      lines: lines,
    );
  }
}

class JournalEntryLine {
  final int? id;
  final int entryId;
  final int accountId;
  final double debit;
  final double credit;
  // Optional: account name for UI convenience
  final String? accountName;

  JournalEntryLine({
    this.id,
    required this.entryId,
    required this.accountId,
    this.debit = 0.0,
    this.credit = 0.0,
    this.accountName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_id': entryId,
      'account_id': accountId,
      'debit': debit,
      'credit': credit,
    };
  }

  factory JournalEntryLine.fromMap(Map<String, dynamic> map, {String? accountName}) {
    return JournalEntryLine(
      id: map['id'],
      entryId: map['entry_id'],
      accountId: map['account_id'],
      debit: map['debit']?.toDouble() ?? 0.0,
      credit: map['credit']?.toDouble() ?? 0.0,
      accountName: accountName,
    );
  }
}
