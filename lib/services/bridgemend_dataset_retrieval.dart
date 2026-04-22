import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Maps app profile gender to [bridgemend_dataset_*.csv] `speaker` values.
String speakerForDatasetGender(String gender) {
  switch (gender.toLowerCase()) {
    case 'male':
      return 'husband';
    case 'female':
      return 'wife';
    default:
      return 'husband';
  }
}

@immutable
class BridgeMendDatasetMatch {
  const BridgeMendDatasetMatch({
    required this.aiResponse,
    required this.score,
    required this.matchedKeywords,
    required this.inputText,
    required this.sessionType,
    required this.speaker,
  });

  final String aiResponse;
  final int score;
  final List<String> matchedKeywords;
  final String inputText;
  final String sessionType;
  final String speaker;
}

/// Keyword overlap on `input_text` → returns bundled `ai_response` only (no generation).
class BridgeMendDatasetRetrieval {
  BridgeMendDatasetRetrieval._();

  static final BridgeMendDatasetRetrieval instance = BridgeMendDatasetRetrieval._();

  static const _assetPath = 'assets/data/bridgemend_dataset_1000.csv';

  static final RegExp _tokenRe = RegExp(r"[a-z0-9']+");

  static const _stopwords = <String>{
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'as', 'is', 'was', 'are', 'were', 'been', 'be', 'have', 'has',
    'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may',
    'might', 'must', 'shall', 'can', 'need', 'dare', 'ought', 'used', 'it',
    'its', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'we',
    'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'our',
    'their', 'what', 'which', 'who', 'whom', 'when', 'where', 'why', 'how',
    'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other', 'some',
    'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too',
    'very', 'just', 'about', 'into', 'through', 'during', 'before', 'after',
    'above', 'below', 'up', 'down', 'out', 'off', 'over', 'under', 'again',
    'further', 'then', 'once', 'here', 'there', 'any', 'if', 'because', 
    'until', 'while', 'although', 'though', 'even', 'also', 'really', 'like',
    'get', 'got', 'getting', 'go', 'going', 'went', 'come', 'came', 'want',
    'wants', 'wanted', 'try', 'tried', 'think', 'thought', 'know', 'knew',
    'feel', 'feels', 'felt', 'im', 'ive', 'ill', 'dont', 'doesnt', 'didnt',
    'cant', 'wont', 'isnt', 'wasnt', 'arent', 'werent', 'thats', 'theres',
  };

  List<Map<String, String>>? _rows;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    _loading ??= _load();
    return _loading!;
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString(_assetPath);
    const converter = CsvToListConverter(eol: '\n');
    final table = converter.convert(raw);
    if (table.isEmpty) {
      _rows = [];
      return;
    }
    final header = table.first.map((e) => e.toString().trim()).toList();
    int idx(String name) {
      final i = header.indexOf(name);
      if (i < 0) {
        throw StateError('CSV missing column "$name"');
      }
      return i;
    }
    final iSession = idx('session_type');
    final iSpeaker = idx('speaker');
    final iInput = idx('input_text');
    final iOut = idx('ai_response');

    final out = <Map<String, String>>[];
    for (var r = 1; r < table.length; r++) {
      final row = table[r];
      if (row.length <= iOut) continue;
      String cell(int i) => row[i].toString().trim();
      out.add({
        'session_type': cell(iSession),
        'speaker': cell(iSpeaker),
        'input_text': cell(iInput),
        'ai_response': cell(iOut),
      });
    }
    _rows = out;
  }

  Set<String> _tokens(String text) {
    final s = <String>{};
    for (final m in _tokenRe.allMatches(text.toLowerCase())) {
      final t = m.group(0)!;
      if (t.length < 2 || _stopwords.contains(t)) continue;
      s.add(t);
    }
    return s;
  }

  /// Best row by keyword overlap on [input_text]. Optionally filter by session/speaker;
  /// if that yields no overlap, retries without speaker filter, then without session filter.
  BridgeMendDatasetMatch? bestMatch(
    String transcript, {
    String sessionType = 'personal',
    String speaker = 'husband',
  }) {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return null;
    final q = _tokens(transcript);
    if (q.isEmpty) return null;

    BridgeMendDatasetMatch? best;
    void consider(bool filterSession, bool filterSpeaker) {
      for (final row in rows) {
        if (filterSession && row['session_type'] != sessionType) continue;
        if (filterSpeaker && row['speaker'] != speaker) continue;
        final input = row['input_text'] ?? '';
        final rowTok = _tokens(input);
        final hit = q.intersection(rowTok);
        final score = hit.length;
        if (score == 0) continue;
        if (best == null || score > best!.score) {
          best = BridgeMendDatasetMatch(
            aiResponse: row['ai_response'] ?? '',
            score: score,
            matchedKeywords: hit.toList()..sort(),
            inputText: input,
            sessionType: row['session_type'] ?? '',
            speaker: row['speaker'] ?? '',
          );
        }
      }
    }

    consider(true, true);
    if (best == null) consider(true, false);
    if (best == null) consider(false, false);
    return best;
  }
}
