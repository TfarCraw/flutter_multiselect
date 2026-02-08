import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() => runApp(MarioLikeGameApp());

class MarioLikeGameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Super Platformer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const double worldWidth = 2400;
  static const double worldHeight = 480;
  static const double gravity = 0.8;

  Timer _timer;
  double _playerX = 60;
  double _playerY = 100;
  double _velocityY = 0;
  double _velocityX = 0;
  bool _moveLeft = false;
  bool _moveRight = false;
  bool _onGround = false;

  int _levelIndex = 0;
  int _score = 0;
  int _lives = 3;

  List<LevelData> _levels;
  List<CoinData> _coins;
  List<EnemyData> _enemies;

  @override
  void initState() {
    super.initState();
    _levels = _buildLevels();
    _loadLevel(0, fullReset: true);
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _tick(Timer timer) {
    if (!mounted) return;

    final LevelData level = _levels[_levelIndex];

    _velocityX = 0;
    if (_moveLeft) _velocityX = -4.0;
    if (_moveRight) _velocityX = 4.0;

    _playerX += _velocityX;
    _velocityY += gravity;
    _playerY += _velocityY;

    _onGround = false;

    if (_playerY + 42 >= worldHeight) {
      _playerY = worldHeight - 42;
      _velocityY = 0;
      _onGround = true;
    }

    for (final PlatformData platform in level.platforms) {
      if (_playerX + 28 > platform.x &&
          _playerX < platform.x + platform.width &&
          _playerY + 42 >= platform.y &&
          _playerY + 42 <= platform.y + 18 &&
          _velocityY >= 0) {
        _playerY = platform.y - 42;
        _velocityY = 0;
        _onGround = true;
      }
    }

    for (final SpikeData spike in level.spikes) {
      if (_overlap(
        _playerX,
        _playerY,
        28,
        42,
        spike.x,
        spike.y,
        spike.width,
        spike.height,
      )) {
        _loseLife();
        return;
      }
    }

    for (final EnemyData enemy in _enemies) {
      enemy.x += enemy.direction * 1.4;
      if (enemy.x < enemy.minX || enemy.x > enemy.maxX) {
        enemy.direction *= -1;
      }

      if (_overlap(_playerX, _playerY, 28, 42, enemy.x, enemy.y, 30, 24)) {
        if (_velocityY > 2 && _playerY + 34 < enemy.y + 10) {
          enemy.alive = false;
          _velocityY = -9;
          _score += 150;
        } else {
          _loseLife();
          return;
        }
      }
    }

    _enemies.removeWhere((EnemyData e) => !e.alive);

    for (final CoinData coin in _coins) {
      if (!coin.collected &&
          _overlap(_playerX, _playerY, 28, 42, coin.x, coin.y, 16, 16)) {
        coin.collected = true;
        _score += 100;
      }
    }

    if (_playerY > worldHeight + 100) {
      _loseLife();
      return;
    }

    if (_playerX + 24 > level.goalX) {
      if (_levelIndex == _levels.length - 1) {
        _showEndDialog('Victoire !',
            'Tu as terminé les 5 niveaux avec $_score points.');
      } else {
        _loadLevel(_levelIndex + 1);
      }
      return;
    }

    _playerX = _playerX.clamp(0.0, worldWidth - 28);
    setState(() {});
  }

  bool _overlap(double x1, double y1, double w1, double h1, double x2, double y2,
      double w2, double h2) {
    return x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2;
  }

  void _jump() {
    if (_onGround) {
      _velocityY = -13;
    }
  }

  void _loseLife() {
    _lives -= 1;
    if (_lives <= 0) {
      _showEndDialog('Game Over', 'Tu as perdu toutes tes vies.');
      return;
    }
    _respawn();
  }

  void _respawn() {
    final LevelData level = _levels[_levelIndex];
    _playerX = level.spawnX;
    _playerY = level.spawnY;
    _velocityY = 0;
  }

  void _loadLevel(int newLevel, {bool fullReset = false}) {
    _levelIndex = newLevel;
    final LevelData level = _levels[_levelIndex];

    if (fullReset) {
      _score = 0;
      _lives = 3;
    }

    _coins = level.coins
        .map((CoinData c) => CoinData(c.x.toDouble(), c.y.toDouble()))
        .toList();
    _enemies = level.enemies
        .map((EnemyData e) => EnemyData(e.x, e.y, e.minX, e.maxX))
        .toList();

    _playerX = level.spawnX;
    _playerY = level.spawnY;
    _velocityY = 0;
    setState(() {});
  }

  void _restartFromStart() {
    _loadLevel(0, fullReset: true);
    Navigator.of(context).pop();
  }

  void _showEndDialog(String title, String message) {
    _timer.cancel();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            FlatButton(
              child: const Text('Rejouer'),
              onPressed: () {
                _restartFromStart();
                _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final LevelData level = _levels[_levelIndex];
    final double cameraX = (_playerX - size.width * 0.35)
        .clamp(0.0, worldWidth - size.width)
        .toDouble();

    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 12),
            color: const Color(0xFF102A43),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Niveau ${_levelIndex + 1}/5'),
                Text('Score: $_score'),
                Text('Vies: $_lives'),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Stack(
                children: <Widget>[
                  CustomPaint(
                    size: Size(size.width, size.height),
                    painter: WorldPainter(
                      level: level,
                      cameraX: cameraX,
                      playerX: _playerX,
                      playerY: _playerY,
                      coins: _coins,
                      enemies: _enemies,
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 22,
                    child: _ControlButton(
                      icon: Icons.arrow_left,
                      onDown: () => _moveLeft = true,
                      onUp: () => _moveLeft = false,
                    ),
                  ),
                  Positioned(
                    left: 90,
                    bottom: 22,
                    child: _ControlButton(
                      icon: Icons.arrow_right,
                      onDown: () => _moveRight = true,
                      onUp: () => _moveRight = false,
                    ),
                  ),
                  Positioned(
                    right: 24,
                    bottom: 22,
                    child: _ControlButton(
                      icon: Icons.arrow_upward,
                      onTap: _jump,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    Key key,
    this.icon,
    this.onDown,
    this.onUp,
    this.onTap,
  }) : super(key: key);

  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (onDown != null) onDown();
      },
      onTapUp: (_) {
        if (onUp != null) onUp();
        if (onTap != null) onTap();
      },
      onTapCancel: () {
        if (onUp != null) onUp();
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class WorldPainter extends CustomPainter {
  WorldPainter({
    this.level,
    this.cameraX,
    this.playerX,
    this.playerY,
    this.coins,
    this.enemies,
  });

  final LevelData level;
  final double cameraX;
  final double playerX;
  final double playerY;
  final List<CoinData> coins;
  final List<EnemyData> enemies;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect sky = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF3A86FF), Color(0xFF87CEEB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(sky);
    canvas.drawRect(sky, skyPaint);

    for (int i = 0; i < 8; i++) {
      final double cloudX = (i * 320.0 - (cameraX * 0.3)) % 2600 - 80;
      final double cloudY = 45 + (i % 3) * 35.0;
      _drawCloud(canvas, Offset(cloudX, cloudY));
    }

    final Paint groundPaint = Paint()..color = const Color(0xFF6A994E);
    canvas.drawRect(
      Rect.fromLTWH(-cameraX, _GamePageState.worldHeight, _GamePageState.worldWidth,
          120),
      groundPaint,
    );

    for (final PlatformData platform in level.platforms) {
      final Rect rect = Rect.fromLTWH(
        platform.x - cameraX,
        platform.y,
        platform.width,
        platform.height,
      );
      canvas.drawRect(rect, Paint()..color = const Color(0xFF8D5524));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 6),
        Paint()..color = const Color(0xFFB08968),
      );
    }

    for (final SpikeData spike in level.spikes) {
      final Path p = Path()
        ..moveTo(spike.x - cameraX, spike.y + spike.height)
        ..lineTo(spike.x + spike.width / 2 - cameraX, spike.y)
        ..lineTo(spike.x + spike.width - cameraX, spike.y + spike.height)
        ..close();
      canvas.drawPath(p, Paint()..color = Colors.grey.shade200);
    }

    for (final CoinData coin in coins) {
      if (coin.collected) continue;
      canvas.drawCircle(
        Offset(coin.x - cameraX + 8, coin.y + 8),
        8,
        Paint()..color = const Color(0xFFFFD60A),
      );
      canvas.drawCircle(
        Offset(coin.x - cameraX + 8, coin.y + 8),
        4,
        Paint()..color = const Color(0xFFFFEE99),
      );
    }

    for (final EnemyData enemy in enemies) {
      final Rect body = Rect.fromLTWH(enemy.x - cameraX, enemy.y, 30, 24);
      final RRect r = RRect.fromRectAndRadius(body, const Radius.circular(8));
      canvas.drawRRect(r, Paint()..color = const Color(0xFF6D597A));
      canvas.drawCircle(Offset(body.left + 8, body.top + 10), 2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(body.left + 22, body.top + 10), 2, Paint()..color = Colors.white);
    }

    final Rect playerRect = Rect.fromLTWH(playerX - cameraX, playerY, 28, 42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFFE76F51),
    );
    canvas.drawRect(
      Rect.fromLTWH(playerRect.left, playerRect.top, playerRect.width, 12),
      Paint()..color = const Color(0xFFEF233C),
    );
    canvas.drawCircle(
      Offset(playerRect.left + 14, playerRect.top + 20),
      4,
      Paint()..color = const Color(0xFFFFE0B2),
    );

    final double flagX = level.goalX - cameraX;
    canvas.drawRect(
      Rect.fromLTWH(flagX, 140, 6, _GamePageState.worldHeight - 140),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(flagX + 6, 150)
        ..lineTo(flagX + 46, 162)
        ..lineTo(flagX + 6, 174)
        ..close(),
      Paint()..color = const Color(0xFFFF006E),
    );
  }

  void _drawCloud(Canvas canvas, Offset o) {
    final Paint cloud = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(o + const Offset(0, 10), 16, cloud);
    canvas.drawCircle(o + const Offset(18, 0), 20, cloud);
    canvas.drawCircle(o + const Offset(38, 10), 16, cloud);
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) => true;
}

class LevelData {
  LevelData({
    this.spawnX,
    this.spawnY,
    this.goalX,
    this.platforms,
    this.coins,
    this.enemies,
    this.spikes,
  });

  final double spawnX;
  final double spawnY;
  final double goalX;
  final List<PlatformData> platforms;
  final List<CoinData> coins;
  final List<EnemyData> enemies;
  final List<SpikeData> spikes;
}

class PlatformData {
  PlatformData(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;
}

class CoinData {
  CoinData(this.x, this.y, {this.collected = false});

  final double x;
  final double y;
  bool collected;
}

class EnemyData {
  EnemyData(this.x, this.y, this.minX, this.maxX)
      : direction = math.Random().nextBool() ? 1 : -1,
        alive = true;

  double x;
  final double y;
  final double minX;
  final double maxX;
  int direction;
  bool alive;
}

class SpikeData {
  SpikeData(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;
}

List<LevelData> _buildLevels() {
  return <LevelData>[
    LevelData(
      spawnX: 50,
      spawnY: 340,
      goalX: 2200,
      platforms: <PlatformData>[
        PlatformData(220, 370, 140, 20),
        PlatformData(460, 320, 120, 20),
        PlatformData(680, 280, 120, 20),
        PlatformData(940, 350, 180, 20),
        PlatformData(1260, 300, 150, 20),
        PlatformData(1540, 250, 140, 20),
        PlatformData(1770, 330, 200, 20),
      ],
      coins: <CoinData>[
        CoinData(250, 335),
        CoinData(500, 285),
        CoinData(710, 245),
        CoinData(970, 315),
        CoinData(1290, 265),
      ],
      enemies: <EnemyData>[
        EnemyData(1020, 326, 970, 1120),
      ],
      spikes: <SpikeData>[
        SpikeData(1460, 438, 28, 20),
        SpikeData(1490, 438, 28, 20),
      ],
    ),
    LevelData(
      spawnX: 60,
      spawnY: 340,
      goalX: 2260,
      platforms: <PlatformData>[
        PlatformData(180, 330, 110, 20),
        PlatformData(380, 300, 100, 20),
        PlatformData(560, 260, 100, 20),
        PlatformData(760, 320, 160, 20),
        PlatformData(1030, 270, 130, 20),
        PlatformData(1320, 230, 130, 20),
        PlatformData(1660, 300, 180, 20),
      ],
      coins: <CoinData>[
        CoinData(210, 295),
        CoinData(590, 225),
        CoinData(790, 285),
        CoinData(1060, 235),
        CoinData(1700, 265),
        CoinData(1810, 265),
      ],
      enemies: <EnemyData>[
        EnemyData(830, 296, 760, 900),
        EnemyData(1710, 276, 1660, 1820),
      ],
      spikes: <SpikeData>[
        SpikeData(960, 438, 28, 20),
        SpikeData(990, 438, 28, 20),
        SpikeData(1950, 438, 28, 20),
      ],
    ),
    LevelData(
      spawnX: 50,
      spawnY: 330,
      goalX: 2280,
      platforms: <PlatformData>[
        PlatformData(190, 300, 150, 20),
        PlatformData(430, 260, 120, 20),
        PlatformData(640, 220, 120, 20),
        PlatformData(890, 260, 140, 20),
        PlatformData(1140, 220, 120, 20),
        PlatformData(1400, 260, 140, 20),
        PlatformData(1680, 320, 220, 20),
      ],
      coins: <CoinData>[
        CoinData(230, 265),
        CoinData(460, 225),
        CoinData(680, 185),
        CoinData(930, 225),
        CoinData(1440, 225),
        CoinData(1730, 285),
      ],
      enemies: <EnemyData>[
        EnemyData(915, 236, 890, 1020),
        EnemyData(1450, 236, 1400, 1510),
      ],
      spikes: <SpikeData>[
        SpikeData(1210, 438, 28, 20),
        SpikeData(1240, 438, 28, 20),
        SpikeData(1270, 438, 28, 20),
      ],
    ),
    LevelData(
      spawnX: 52,
      spawnY: 340,
      goalX: 2300,
      platforms: <PlatformData>[
        PlatformData(220, 360, 140, 20),
        PlatformData(450, 330, 120, 20),
        PlatformData(640, 290, 120, 20),
        PlatformData(830, 250, 120, 20),
        PlatformData(1060, 210, 140, 20),
        PlatformData(1320, 260, 140, 20),
        PlatformData(1560, 300, 130, 20),
        PlatformData(1820, 260, 160, 20),
      ],
      coins: <CoinData>[
        CoinData(250, 325),
        CoinData(480, 295),
        CoinData(670, 255),
        CoinData(860, 215),
        CoinData(1090, 175),
        CoinData(1840, 225),
      ],
      enemies: <EnemyData>[
        EnemyData(470, 306, 450, 560),
        EnemyData(1590, 276, 1560, 1690),
        EnemyData(1860, 236, 1820, 1970),
      ],
      spikes: <SpikeData>[
        SpikeData(960, 438, 28, 20),
        SpikeData(990, 438, 28, 20),
        SpikeData(1020, 438, 28, 20),
        SpikeData(1710, 438, 28, 20),
      ],
    ),
    LevelData(
      spawnX: 55,
      spawnY: 340,
      goalX: 2330,
      platforms: <PlatformData>[
        PlatformData(200, 330, 120, 20),
        PlatformData(380, 290, 100, 20),
        PlatformData(540, 250, 100, 20),
        PlatformData(700, 210, 100, 20),
        PlatformData(900, 260, 140, 20),
        PlatformData(1140, 220, 140, 20),
        PlatformData(1380, 180, 130, 20),
        PlatformData(1620, 240, 130, 20),
        PlatformData(1860, 300, 180, 20),
      ],
      coins: <CoinData>[
        CoinData(230, 295),
        CoinData(410, 255),
        CoinData(570, 215),
        CoinData(730, 175),
        CoinData(930, 225),
        CoinData(1170, 185),
        CoinData(1410, 145),
        CoinData(1885, 265),
      ],
      enemies: <EnemyData>[
        EnemyData(930, 236, 900, 1040),
        EnemyData(1430, 156, 1380, 1510),
        EnemyData(1910, 276, 1860, 2040),
      ],
      spikes: <SpikeData>[
        SpikeData(840, 438, 28, 20),
        SpikeData(870, 438, 28, 20),
        SpikeData(1530, 438, 28, 20),
        SpikeData(1560, 438, 28, 20),
        SpikeData(1590, 438, 28, 20),
      ],
    ),
  ];
}
