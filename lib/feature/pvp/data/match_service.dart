import 'package:cloud_firestore/cloud_firestore.dart';
import '../../battle/domain/entities/hero_entities.dart';
import 'match_mapper.dart';

/// matches/{matchId} koleksiyonu için Firestore CRUD + canlı dinleme.
///
/// Doküman alanları:
/// - lobi: status, hostId, guestId, hostReady, guestReady,
///   hostTeam, guestTeam, hostBench, guestBench, createdAt
/// - savaş: live(bool), turnNumber(int), turnOwner('host'|'guest'),
///   displayTurn, activeBuffs[], battleLogs[], totalDamageDealt{},
///   status('in_progress'|'finished'|'aborted'), result{winnerSide},
///   hostHeartbeat, guestHeartbeat
class MatchService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // PvP lobi/maç dokümanları mevcut 'battles' koleksiyonunda yaşar (yazma izni
  // zaten tanımlı). PvE savaş loglarından `status` alanıyla ayrılır.
  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('battles');

  /// Host yeni bir maç lobisi açar; davet linki bu id ile üretilir.
  Future<String> createMatch({
    required String hostId,
    required List<HeroCardEntity> hostTeam,
    required List<HeroCardEntity> hostBench,
  }) async {
    final doc = _col.doc();
    await doc.set({
      'status': 'lobby',
      'hostId': hostId,
      'guestId': null,
      'hostReady': true,
      'guestReady': false,
      'hostTeam': MatchMapper.teamToList(hostTeam),
      'hostBench': MatchMapper.teamToList(hostBench),
      'guestTeam': null,
      'guestBench': null,
      'live': false,
      'turnNumber': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Guest davetli olarak katılır; her iki taraf da hazır olduğundan maç
  /// in_progress'e geçer (host'un dinleyicisi canlı savaş durumunu yazacak).
  Future<void> joinMatch({
    required String matchId,
    required String guestId,
    required List<HeroCardEntity> guestTeam,
    required List<HeroCardEntity> guestBench,
  }) async {
    await _col.doc(matchId).update({
      'guestId': guestId,
      'guestReady': true,
      'guestTeam': MatchMapper.teamToList(guestTeam),
      'guestBench': MatchMapper.teamToList(guestBench),
      'status': 'in_progress',
    });
  }

  Stream<Map<String, dynamic>?> watch(String matchId) =>
      _col.doc(matchId).snapshots().map((s) => s.data());

  Future<Map<String, dynamic>?> get(String matchId) async =>
      (await _col.doc(matchId).get()).data();

  Future<void> push(String matchId, Map<String, dynamic> payload) =>
      _col.doc(matchId).update(payload);

  Future<void> abort(String matchId) async {
    try {
      await _col.doc(matchId).update({'status': 'aborted'});
    } catch (_) {/* maç zaten silinmiş/bitmiş olabilir */}
  }
}
