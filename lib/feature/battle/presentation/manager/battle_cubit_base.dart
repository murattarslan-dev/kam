import 'package:flutter_bloc/flutter_bloc.dart';
import 'battle_state.dart';
import '../../domain/entities/hero_entities.dart';

/// Battle ekranının (battle_screen.dart) hem PvE (BattleCubit) hem de PvP
/// (PvpBattleCubit) ile çalışabilmesi için ortak arayüz. Ekran bu soyut tipi
/// dinler; BlocProvider somut tipi sağlar.
abstract class BattleCubitBase extends Cubit<BattleState> {
  BattleCubitBase(super.initialState);

  void selectHero(int index, bool isEnemy);
  void executePlayerAttack();
  void onAnimationComplete();
  void swapHero(int fieldIndex, int benchIndex);
  void useSkill(int heroIndex, SkillEntity skill);
  bool isSkillPrerequisiteMet(HeroCardEntity hero, SkillEntity skill);
}
