enum TableShape { round, square, rectangular }

class EventTable {
  String id;
  int number;
  TableShape shape;
  double x, y; // Poziția pe canvas
  List<String> guests;
  bool isPlaced;
  int capacity;

  EventTable({
    required this.id,
    required this.number,
    this.shape = TableShape.round,
    this.x = 0.0,
    this.y = 0.0,
    this.guests = const [],
    this.isPlaced = false,
    this.capacity = 10,
  });
}