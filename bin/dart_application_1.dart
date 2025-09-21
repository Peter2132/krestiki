import 'dart:io';
import 'dart:math';

void main() {
  bool gameturnon = true;
  
  while (gameturnon) {
    print('Крестики-Нолики!');
    print('1 - Против игрока\n2 - Против робота');
    bool robotturn = stdin.readLineSync() == '2';

    int size;
    while (true) {
      print('Размер поля (3-9):');
      size = int.tryParse(stdin.readLineSync() ?? '0') ?? 0;
      if (size >= 3 && size <= 9) break;
      print('От 3 до 9!');
    }

    String selectPlayer = Random().nextBool() ? 'X' : 'O';
    print('Первым ходит: $selectPlayer');
    
    List<List<String>> board = List.generate(size, (_) => List.filled(size, '.'));
    printBoard(board);

    bool gameRunning = true;
    while (gameRunning) {
      if (selectPlayer == 'O' && robotturn) {
        robotMove(board, size);
      } else {
        playerMove(board, size, selectPlayer);
      }

      printBoard(board);

      if (checkWin(board, selectPlayer, size)) {
        print('$selectPlayer победил!');
        gameRunning = false;
      } else if (checkDraw(board)) {
        print('Ничья!');
        gameRunning = false;
      } else {
        selectPlayer = selectPlayer == 'X' ? 'O' : 'X';
      }
    }

    print('\nСыграть еще? (y/n)');
    if (stdin.readLineSync()?.toLowerCase() != 'y') {
      gameturnon = false;
    }
  }
}

void printBoard(List<List<String>> board) {
  print('\nПоле:');
  for (var row in board) print(row.join(' '));
}

void playerMove(List<List<String>> board, int size, String player) {
  while (true) {
    print('$player, введите строку и столбец (1 2):');
    var coords = stdin.readLineSync()?.split(' ');
    if (coords?.length != 2) {
      print('Введите 2 числа через пробел!');
      continue;
    }

    var row = int.tryParse(coords![0]);
    var col = int.tryParse(coords[1]);
    if (row == null || col == null || row < 1 || row > size || col < 1 || col > size) {
      print('Неверные координаты! Используйте числа от 1 до $size');
      continue;
    }

    if (board[row-1][col-1] == '.') {
      board[row-1][col-1] = player;
      break;
    }
    print('Клетка занята!');
  }
}

void robotMove(List<List<String>> board, int size) {
  print('Робот (O) ходит...');
  while (true) {
    var row = Random().nextInt(size);
    var col = Random().nextInt(size);
    if (board[row][col] == '.') {
      board[row][col] = 'O';
      break;
    }
  }
}

bool checkWin(List<List<String>> board, String player, int size) {
  for (int i = 0; i < size; i++) {
    if (board[i].every((e) => e == player)) return true;
  }

  for (int j = 0; j < size; j++) {
    bool win = true;
    for (int i = 0; i < size; i++) {
      if (board[i][j] != player) {
        win = false;
        break;
      }
    }
    if (win) return true;
  }

  bool diag1 = true, diag2 = true;
  for (int i = 0; i < size; i++) {
    if (board[i][i] != player) diag1 = false;
    if (board[i][size-1-i] != player) diag2 = false;
  }
  return diag1 || diag2;
}

bool checkDraw(List<List<String>> board) {
  return board.every((row) => row.every((e) => e != '.'));
}