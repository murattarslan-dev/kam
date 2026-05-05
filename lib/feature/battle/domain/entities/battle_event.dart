/// Firestore battles/{id}/events/{id} dokümanına yazılan tek bir savaş olayı.
class BattleEventDto {
  final int seq;
  final int turn;
  final String side; // "player" | "enemy" | "system"
  final String type; // attack | skill | swap | buff_trigger | dot | turn_start | turn_end | battle_start | battle_end
  final Map<String, dynamic>? actor;   // {id, name, isBot}
  final Map<String, dynamic>? target;  // {id, name, isBot}
  final Map<String, dynamic>? skill;   // {id, name}
  final Map<String, dynamic>? damage;  // {raw, finalDamage, defenseReduction, soakedBy:[...]}
  final Map<String, dynamic>? result;  // {targetHpAfter, killed, kutEarned}
  final Map<String, dynamic>? buff;    // {id, name, condition}
  final String message;

  const BattleEventDto({
    required this.seq,
    required this.turn,
    required this.side,
    required this.type,
    required this.message,
    this.actor,
    this.target,
    this.skill,
    this.damage,
    this.result,
    this.buff,
  });

  Map<String, dynamic> toMap() => {
        'seq': seq,
        'turn': turn,
        'side': side,
        'type': type,
        if (actor != null) 'actor': actor,
        if (target != null) 'target': target,
        if (skill != null) 'skill': skill,
        if (damage != null) 'damage': damage,
        if (result != null) 'result': result,
        if (buff != null) 'buff': buff,
        'message': message,
      };
}
