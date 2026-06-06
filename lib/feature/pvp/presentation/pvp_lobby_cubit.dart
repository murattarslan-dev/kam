import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/match_service.dart';

enum PvpLobbyState {
  waiting, // her iki taraf hazır değil
  ready,   // her iki taraf hazır, savaş başlamak üzere
  error,
}

class PvpLobbyCubit extends Cubit<PvpLobbyState> {
  final MatchService _svc;
  final String _matchId;

  PvpLobbyCubit(this._svc, this._matchId) : super(PvpLobbyState.waiting);

  Future<void> watch() async {
    try {
      _svc.watch(_matchId).listen((data) {
        if (data == null) return;
        final status = data['status'] as String?;
        final hostReady = data['hostReady'] == true;
        final guestReady = data['guestReady'] == true;

        if (status == 'in_progress' && hostReady && guestReady) {
          emit(PvpLobbyState.ready);
        } else if (status == 'aborted') {
          emit(PvpLobbyState.error);
        } else {
          emit(PvpLobbyState.waiting);
        }
      });
    } catch (e) {
      emit(PvpLobbyState.error);
    }
  }
}
