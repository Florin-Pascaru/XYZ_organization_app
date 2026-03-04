import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const HostessApp());

class HostessApp extends StatelessWidget {
  const HostessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const TableLayoutScreen(),
      );
}

// 1. MODELELE DE DATE
class Guest {
  String name;
  bool arrived;
  Guest({required this.name, this.arrived = false});

  Map<String, dynamic> toJson() => {'name': name, 'arrived': arrived};
  factory Guest.fromJson(Map<String, dynamic> json) => 
      Guest(name: json['name'], arrived: json['arrived']);
}

class EventTable {
  int number;
  Offset position;
  bool isRound;
  List<Guest> guests;
  bool isPlaced;

  EventTable({
    required this.number,
    this.position = const Offset(100, 150),
    this.isRound = true,
    List<Guest>? guests,
    this.isPlaced = false,
  }) : guests = guests ?? [];

  int get arrivedCount => guests.where((g) => g.arrived).length;
  bool get isFull => guests.isNotEmpty && arrivedCount == guests.length;

  Map<String, dynamic> toJson() => {
    'number': number,
    'x': position.dx,
    'y': position.dy,
    'isRound': isRound,
    'isPlaced': isPlaced,
    'guests': guests.map((g) => g.toJson()).toList(),
  };

  factory EventTable.fromJson(Map<String, dynamic> json) => EventTable(
    number: json['number'],
    position: Offset(json['x'], json['y']),
    isRound: json['isRound'],
    isPlaced: json['isPlaced'],
    guests: (json['guests'] as List).map((g) => Guest.fromJson(g)).toList(),
  );
}

class TableLayoutScreen extends StatefulWidget {
  const TableLayoutScreen({super.key});
  @override
  State<TableLayoutScreen> createState() => _TableLayoutScreenState();
}

class _TableLayoutScreenState extends State<TableLayoutScreen> {
  List<EventTable> allTables = [];
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  double tableSize = 85.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- PERSISTENȚA DATELOR ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(allTables.map((t) => t.toJson()).toList());
    await prefs.setString('event_data', encodedData);
    await prefs.setDouble('table_size', tableSize);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('event_data');
    final double? savedSize = prefs.getDouble('table_size');
    if (savedData != null) {
      final List<dynamic> decodedData = jsonDecode(savedData);
      setState(() {
        allTables = decodedData.map((item) => EventTable.fromJson(item)).toList();
        if (savedSize != null) tableSize = savedSize;
      });
    }
  }

  void _createNewTable() {
    if (allTables.length >= 60) return;
    setState(() {
      allTables.add(EventTable(number: allTables.length + 1));
    });
    _saveData();
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    bool isSearching = searchQuery.trim().isNotEmpty;
    List<Map<String, dynamic>> searchSuggestions = [];
    
    if (isSearching) {
      for (var table in allTables) {
        for (var guest in table.guests) {
          if (guest.name.toLowerCase().contains(searchQuery)) {
            searchSuggestions.add({'guest': guest, 'table': table});
          }
        }
      }
    }

    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isSearching) {
          setState(() {
            searchQuery = "";
            _searchController.clear();
          });
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.indigo.shade50,
          title: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: "Caută invitat...",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => searchQuery = v.toLowerCase().trim()),
          ),
          actions: [
            Builder(builder: (context) => IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            )),
          ],
        ),
        body: Stack(
          children: [
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                color: isSearching ? Colors.black.withOpacity(0.8) : Colors.grey[900],
                child: Stack(
                  children: [
                    if (allTables.where((t) => t.isPlaced).isEmpty)
                      const Center(child: Text("Adaugă mese din meniul lateral", style: TextStyle(color: Colors.white24))),
                    ...allTables.where((t) => t.isPlaced).map((table) {
                      bool hasMatch = isSearching && table.guests.any((g) => g.name.toLowerCase().contains(searchQuery));
                      return _buildTableWidget(table, hasMatch);
                    }).toList(),
                  ],
                ),
              ),
            ),
            if (isSearching && searchSuggestions.isNotEmpty) _buildSearchDropdown(searchSuggestions),
          ],
        ),
        endDrawer: _buildDrawer(),
      ),
    );
  }

  // --- COMPONENTE UI ---

  Widget _buildTableWidget(EventTable table, bool isMatch) {
    return Positioned(
      left: table.position.dx,
      top: table.position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => table.position += d.delta),
        onPanEnd: (_) => _saveData(),
        onDoubleTap: () {
          setState(() => table.isRound = !table.isRound);
          _saveData();
        },
        onTap: () => _showEditGuestsDialog(table),
        child: Container(
          width: tableSize, height: tableSize,
          decoration: BoxDecoration(
            color: isMatch ? Colors.green : (table.isFull ? Colors.blueGrey.shade800 : Colors.indigo),
            shape: table.isRound ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: table.isRound ? null : BorderRadius.circular(12),
            border: Border.all(color: table.isFull ? Colors.greenAccent : Colors.white, width: 2),
            boxShadow: isMatch ? [const BoxShadow(color: Colors.green, blurRadius: 15)] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("${table.number}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: tableSize * 0.22)),
              Text("${table.arrivedCount}/${table.guests.length}", style: TextStyle(color: Colors.white70, fontSize: tableSize * 0.12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDropdown(List<Map<String, dynamic>> suggestions) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        elevation: 10,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 350),
          color: Colors.white,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, i) {
              final guest = suggestions[i]['guest'] as Guest;
              final table = suggestions[i]['table'] as EventTable;
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.indigo, child: Text("${table.number}", style: const TextStyle(color: Colors.white, fontSize: 12))),
                title: Text(guest.name),
                subtitle: Text(guest.arrived ? "Sosit la Masa ${table.number}" : "Așteptat la Masa ${table.number}", 
                             style: TextStyle(color: guest.arrived ? Colors.green : Colors.grey)),
                trailing: Checkbox(
                  value: guest.arrived,
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() => guest.arrived = val!);
                    _saveData();
                  },
                ),
                onTap: () {
                  setState(() => guest.arrived = !guest.arrived);
                  _saveData();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEditGuestsDialog(EventTable table) {
    TextEditingController _c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Masa ${table.number}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _c,
                  decoration: InputDecoration(
                    labelText: "Adaugă Nume",
                    suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () {
                      if (_c.text.trim().isNotEmpty) {
                        setState(() => table.guests.add(Guest(name: _c.text.trim())));
                        _saveData();
                        setDialogState(() {});
                        _c.clear();
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3, minWidth: double.maxFinite),
                  child: table.guests.isEmpty 
                    ? const Padding(padding: EdgeInsets.all(20), child: Text("Niciun invitat"))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: table.guests.length,
                        itemBuilder: (context, i) => CheckboxListTile(
                          title: Text(table.guests[i].name),
                          value: table.guests[i].arrived,
                          onChanged: (v) {
                            setState(() => table.guests[i].arrived = v!);
                            _saveData();
                            setDialogState(() {});
                          },
                          secondary: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () {
                            setState(() => table.guests.removeAt(i));
                            _saveData();
                            setDialogState(() {});
                          }),
                        ),
                      ),
                )
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("GATA"))],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(decoration: BoxDecoration(color: Colors.indigo), child: Center(child: Text("GESTIUNE SALĂ", style: TextStyle(color: Colors.white, fontSize: 20)))),
          ListTile(leading: const Icon(Icons.add), title: const Text("Adaugă Masă Nouă"), onTap: _createNewTable),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.zoom_in, size: 20),
                Expanded(child: Slider(value: tableSize, min: 50, max: 150, onChanged: (v) { setState(() => tableSize = v); _saveData(); })),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: allTables.length,
              itemBuilder: (context, i) => ListTile(
                title: Text("Masa ${allTables[i].number}"),
                trailing: Switch(value: allTables[i].isPlaced, onChanged: (v) { setState(() => allTables[i].isPlaced = v); _saveData(); }),
                onTap: () => _showEditGuestsDialog(allTables[i]),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Resetare Eveniment", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              bool confirm = false;
              showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setD) => AlertDialog(
                    title: const Text("Ștergi tot?"),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text("Datele vor fi pierdute definitiv."),
                      CheckboxListTile(title: const Text("Confirm ștergerea"), value: confirm, onChanged: (v) => setD(() => confirm = v!)),
                    ]),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANULEAZĂ")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: confirm ? Colors.red : Colors.grey, foregroundColor: Colors.white),
                        onPressed: confirm ? () async {
                          final p = await SharedPreferences.getInstance();
                          await p.clear();
                          setState(() { allTables = []; searchQuery = ""; });
                          Navigator.pop(context);
                        } : null,
                        child: const Text("ȘTERGE TOT"),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}