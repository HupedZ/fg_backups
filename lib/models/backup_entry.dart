class BackupEntry {
  final String name;
  final DateTime date;
  final int sizeBytes;

  BackupEntry({required this.name, required this.date, required this.sizeBytes});

  factory BackupEntry.fromJson(Map<String, dynamic> json) {
    return BackupEntry(
      name: json['name'] as String,
      date: DateTime.parse(json['date'] as String),
      sizeBytes: json['sizeBytes'] as int,
    );
  }

  String get sizeHuman {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = sizeBytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}
