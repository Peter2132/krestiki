import 'dart:io';
import 'dart:math';

class GameObject {
  String get symbol => '?';
  void showInfo() => print(symbol);
}

class Ship extends GameObject {
  final String id;
  final int length;
  Ship(this.id, this.length);
  @override String get symbol => 'S$length';
  @override void showInfo() => print('Корабль $id ($length)');
}

class Board extends GameObject {
  List<List<String>> grid = [];
  List<List<String>> shipIds = [];
  final int size;
  
  Board(this.size) {
    grid = List.generate(size, (_) => List.filled(size, '~'));
    shipIds = List.generate(size, (_) => List.filled(size, ''));
  }

  @override String get symbol => 'Board$size';
  
  void display(bool showShips) {
    print('  ' + List.generate(size, (i) => (i + 1)).join(' '));
    for (int i = 0; i < size; i++) {
      String row = '${String.fromCharCode(65 + i)} ';
      for (int j = 0; j < size; j++) {
        String cell = grid[i][j];
        if (!showShips && cell == 'S') row += '~ ';
        else if (cell == 'S') row += '\x1B[3${(shipIds[i][j].hashCode % 6) + 1}mS\x1B[0m ';
        else if (cell == 'X') row += '\x1B[31mX\x1B[0m ';
        else if (cell == 'O') row += '\x1B[33mO\x1B[0m ';
        else row += '~ ';
      }
      print(row);
    }
  }

  bool placeShip(int row, int col, int length, bool horizontal, String shipId) {
    if (horizontal ? col + length > size : row + length > size) return false;
    
    for (int k = 0; k < length; k++) {
      int r = horizontal ? row : row + k;
      int c = horizontal ? col + k : col;
      if (grid[r][c] != '~') return false;
      for (int i = max(0, r-1); i <= min(size-1, r+1); i++) {
        for (int j = max(0, c-1); j <= min(size-1, c+1); j++) {
          if (grid[i][j] == 'S') return false;
        }
      }
    }

    for (int k = 0; k < length; k++) {
      int r = horizontal ? row : row + k;
      int c = horizontal ? col + k : col;
      grid[r][c] = 'S';
      shipIds[r][c] = shipId;
    }
    return true;
  }

  bool isValidShot(int row, int col) => 
      row >= 0 && row < size && col >= 0 && col < size && 
      (grid[row][col] == '~' || grid[row][col] == 'S');

  String processShot(int row, int col) {
    if (grid[row][col] == 'S') {
      grid[row][col] = 'X';
      return 'hit';
    } else if (grid[row][col] == '~') {
      grid[row][col] = 'O';
      return 'miss';
    }
    return 'invalid';
  }

  bool get hasShips => grid.any((row) => row.contains('S'));
  String getShipId(int row, int col) => shipIds[row][col];
}

class Player extends GameObject {
  String name;
  int score = 0;
  Player(this.name);
  @override String get symbol => 'Player:$name';
  void makeMove(Board target, Board ownBoard, BattleshipGame game) {}
}

class HumanPlayer extends Player {
  HumanPlayer(String name) : super(name);
  @override void makeMove(Board target, Board ownBoard, BattleshipGame game) {
    while (true) {
      print('\nВаше поле:'); ownBoard.display(true);
      print('Поле противника:'); target.display(false);
      print('Ваш ход (A1):');
      
      String? input = stdin.readLineSync();
      if (input == null || input.length < 2) continue;
      
      int row = input.toUpperCase().codeUnitAt(0) - 65;
      int col = (int.tryParse(input.substring(1)) ?? 0) - 1;
      
      if (!target.isValidShot(row, col)) {
        print('Уже стреляли!'); continue;
      }
      
      String result = target.processShot(row, col);
      if (result == 'hit') {
        print('Попадание!'); 
        score++;
        game.hits++;
        if (game._isShipSunk(target, row, col)) {
          print('Корабль потоплен!');
          game._markSunkArea(target, target, row, col);
        }
        break;
      } else if (result == 'miss') {
        print('Промах!'); break;
      }
    }
  }
}

class ComputerPlayer extends Player {
  ComputerPlayer() : super('Компьютер');
  @override void makeMove(Board target, Board ownBoard, BattleshipGame game) {
    print('\nХод компьютера...');
    for (int i = 0; i < target.size; i++) {
      for (int j = 0; j < target.size; j++) {
        if (target.grid[i][j] == 'X') {
          for (var neighbor in [[i-1,j], [i+1,j], [i,j-1], [i,j+1]]) {
            int r = neighbor[0], c = neighbor[1];
            if (r >= 0 && r < target.size && c >= 0 && c < target.size && 
                target.isValidShot(r, c)) {
              _makeShot(target, r, c, game);
              return;
            }
          }
        }
      }
    }
    
    Random random = Random();
    while (true) {
      int r = random.nextInt(target.size), c = random.nextInt(target.size);
      if (target.isValidShot(r, c)) {
        _makeShot(target, r, c, game);
        break;
      }
    }
  }
  
  void _makeShot(Board target, int row, int col, BattleshipGame game) {
    print('Стреляет в ${String.fromCharCode(65 + row)}${col + 1}');
    String result = target.processShot(row, col);
    if (result == 'hit') {
      print('Попадание!'); 
      score++;
      if (game._isShipSunk(target, row, col)) {
        print('Корабль потоплен!');
        game._markSunkArea(target, target, row, col);
      }
    } else {
      print('Промах!');
    }
  }
}

class BattleshipGame {
  Board playerBoard = Board(8), computerBoard = Board(8), targetBoard = Board(8);
  Player human, computer;
  int totalShots = 0, hits = 0;
  int shipCounter = 0;

  BattleshipGame(bool vsComputer)
      : human = HumanPlayer('Игрок'),
        computer = vsComputer ? ComputerPlayer() : HumanPlayer('Игрок 2');

  String _generateShipId() => 'ship_${++shipCounter}';

  void _placeShips(Board board, bool manual) {
    List<int> ships = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
    
    for (int length in ships) {
      Ship ship = Ship(_generateShipId(), length);
      if (manual) ship.showInfo();
      
      bool placed = false;
      int attempts = 0;
      
      while (!placed && attempts < 100) {
        if (manual) {
          print('\nПоле:'); board.display(true);
          print('Разместите корабль длиной $length (A1 H):');
          String? input = stdin.readLineSync();
          if (input == null || input.length < 3) continue;
          
          List<String> parts = input.toUpperCase().split(' ');
          if (parts.length != 2) continue;
          
          int row = parts[0].codeUnitAt(0) - 65;
          int col = (int.tryParse(parts[0].substring(1)) ?? 0) - 1;
          bool horizontal = parts[1] == 'H';
          
          if (row >= 0 && row < 8 && col >= 0 && col < 8) {
            placed = board.placeShip(row, col, length, horizontal, ship.id);
          }
          if (!placed) print('Нельзя разместить!');
        } else {
          Random random = Random();
          int row = random.nextInt(8);
          int col = random.nextInt(8);
          bool horizontal = random.nextBool();
          placed = board.placeShip(row, col, length, horizontal, ship.id);
        }
        attempts++;
      }
      
      if (!placed && !manual) {
        print('Не удалось разместить корабль длиной $length, пробуем снова...');
        board.grid = List.generate(8, (_) => List.filled(8, '~'));
        board.shipIds = List.generate(8, (_) => List.filled(8, ''));
        shipCounter = 0;
        _placeShips(board, false); 
        return;
      }
    }
    
    if (manual) print('\nВсе корабли размещены!');
    board.display(manual);
  }

  bool _isShipSunk(Board board, int row, int col) {
    String shipId = board.getShipId(row, col);
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        if (board.shipIds[i][j] == shipId && board.grid[i][j] == 'S') return false;
      }
    }
    return true;
  }

  void _markSunkArea(Board source, Board target, int row, int col) {
    String shipId = source.getShipId(row, col);
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        if (source.shipIds[i][j] == shipId) {
          for (int x = max(0, i-1); x <= min(7, i+1); x++) {
            for (int y = max(0, j-1); y <= min(7, j+1); y++) {
              if (target.grid[x][y] == '~') target.grid[x][y] = 'O';
            }
          }
        }
      }
    }
  }

  void play() {
    print('МОРСКОЙ БОЙ');
    human.showInfo();
    computer.showInfo();
    
    shipCounter = 0;
    print('Расстановка: 1-авто, 2-ручно');
    bool manual = stdin.readLineSync() == '2';
    _placeShips(playerBoard, manual);
    
    shipCounter = 0;
    _placeShips(computerBoard, false);
    
    Player current = human;
    while (true) {
      print('\n--- Ход ${current.name} ---');
      totalShots++;
      
      if (current == human) {
        human.makeMove(computerBoard, playerBoard, this);
        if (!computerBoard.hasShips) {
          print('\n${human.name} ПОБЕДИЛ!'); break;
        }
        current = computer;
      } else {
        computer.makeMove(playerBoard, computerBoard, this);
        if (!playerBoard.hasShips) {
          print('\n${computer.name} ПОБЕДИЛ!'); break;
        }
        current = human;
      }
      
      double accuracy = totalShots > 0 ? (hits / totalShots * 100) : 0;
      print('Счет: ${human.score}:${computer.score} | Точность: ${accuracy.toStringAsFixed(1)}%');
    }
  }
}

void main() {
  while (true) {
    print('МОРСКОЙ БОЙ\n1-Против ИИ 2-Два игрока 3-Выход');
    String? choice = stdin.readLineSync();
    if (choice == '3') break;
    if (choice == '1' || choice == '2') {
      BattleshipGame(choice == '1').play();
      print('\nСыграть еще? (y/n)');
      if (stdin.readLineSync()?.toLowerCase() != 'y') break;
    }
  }
  print('Спасибо за игру!');
}