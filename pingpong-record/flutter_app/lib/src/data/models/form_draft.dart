import 'dart:convert';

class FormDraft {
  const FormDraft({
    required this.draftKey,
    required this.payload,
    required this.updatedAt,
  });

  final String draftKey;
  final Map<String, Object?> payload;
  final String updatedAt;

  factory FormDraft.fromMap(Map<String, Object?> map) {
    final rawPayload = (map['payload'] as String?) ?? '{}';
    Map<String, Object?> decodedPayload;

    try {
      final decoded = jsonDecode(rawPayload);
      decodedPayload = decoded is Map<String, Object?>
          ? decoded
          : <String, Object?>{};
    } catch (_) {
      decodedPayload = <String, Object?>{};
    }

    return FormDraft(
      draftKey: (map['draft_key'] as String?) ?? '',
      payload: decodedPayload,
      updatedAt: (map['updated_at'] as String?) ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'draft_key': draftKey,
      'payload': jsonEncode(payload),
      'updated_at': updatedAt,
    };
  }
}
