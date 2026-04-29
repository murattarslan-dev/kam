import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const ShadowDeckApp());
}

class ShadowDeckApp extends StatelessWidget {
  const ShadowDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadow Deck Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Georgia', // Fantasy hissi için
      ),
      home: const GameCanvas(),
    );
  }
}

// --- DATA LAYER ---
enum ElementType { fire, water, earth, lightning }

class CardModel {
  final String id;
  final String name;
  final String icon;
  final ElementType element;
  final int owner; // 1: Player, 2: AI
  int hp;
  int maxHp;
  int atk;
  int level;
  int xp;
  bool hasActed;
  bool isDead;

  CardModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.element,
    required this.owner,
    required this.hp,
    required this.maxHp,
    required this.atk,
    this.level = 1,
    this.xp = 0,
    this.hasActed = false,
    this.isDead = false,
  });
}

// --- GAME ENGINE & STATE ---
class GameCanvas extends StatefulWidget {
  const GameCanvas({super.key});

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> {
  List<CardModel> playerTeam = [];
  List<CardModel> enemyTeam = [];
  int playerMana = 5;
  int enemyMana = 5;
  bool isPlayerTurn = true;
  String? selectedCardId;
  List<String> logs = ["Muharebe senkronize edildi."];
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initTeams();
  }

  void _initTeams() {
    playerTeam = _generateTeam(1);
    enemyTeam = _generateTeam(2);
  }

  List<CardModel> _generateTeam(int owner) {
    final names = ["Ironclad", "Ember", "Storm", "Gaia"];
    final icons = ["🛡️", "⚔️", "🔮", "🌿"];
    final elements = [ElementType.water, ElementType.fire, ElementType.lightning, ElementType.earth];

    return List.generate(3, (i) {
      int r = Random().nextInt(4);
      return CardModel(
        id: "card-$owner-$i",
        name: names[r],
        icon: icons[r],
        element: elements[r],
        owner: owner,
        hp: 100 + (r * 20),
        maxHp: 100 + (r * 20),
        atk: 25 + (r * 5),
      );
    });
  }

  // --- LOGIC ---
  void _handleAttack(CardModel attacker, CardModel target) async {
    if (isProcessing || attacker.hasActed || attacker.isDead || target.isDead) return;

    setState(() {
      isProcessing = true;
      attacker.hasActed = true;
    });

    // Hasar Hesaplama
    int damage = attacker.atk;
    // Element avantajı (Basit mantık)
    if (attacker.element == ElementType.fire && target.element == ElementType.earth) damage = (damage * 1.5).floor();

    await Future.delayed(const Duration(milliseconds: 500)); // Animasyon simülasyonu

    setState(() {
      target.hp = max(0, target.hp - damage);
      if (target.hp <= 0) target.isDead = true;

      logs.insert(0, "${attacker.name}, ${target.name} birimine $damage hasar verdi.");
      selectedCardId = null;
      isProcessing = false;
    });

    _checkTurnEnd();
  }

  void _checkTurnEnd() {
    final currentTeam = isPlayerTurn ? playerTeam : enemyTeam;
    if (currentTeam.where((c) => !c.isDead).every((c) => c.hasActed)) {
      _switchTurn();
    }
  }

  void _switchTurn() {
    setState(() {
      isPlayerTurn = !isPlayerTurn;
      playerMana = min(15, playerMana + 3);
      enemyMana = min(15, enemyMana + 3);
      for (var c in playerTeam) {
        c.hasActed = false;
      }
      for (var c in enemyTeam) {
        c.hasActed = false;
      }
      logs.insert(0, isPlayerTurn ? "Sıra sizde." : "Rakip hamle yapıyor...");
    });

    if (!isPlayerTurn) {
      Timer(const Duration(seconds: 1), _runAI);
    }
  }

  void _runAI() async {
    for (var attacker in enemyTeam.where((c) => !c.isDead && !c.hasActed)) {
      var targets = playerTeam.where((c) => !c.isDead).toList();
      if (targets.isNotEmpty) {
        _handleAttack(attacker, targets[Random().nextInt(targets.length)]);
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  // --- UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF020617)],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Battle Field
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTeamRow(enemyTeam, isEnemy: true),
                  _buildManaBar(),
                  _buildTeamRow(playerTeam, isEnemy: false),
                ],
              ),
            ),
            // Sidebar Logs
            _buildSidebar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(List<CardModel> team, {required bool isEnemy}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: team.map((card) => _CardWidget(
        card: card,
        isSelected: selectedCardId == card.id,
        onTap: () {
          if (!isPlayerTurn || isProcessing) return;
          if (!isEnemy && !card.hasActed && !card.isDead) {
            setState(() => selectedCardId = card.id);
          } else if (isEnemy && selectedCardId != null && !card.isDead) {
            final attacker = playerTeam.firstWhere((c) => c.id == selectedCardId);
            _handleAttack(attacker, card);
          }
        },
      )).toList(),
    );
  }

  Widget _buildManaBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "MANA: $playerMana / 15",
        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.black45,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("BATTLE LOG", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (context, i) => Text(
                "> ${logs[i]}",
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final CardModel card;
  final bool isSelected;
  final VoidCallback onTap;

  const _CardWidget({required this.card, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    double hpRatio = card.hp / card.maxHp;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.yellow : (card.owner == 1 ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: Colors.yellow.withOpacity(0.3), blurRadius: 15)] : [],
        ),
        child: Opacity(
          opacity: card.isDead ? 0.3 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(card.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // HP Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    backgroundColor: Colors.black,
                    color: hpRatio > 0.5 ? Colors.green : Colors.red,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text("ATK: ${card.atk}", style: const TextStyle(fontSize: 10, color: Colors.orange)),
              if (card.hasActed && !card.isDead)
                const Text("BEKLIYOR", style: TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}