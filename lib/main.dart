import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const EnshroudedManagerApp());
}

class EnshroudedManagerApp extends StatelessWidget {
  const EnshroudedManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caveman Games - Enshrouded Manager',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ServerConfigPage(),
    );
  }
}

class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  // App Versie
  static const String _currentAppVersion = "v1.1.0";

  Map<String, dynamic> _fullJsonData = {};
  Map<String, dynamic> _gameSettings = {};
  List<dynamic> _userGroups = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _queryPortController = TextEditingController();

  double _slotCount = 16.0;
  bool _savedStatus = false;
  String? exePath;
  String? jsonPath;
  String? steamCmdPath; 
  Process? _serverProcess;
  bool _isRunning = false;
  bool _isUpdating = false;
  bool _serverUpdateAvailable = false;
  String _consoleOutput = "Welcome to the Caveman Games Manager ($_currentAppVersion)!\nSearching for server...\n";

  @override
  void initState() {
    super.initState();
    _initServerPath();
    _initSteamCmdPath(); 
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForManagerUpdate();
    });
  }

  // --- AUTOMATISCHE GITHUB APP UPDATE CHECK (Aangepast naar dedicated repo) ---
  Future<void> _checkForManagerUpdate() async {
    try {
      final client = HttpClient();
      client.userAgent = "EnshroudedManagerApp";
      // Hier URL aangepast naar enshrouded-server-manager
      final request = await client.getUrl(Uri.parse('https://api.github.com/repos/caveman-games/enshrouded-server-manager/releases/latest'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        final latestTag = json['tag_name'] ?? '';
        final htmlUrl = json['html_url'] ?? 'https://github.com/caveman-games/enshrouded-server-manager/releases';

        if (latestTag.isNotEmpty && latestTag != _currentAppVersion) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Manager Update Available! 🎉"),
              content: Text("A new version ($latestTag) of Enshrouded Manager is available!\n\nYou are currently running $_currentAppVersion."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Later"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Process.run('cmd', ['/c', 'start', '', htmlUrl]);
                    Navigator.pop(context);
                  },
                  child: const Text("Download Update"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("GitHub update check skipped/failed: $e");
    }
  }

  Future<void> _checkServerUpdateStatus() async {
    if (exePath == null) return;
    try {
      Directory serverDir = File(exePath!).parent;
      File manifestFile = File('${serverDir.parent.path}\\appmanifest_2278520.acf');
      if (!await manifestFile.exists()) {
        manifestFile = File('${serverDir.path}\\steamapps\\appmanifest_2278520.acf');
      }

      String? localBuildId;
      if (await manifestFile.exists()) {
        String content = await manifestFile.readAsString();
        RegExp regExp = RegExp(r'"buildid"\s+"(\d+)"');
        Match? match = regExp.firstMatch(content);
        if (match != null) {
          localBuildId = match.group(1);
        }
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://api.steamcmd.net/v1/info/2278520'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        String? latestBuildId = json['data']?['2278520']?['depots']?['branches']?['public']?['buildid']?.toString();

        if (localBuildId != null && latestBuildId != null && localBuildId != latestBuildId) {
          setState(() {
            _serverUpdateAvailable = true;
            _consoleOutput += "📢 Notice: A new Enshrouded Server update (Build $latestBuildId) is available on Steam!\n";
          });
        }
      }
    } catch (e) {
      debugPrint("Server update check skipped: $e");
    }
  }

  Future<String?> _findServerPath() async {
    List<String> defaultPaths = [
      r'C:\Program Files (x86)\Steam\steamapps\common\EnshroudedServer\enshrouded_server.exe',
      r'C:\steamcmd\steamapps\common\EnshroudedServer\enshrouded_server.exe',
    ];
    for (String path in defaultPaths) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<void> _initServerPath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedPath = prefs.getString('server_exe_path');

    if (savedPath != null && await File(savedPath).exists()) {
      _setPaths(savedPath);
    } else {
      String? foundPath = await _findServerPath();
      if (foundPath != null) {
        _setPaths(foundPath);
        await prefs.setString('server_exe_path', foundPath);
      } else {
        setState(() => _consoleOutput += "Server not found automatically. Please select 'enshrouded_server.exe' manually.\n");
      }
    }
  }

  Future<void> _initSteamCmdPath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedPath = prefs.getString('steamcmd_exe_path');

    if (savedPath != null && await File(savedPath).exists()) {
      setState(() => steamCmdPath = savedPath);
    } else {
      List<String> defaultPaths = [
        r'C:\steamcmd\steamcmd.exe',
        r'D:\steamcmd\steamcmd.exe',
      ];
      for (String path in defaultPaths) {
        if (await File(path).exists()) {
          setState(() => steamCmdPath = path);
          await prefs.setString('steamcmd_exe_path', path);
          break;
        }
      }
    }
  }

  void _setPaths(String path) {
    setState(() {
      exePath = path;
      jsonPath = path.replaceAll('enshrouded_server.exe', 'enshrouded_server.json');
    });
    _loadConfig();
    _checkServerUpdateStatus();
  }

  Future<void> _pickServerManually() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select enshrouded_server.exe', type: FileType.custom, allowedExtensions: ['exe'],
    );
    if (result != null && result.files.single.path != null) {
      String chosenPath = result.files.single.path!;
      if (chosenPath.toLowerCase().endsWith('enshrouded_server.exe')) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_exe_path', chosenPath);
        _setPaths(chosenPath);
        setState(() => _consoleOutput += "Server path set manually: $chosenPath\n");
      } else {
        setState(() => _consoleOutput += "Error: You must select 'enshrouded_server.exe'!\n");
      }
    }
  }

  Future<void> _pickSteamCmdManually() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select steamcmd.exe', type: FileType.custom, allowedExtensions: ['exe'],
    );
    if (result != null && result.files.single.path != null) {
      String chosenPath = result.files.single.path!;
      if (chosenPath.toLowerCase().endsWith('steamcmd.exe')) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('steamcmd_exe_path', chosenPath);
        setState(() {
          steamCmdPath = chosenPath;
          _consoleOutput += "SteamCMD path set manually: $chosenPath\n";
        });
      } else {
        setState(() => _consoleOutput += "Error: You must select 'steamcmd.exe'!\n");
      }
    }
  }

  Future<void> _loadConfig() async {
    if (jsonPath == null) return;
    try {
      final file = File(jsonPath!);
      if (await file.exists()) {
        String contents = await file.readAsString();
        setState(() {
          _fullJsonData = jsonDecode(contents);
          _gameSettings = _fullJsonData['gameSettings'] ?? {};
          _userGroups = _fullJsonData['userGroups'] ?? [];

          _nameController.text = _fullJsonData['name'] ?? 'Enshrouded Server';
          _ipController.text = _fullJsonData['ip'] ?? '0.0.0.0';
          _queryPortController.text = (_fullJsonData['queryPort'] ?? 15637).toString();
          _slotCount = (_fullJsonData['slotCount'] ?? 16).toDouble();

          _consoleOutput += "Configuration loaded successfully.\n";
        });
      }
    } catch (e) {
      debugPrint("Error loading config: $e");
    }
  }

  Future<void> _saveConfig() async {
    if (jsonPath == null) return;
    try {
      _fullJsonData['name'] = _nameController.text;
      _fullJsonData['ip'] = _ipController.text;
      _fullJsonData['queryPort'] = int.tryParse(_queryPortController.text) ?? 15637;
      _fullJsonData['slotCount'] = _slotCount.toInt();
      _fullJsonData['gameSettings'] = _gameSettings;
      _fullJsonData['userGroups'] = _userGroups;

      JsonEncoder encoder = const JsonEncoder.withIndent('\t');
      await File(jsonPath!).writeAsString(encoder.convert(_fullJsonData));

      setState(() => _savedStatus = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedStatus = false);
      });
      setState(() => _consoleOutput += "Settings saved successfully!\n");
    } catch (e) {
      debugPrint("Error saving config: $e");
    }
  }

  void _startServer() async {
    if (exePath == null) return;
    try {
      final executable = File(exePath!);
      if (!await executable.exists()) return;

      _serverProcess = await Process.start(exePath!, [], workingDirectory: executable.parent.path);
      setState(() { _isRunning = true; _consoleOutput += "Server started...\n"; });

      _serverProcess!.stdout.transform(utf8.decoder).listen((data) => setState(() => _consoleOutput += data));
      _serverProcess!.stderr.transform(utf8.decoder).listen((data) => setState(() => _consoleOutput += "ERR: $data"));
      _serverProcess!.exitCode.then((exitCode) => setState(() { _isRunning = false; _consoleOutput += "Server stopped ($exitCode).\n"; }));
    } catch (e) {
      setState(() => _consoleOutput += "Error starting server: $e\n");
    }
  }

  void _stopServer() {
    if (_serverProcess != null) {
      _serverProcess!.kill();
      setState(() { _isRunning = false; _consoleOutput += "Stop signal sent.\n"; });
    }
  }

  Future<void> _updateServer() async {
    if (exePath == null) return;
    
    if (steamCmdPath == null || !File(steamCmdPath!).existsSync()) {
      setState(() {
        _consoleOutput += "========================================\n";
        _consoleOutput += "Error: No valid SteamCMD path found!\n";
        _consoleOutput += "Go to the 'Basic' tab and select steamcmd.exe.\n";
        _consoleOutput += "========================================\n";
      });
      return;
    }

    String serverInstallPath = File(exePath!).parent.path;

    setState(() {
      _isUpdating = true;
      _consoleOutput += "========================================\n";
      _consoleOutput += "SteamCMD Update started...\n";
      _consoleOutput += "SteamCMD Path: $steamCmdPath\n";
      _consoleOutput += "Target Folder: $serverInstallPath\n";
      _consoleOutput += "Please wait, this may take a few minutes...\n";
      _consoleOutput += "========================================\n";
    });

    try {
      ProcessResult result = await Process.run(steamCmdPath!, [
        '+force_install_dir',
        serverInstallPath,
        '+login',
        'anonymous',
        '+app_update',
        '2278520',
        'validate',
        '+quit'
      ]);

      if (result.exitCode == 0) {
        setState(() {
          _consoleOutput += "Update completed successfully!\n";
          _serverUpdateAvailable = false;
        });
      } else {
        setState(() {
          _consoleOutput += "Update failed (Exit code: ${result.exitCode}).\n";
          _consoleOutput += "Log: ${result.stderr}\n";
        });
      }
    } catch (e) {
      setState(() {
        _consoleOutput += "Error during update: $e\n";
      });
    } finally {
      setState(() {
        _isUpdating = false;
        _consoleOutput += "========================================\n";
      });
    }
  }

  Widget _buildDiscreteSlider(String label, String jsonKey, List<int> allowedValues) {
    double currentFactor = (_gameSettings[jsonKey] ?? 1.0).toDouble();
    int currentPct = (currentFactor * 100).round();

    int closestIndex = 0;
    int minDiff = 9999;
    for (int i = 0; i < allowedValues.length; i++) {
      int diff = (allowedValues[i] - currentPct).abs();
      if (diff < minDiff) { minDiff = diff; closestIndex = i; }
    }

    int displayPct = allowedValues[closestIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $displayPct%', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.orangeAccent)),
          Slider(
            value: closestIndex.toDouble(),
            min: 0, max: (allowedValues.length - 1).toDouble(),
            divisions: allowedValues.length > 1 ? allowedValues.length - 1 : 1,
            label: '$displayPct%',
            onChanged: (newIndex) {
              int selectedPct = allowedValues[newIndex.toInt()];
              setState(() => _gameSettings[jsonKey] = double.parse((selectedPct / 100.0).toStringAsFixed(2)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider(String label, String jsonKey, List<int> allowedMinutes) {
    const int tickMultiplier = 60000000000; 
    int currentVal = _gameSettings[jsonKey] ?? (10 * tickMultiplier);
    int currentMin = (currentVal / tickMultiplier).round();

    int closestIndex = 0;
    int minDiff = 9999;
    for (int i = 0; i < allowedMinutes.length; i++) {
      int diff = (allowedMinutes[i] - currentMin).abs();
      if (diff < minDiff) { minDiff = diff; closestIndex = i; }
    }
    int displayMin = allowedMinutes[closestIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $displayMin min', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.lightBlueAccent)),
          Slider(
            value: closestIndex.toDouble(),
            min: 0, max: (allowedMinutes.length - 1).toDouble(),
            divisions: allowedMinutes.length > 1 ? allowedMinutes.length - 1 : 1,
            label: '$displayMin min',
            onChanged: (newIndex) {
              int selectedMin = allowedMinutes[newIndex.toInt()];
              setState(() => _gameSettings[jsonKey] = selectedMin * tickMultiplier);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntSlider(String label, String jsonKey, int minVal, int maxVal) {
    int currentVal = (_gameSettings[jsonKey] ?? maxVal).toInt();
    currentVal = currentVal.clamp(minVal, maxVal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $currentVal', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.greenAccent)),
          Slider(
            value: currentVal.toDouble(), min: minVal.toDouble(), max: maxVal.toDouble(),
            divisions: maxVal - minVal, label: '$currentVal',
            onChanged: (newVal) => setState(() => _gameSettings[jsonKey] = newVal.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String jsonKey, List<String> options) {
    String currentVal = _gameSettings[jsonKey]?.toString() ?? options.first;
    if (!options.contains(currentVal)) options.add(currentVal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: currentVal,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (newVal) => setState(() => _gameSettings[jsonKey] = newVal),
      ),
    );
  }

  Widget _buildSwitch(String label, String jsonKey) {
    bool val = _gameSettings[jsonKey] ?? false;
    return SwitchListTile(
      title: Text(label), value: val, contentPadding: EdgeInsets.zero,
      onChanged: (newVal) => setState(() => _gameSettings[jsonKey] = newVal),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConfigReady = jsonPath != null && File(jsonPath!).existsSync();

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 140,
          title: Row(
            children: [
              const Text('Caveman Games\nEnshrouded Manager', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.asset(
                  'assets/enshrouded.jpg', height: 120, width: 120, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 24.0, top: 10, bottom: 10),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.jpg', height: 120, width: 120, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.videogame_asset, size: 100, color: Colors.orange),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "Basic", icon: Icon(Icons.settings)),
              Tab(text: "Users", icon: Icon(Icons.group)),
              Tab(text: "Enemies", icon: Icon(Icons.warning)),
              Tab(text: "Player", icon: Icon(Icons.person)),
              Tab(text: "Survival", icon: Icon(Icons.favorite)),
              Tab(text: "Resources", icon: Icon(Icons.forest)),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TabBarView(
                        children: [
                          // TAB 1: BASIC
                          ListView(
                            children: [
                              Text(exePath ?? 'No server selected', style: const TextStyle(color: Colors.greenAccent)),
                              ElevatedButton.icon(
                                onPressed: _pickServerManually, icon: const Icon(Icons.folder_open), label: const Text('Select Server'),
                              ),
                              const SizedBox(height: 12),
                              Text(steamCmdPath ?? 'No SteamCMD selected (required for updates)', style: const TextStyle(color: Colors.lightBlueAccent)),
                              ElevatedButton.icon(
                                onPressed: _pickSteamCmdManually, icon: const Icon(Icons.downloading), label: const Text('Select SteamCMD'),
                              ),
                              const Divider(height: 30),
                              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Server Name', border: OutlineInputBorder())),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'IP (0.0.0.0 = All)', border: OutlineInputBorder()))),
                                  const SizedBox(width: 12),
                                  Expanded(child: TextField(controller: _queryPortController, decoration: const InputDecoration(labelText: 'Query Port', border: OutlineInputBorder()))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text('Player Limit: ${_slotCount.toInt()}'),
                              Slider(value: _slotCount, min: 1, max: 16, divisions: 15, label: _slotCount.toInt().toString(), onChanged: (val) => setState(() => _slotCount = val)),
                              _buildDropdown('Voice Chat Mode', 'voiceChatMode', ['Proximity', 'Global', 'None']),
                              _buildDropdown('Game Settings Preset', 'gameSettingsPreset', ['Default', 'Custom', 'Hard', 'Relaxed', 'Survival']),
                            ],
                          ),

                          // TAB 2: USERS
                          ListView(
                            children: [
                              const Text("User Groups & Passwords", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 10),
                              if (_userGroups.isEmpty)
                                const Text("No user groups found in this JSON file.", style: TextStyle(color: Colors.grey)),
                              for (int i = 0; i < _userGroups.length; i++)
                                Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Role: ${_userGroups[i]['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: TextEditingController(text: _userGroups[i]['password']),
                                          onChanged: (val) => _userGroups[i]['password'] = val,
                                          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 16,
                                          children: [
                                            FilterChip(
                                              label: const Text('Kick/Ban'),
                                              selected: _userGroups[i]['canKickBan'] ?? false,
                                              onSelected: (val) => setState(() => _userGroups[i]['canKickBan'] = val),
                                            ),
                                            FilterChip(
                                              label: const Text('Inventories'),
                                              selected: _userGroups[i]['canAccessInventories'] ?? false,
                                              onSelected: (val) => setState(() => _userGroups[i]['canAccessInventories'] = val),
                                            ),
                                            FilterChip(
                                              label: const Text('Edit World'),
                                              selected: _userGroups[i]['canEditWorld'] ?? false,
                                              onSelected: (val) => setState(() => _userGroups[i]['canEditWorld'] = val),
                                            ),
                                            FilterChip(
                                              label: const Text('Edit Base'),
                                              selected: _userGroups[i]['canEditBase'] ?? false,
                                              onSelected: (val) => setState(() => _userGroups[i]['canEditBase'] = val),
                                            ),
                                            FilterChip(
                                              label: const Text('Extend Base'),
                                              selected: _userGroups[i]['canExtendBase'] ?? false,
                                              onSelected: (val) => setState(() => _userGroups[i]['canExtendBase'] = val),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          // TAB 3: ENEMIES
                          ListView(
                            children: [
                              const Text("Enemy Customization", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 10),
                              _buildDiscreteSlider('Enemy Damage', 'enemyDamageFactor', [25, 50, 75, 100, 125, 150, 175, 200, 225, 250]),
                              _buildDiscreteSlider('Boss Damage', 'bossDamageFactor', [20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 250, 300, 350, 400, 450, 500]),
                              _buildDiscreteSlider('Enemy Health', 'enemyHealthFactor', [25, 50, 75, 100, 200, 300, 400]),
                              _buildDiscreteSlider('Boss Health', 'bossHealthFactor', [20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 250, 300, 350, 400]),
                              _buildDiscreteSlider('Enemy Stamina', 'enemyStaminaFactor', [50, 75, 100, 125, 150, 175, 200]),
                              _buildDiscreteSlider('Enemy Perception Range', 'enemyPerceptionRangeFactor', [50, 75, 100, 125, 150, 175, 200]),
                              const Divider(height: 30),
                              _buildSwitch('Pacify All Enemies', 'pacifyAllEnemies'),
                              _buildDropdown('Simultaneous Enemy Attacks (Aggro Pool)', 'aggroPoolAmount', ['Few', 'Normal', 'Many', 'Extreme']),
                              _buildDropdown('Enemy Amount', 'randomSpawnerAmount', ['Automatic', 'Few', 'Normal', 'Many', 'Extreme']),
                            ],
                          ),

                          // TAB 4: PLAYER
                          ListView(
                            children: [
                              const Text("Player Customization", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 10),
                              _buildDiscreteSlider('Player Health', 'playerHealthFactor', [25, 50, 75, 100, 150, 200, 300, 400]),
                              _buildDiscreteSlider('Player Mana', 'playerManaFactor', [25, 50, 75, 100, 150, 200, 300, 400]),
                              _buildDiscreteSlider('Player Stamina', 'playerStaminaFactor', [25, 50, 75, 100, 150, 200, 300, 400]),
                              _buildDiscreteSlider('Frost Resistance Duration (Body Heat)', 'playerBodyHeatFactor', [50, 75, 100, 150, 200]),
                              _buildDiscreteSlider('Diving Time', 'playerDivingTimeFactor', [50, 75, 100, 150, 200]),
                              _buildDiscreteSlider('Mining XP', 'experienceMiningFactor', [0, 25, 50, 75, 100, 150, 200, 300]),
                              _buildDiscreteSlider('Quest & Exploration XP', 'experienceExplorationQuestsFactor', [25, 50, 75, 100, 150, 200, 300]),
                              _buildDiscreteSlider('Combat XP', 'experienceCombatFactor', [25, 50, 75, 100, 150, 200, 300]),
                            ],
                          ),

                          // TAB 5: SURVIVAL
                          ListView(
                            children: [
                              const Text("Survival Customization", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 10),
                              _buildTimeSlider('Time until Starvation', 'fromHungerToStarving', [5, 8, 10, 15]),
                              _buildDiscreteSlider('Time in the Shroud', 'shroudTimeFactor', [50, 60, 70, 80, 90, 100, 125, 150, 200]),
                              _buildIntSlider('Required Flame Level for Shroud Removal', 'flameLevelFogRemoval', 1, 11),
                              _buildTimeSlider('Day Duration', 'dayTimeDuration', [2, 4, 6, 8, 12, 20, 30, 45, 60]),
                              _buildTimeSlider('Night Duration', 'nightTimeDuration', [2, 4, 6, 8, 12, 20, 30, 45, 60]),
                              _buildDiscreteSlider('Food Buff Duration', 'foodBuffDurationFactor', [50, 60, 70, 80, 90, 100, 125, 150, 175, 200]),
                              
                              const Divider(height: 30),
                              _buildSwitch('Starvation Mode', 'enableStarvingDebuff'),
                              _buildSwitch('Weapon Durability', 'enableDurability'),
                              _buildSwitch('Glider Turbulences', 'enableGliderTurbulences'),
                              _buildDropdown('Tombstone Mode (Loot Loss)', 'tombstoneMode', ['AddBackpackMaterials', 'Everything', 'NoTombstone']),
                              _buildDropdown('Harsh Weather Occurrences', 'weatherFrequency', ['Disabled', 'Rare', 'Normal', 'Often']),
                              _buildDropdown('Fishing Difficulty', 'fishingDifficulty', ['VeryEasy', 'Easy', 'Normal', 'Hard', 'VeryHard']),
                              _buildDropdown('Taming Startle Repercussion', 'tamingStartleRepercussion', ['KeepProgress', 'LoseSomeProgress', 'LoseAllProgress']),
                              _buildDropdown('Curse Modifier', 'curseModifier', ['Easy', 'Normal', 'Hard']),
                            ],
                          ),

                          // TAB 6: RESOURCES
                          ListView(
                            children: [
                              const Text("Resources Customization", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 10),
                              _buildDiscreteSlider('Workshop Production Speed', 'factoryProductionSpeedFactor', [25, 50, 75, 100, 125, 150, 175, 200, 300]),
                              _buildDiscreteSlider('Plant Growth Speed', 'plantGrowthSpeedFactor', [25, 50, 75, 100, 125, 150, 175, 200, 300]),
                              _buildDiscreteSlider('Weapon Upgrade Cost', 'perkCostFactor', [25, 30, 50, 75, 100, 125, 150, 175, 200]),
                              _buildDiscreteSlider('Equipment Upgrade Recycling Yield', 'perkUpgradeRecyclingFactor', [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]),
                              _buildDiscreteSlider('Mining Damage', 'miningDamageFactor', [50, 75, 100, 150, 200, 300]),
                              _buildDiscreteSlider('Loot Amount', 'resourceDropStackAmountFactor', [25, 50, 75, 100, 150, 200, 300]),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: isConfigReady ? _saveConfig : null,
                          icon: const Icon(Icons.save), label: const Text('Save'),
                        ),
                        const SizedBox(width: 16),
                        if (_savedStatus) const Text('JSON updated successfully!', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              
              // RECHTER KANT: Server Console
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Server Management & Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: (_isRunning || _isUpdating || !isConfigReady) ? null : _startServer,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
                          icon: const Icon(Icons.play_arrow), label: const Text('Start'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isRunning ? _stopServer : null,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                          icon: const Icon(Icons.stop), label: const Text('Stop'),
                        ),
                        ElevatedButton.icon(
                          onPressed: (_isRunning || _isUpdating || !isConfigReady) ? null : _updateServer,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                          icon: const Icon(Icons.system_update), label: const Text('Update'),
                        ),
                        if (_serverUpdateAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade900,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orangeAccent),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.priority_high, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  "UPDATE AVAILABLE!",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Text(_consoleOutput, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.greenAccent)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}