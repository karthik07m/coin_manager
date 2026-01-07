class Receipt {
  final String id;
  final String? transactionId;
  final String imagePath;
  final String? extractedText;
  final DateTime createdOn;

  Receipt({
    required this.id,
    this.transactionId,
    required this.imagePath,
    this.extractedText,
    required this.createdOn,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'image_path': imagePath,
      'extracted_text': extractedText,
      'created_on': createdOn.toIso8601String(),
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'],
      transactionId: map['transaction_id'],
      imagePath: map['image_path'],
      extractedText: map['extracted_text'],
      createdOn: DateTime.parse(map['created_on']),
    );
  }

  Receipt copyWith({
    String? id,
    String? transactionId,
    String? imagePath,
    String? extractedText,
    DateTime? createdOn,
  }) {
    return Receipt(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      imagePath: imagePath ?? this.imagePath,
      extractedText: extractedText ?? this.extractedText,
      createdOn: createdOn ?? this.createdOn,
    );
  }
}
