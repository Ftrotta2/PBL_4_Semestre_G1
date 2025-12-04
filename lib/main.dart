import 'dart:io';        
import 'dart:convert';   
import 'dart:async';     
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:http/http.dart' as http; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'video_player_screen.dart';
import 'streak_manager.dart';
import 'package:lottie/lottie.dart';

// --- MODELO DE DADOS (Sinais Discretos) ---
class SensorData {
  final double tempoS;
  final double anguloJoelho; 
  final double anguloTornozelo; 
  final double p1, r1, y1; 
  final double p2, r2, y2; 
  final double p3, r3, y3; 
  final int tMs; 

  SensorData({
    required this.tempoS,
    required this.anguloJoelho,
    required this.anguloTornozelo,
    required this.p1, required this.r1, required this.y1,
    required this.p2, required this.r2, required this.y2,
    required this.p3, required this.r3, required this.y3,
    required this.tMs,
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await streakManager.init();
  await streakManager.resetIfMissed();
  runApp(const FisioTrackApp());
}

class FisioTrackApp extends StatelessWidget {
  const FisioTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOME-FISIO Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006A6A), // Verde Petróleo (Identidade)
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedUser = prefs.getString('loggedUser');
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    if (loggedUser != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(userName: loggedUser)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_heart_outlined, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text("HOME-FISIO", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 10),
            const Text("Tecnologia Assistiva em Reabilitação", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// --- LOGIN & CADASTRO (COM DADOS BIOMECÂNICOS) ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  final TextEditingController _loginUserController = TextEditingController();
  final TextEditingController _loginPassController = TextEditingController();
  
  final TextEditingController _regUserController = TextEditingController();
  final TextEditingController _regPassController = TextEditingController();
  
  // NOVOS CAMPOS: Necessários para o Cálculo de Torque/Força no Python
  final TextEditingController _regWeightController = TextEditingController(); 
  final TextEditingController _regHeightController = TextEditingController(); 
  String _selectedGender = "Masculino"; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];
    final user = _loginUserController.text.trim();
    final pass = _loginPassController.text.trim();

    bool found = false;
    for (var u in users) {
      // Formato: user:pass:peso:altura:genero
      final parts = u.split(':');
      if (parts.length >= 2 && parts[0] == user && parts[1] == pass) {
        found = true;
        break;
      }
    }

    if (found || (user == 'admin' && pass == '123')) {
      await prefs.setString('loggedUser', user.isEmpty ? 'Bruno' : user);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(userName: user.isEmpty ? 'Bruno' : user)));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciais inválidas!'), backgroundColor: Colors.red));
    }
  }

  Future<void> _register() async {
    final user = _regUserController.text.trim();
    final pass = _regPassController.text.trim();
    final weight = _regWeightController.text.trim();
    final height = _regHeightController.text.trim();

    if (user.isEmpty || pass.isEmpty || weight.isEmpty || height.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];
    
    if (users.any((u) => u.split(':').first == user)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário já existe!'), backgroundColor: Colors.red));
      return;
    }

    // SALVA NO FORMATO NOVO: user:pass:peso:altura:genero
    // Isso permite que o App mande esses dados para o Python depois
    users.add('$user:$pass:$weight:$height:$_selectedGender');
    await prefs.setStringList('users', users);

    await prefs.setString('loggedUser', user);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastro completo!'), backgroundColor: Colors.green));
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(userName: user)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUserController.dispose();
    _loginPassController.dispose();
    _regUserController.dispose();
    _regPassController.dispose();
    _regWeightController.dispose();
    _regHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Image.asset('assets/app_icon.jpeg', width: 64, height: 64),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF006A6A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF006A6A),
              tabs: const [Tab(text: 'Entrar'), Tab(text: 'Cadastrar')],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- Login ---
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          TextField(controller: _loginUserController, decoration: const InputDecoration(labelText: "Usuário", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                          const SizedBox(height: 16),
                          TextField(controller: _loginPassController, obscureText: true, decoration: const InputDecoration(labelText: "Senha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
                          const SizedBox(height: 24),
                          FilledButton(onPressed: _login, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), child: const Text("ENTRAR")),
                        ],
                      ),
                    ),

                    // --- Cadastro (BIOMECÂNICA) ---
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          TextField(controller: _regUserController, decoration: const InputDecoration(labelText: "Nome", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                          const SizedBox(height: 10),
                          TextField(controller: _regPassController, obscureText: true, decoration: const InputDecoration(labelText: "Senha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
                          
                          const SizedBox(height: 20),
                          const Text("Dados Fisiológicos (Para Análise)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 10),
                          
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _regWeightController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: "Peso (kg)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _regHeightController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: "Altura (m)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.height)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: const InputDecoration(labelText: "Gênero Biológico", border: OutlineInputBorder(), prefixIcon: Icon(Icons.transgender)),
                            items: const [
                              DropdownMenuItem(value: "Masculino", child: Text("Masculino")),
                              DropdownMenuItem(value: "Feminino", child: Text("Feminino")),
                            ],
                            onChanged: (val) => setState(() => _selectedGender = val!),
                          ),
                          const SizedBox(height: 10),
                          const Text("* Obrigatório para cálculo de Força e Torque.", style: TextStyle(fontSize: 12, color: Colors.grey)),

                          const SizedBox(height: 24),
                          FilledButton(onPressed: _register, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), child: const Text("CADASTRAR E ENTRAR")),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> exercicios = const [
    {"nome": "Flexão/Extensão de Joelho", "icone": Icons.accessibility_new, "color": Colors.blue, "video": "assets/videos/flexao.mp4"},
    {"nome": "Dorsiflexão/Plantiflexão", "icone": Icons.directions_walk, "color": Colors.orange, "video": "assets/videos/dorsiflexao.mp4"},
    {"nome": "Abdução de Quadril", "icone": Icons.boy_rounded, "color": Colors.purple, "video": "assets/videos/abducao_quadril.mp4"},
    {"nome": "Inversão dos Pés", "icone": Icons.fork_right, "color": Colors.teal, "video": "assets/videos/inversao_pes.mp4"},
    {"nome": "Coleta Livre (Geral)", "icone": Icons.show_chart, "color": Colors.green, "video": ""}
  ];

  StreakStatus? _status;

  @override
  void initState() {
    super.initState();
    _status = streakManager.getStatus();
  }

  Future<void> _refreshStreak() async {
    setState(() { _status = streakManager.getStatus(); });
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 88,
        flexibleSpace: Container(
          color: const Color(0xFF2E7D32),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image.asset('assets/app_icon.jpeg', width: 36, height: 36, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Olá, $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (widget.userName.trim() != firstName.trim()) ...[
                      const SizedBox(height: 4),
                      Text(widget.userName, style: const TextStyle(color: Colors.white)),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshStreak),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('loggedUser');
            if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          })
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Streak atual: ${_status?.currentStreak ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Melhor: ${_status?.bestStreak ?? 0} • Hoje: ${_status?.todayCount ?? 0}/${streakManager.requiredPerDay}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if ((_status?.todayCompleted ?? false)) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.asset(
                        'assets/streak_done.gif',
                        width: 48,
                        height: 48,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.celebration, color: Colors.green, size: 36),
                      ),
                    ),
                  ],
                  ElevatedButton(onPressed: _refreshStreak, child: const Text('Atualizar')),
                ],
              ),
            ),
          ),

          const Text("Selecione o Protocolo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...exercicios.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(item['icone'] as IconData, color: item['color'] as Color),
              ),
              title: Text(item['nome'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () async {
                final video = (item['video'] as String? ?? '');
                if (video.isNotEmpty) {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoAsset: video, nextScreen: ColetaScreen(nomeExercicio: item['nome'], nomePaciente: widget.userName))));
                } else {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ColetaScreen(nomeExercicio: item['nome'], nomePaciente: widget.userName)));
                }
                if (mounted) _refreshStreak();
              },
            ),
          )),
        ],
      ),
    );
  }
}

// --- TELA DE COLETA ---
class ColetaScreen extends StatefulWidget {
  final String nomeExercicio;
  final String nomePaciente;
  const ColetaScreen({super.key, required this.nomeExercicio, required this.nomePaciente});
  @override State<ColetaScreen> createState() => _ColetaScreenState();
}

class _ColetaScreenState extends State<ColetaScreen> {
  Socket? _socket;
  bool isConnected = false, isCalibrated = false, isZeroed = false, isCollecting = false;
  bool isCalibrating = false;
  int calibrationPercent = 0;
  Timer? _calibrationTimer;
  List<SensorData> dataPoints = [];
  
  int _plotDecimationCounter = 0;
  final int _plotDecimationRate = 5; 
  int? _startTimeMs;
  
  final TextEditingController _ipController = TextEditingController(text: "192.168.137.50"); 
  final String _flaskIp = "192.168.137.1"; 

  double _currentKnee = 0.0;
  double _currentAnkle = 0.0;

  bool _showGeneratingOverlay = false;
  final List<String> _overlayMessages = ['Gravando dados...', 'Gerando gráficos...', 'Processando...'];
  int _overlayMessageIndex = 0;
  Timer? _overlayTimer;

  @override void dispose() { if (isCollecting) _stopCollecting(); _disconnect(); _ipController.dispose(); super.dispose(); }

  Future<void> _connect() async {
    try {
      _socket = await Socket.connect(_ipController.text, 3333, timeout: const Duration(seconds: 3));
      _socket!.listen(_handleData, onError: (e) => _disconnect(), onDone: () => _disconnect());
      setState(() => isConnected = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conectado ao ESP32!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    }
  }

  void _disconnect() {
    _socket?.destroy();
    _stopCalibrationTimer();
    if(mounted) setState(() { _socket = null; isConnected=false; isCalibrated=false; isZeroed=false; isCollecting=false; });
  }

  void _cmd(String c) { _socket?.write('$c\n'); }

  void _startCalibration() {
    if (!isConnected) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conecte-se ao dispositivo antes de calibrar.'), backgroundColor: Colors.orange));
      return;
    }
    _cmd('c');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando calibração...'), backgroundColor: Colors.green));
      setState(() { isCalibrating = true; calibrationPercent = 1; });
    }

    _calibrationTimer?.cancel();
    _calibrationTimer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!mounted) return;
      setState(() {
        if (calibrationPercent < 98) calibrationPercent += 3;
      });
    });
  }

  void _stopCalibrationTimer() {
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    if (mounted) setState(() { isCalibrating = false; calibrationPercent = 0; });
  }

  void _startCollecting() {
    setState(() { dataPoints.clear(); _startTimeMs = null; isCollecting = true; });
    _postStatus(true);
    _startGeneratingOverlay();
  }

  Future<void> _stopCollecting() async {
    setState(() { isCollecting = false; });
    _postStatus(false);
    _setOverlayMessage('Gerando gráficos');
    Future.delayed(const Duration(milliseconds: 1200), () {
      _stopGeneratingOverlay();
    });

    if (dataPoints.isNotEmpty) {
      try {
        final current = streakManager.getStatus();
        if (current.todayCompleted) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Exercício concluído, Parabéns! (diária alcançada!).'),
            duration: Duration(seconds: 2),
          ));
          return;
        }

        final status = await streakManager.markExerciseDone();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Exercício registrado. Hoje: ${status.todayCount}/${streakManager.requiredPerDay}'),
            duration: const Duration(seconds: 2),
          ));
        }
      } catch (e) {}
    }
  }

  void _startGeneratingOverlay() {
    _overlayTimer?.cancel();
    setState(() {
      _showGeneratingOverlay = true;
      _overlayMessageIndex = 0;
    });
    _overlayTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() {
        _overlayMessageIndex = (_overlayMessageIndex + 1) % _overlayMessages.length;
      });
    });
  }

  void _stopGeneratingOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    setState(() { _showGeneratingOverlay = false; });
  }

  void _setOverlayMessage(String msg) {
    _overlayTimer?.cancel();
    setState(() {
      _showGeneratingOverlay = true;
    });
    _overlayTimer = Timer(const Duration(milliseconds: 1100), () {
      _stopGeneratingOverlay();
    });
  }

  Future<void> _postStatus(bool c) async { try { await http.post(Uri.parse("http://$_flaskIp:5000/status"), headers: {'Content-Type':'application/json'}, body: jsonEncode({"collecting": c})).timeout(const Duration(milliseconds: 500)); } catch(e){} }
  
  // --- UPLOAD PARA PC (ENVIA DADOS + FÍSICA) ---
  Future<void> _uploadToPC() async {
    if(dataPoints.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];
    
    // Valores default
    double pPeso = 70.0;
    double pAltura = 1.70;
    String pGenero = "Masculino";

    // Busca os dados do usuário logado
    for (var u in users) {
      final parts = u.split(':');
      if (parts.length >= 2 && parts[0] == widget.nomePaciente) {
        if (parts.length >= 5) {
          pPeso = double.tryParse(parts[2]) ?? 70.0;
          pAltura = double.tryParse(parts[3]) ?? 1.70;
          pGenero = parts[4];
        }
        break;
      }
    }

    final url = Uri.parse("http://$_flaskIp:5000/save_session");
    final payload = {
      "patient": widget.nomePaciente, 
      "exercise": widget.nomeExercicio,
      // Dados Biomecânicos
      "weight": pPeso,
      "height": pAltura,
      "gender": pGenero,
      // Sinais dos Sensores
      "data": dataPoints.map((d) => {
        "tempoS": d.tempoS, "anguloJoelho": d.anguloJoelho, "anguloTornozelo": d.anguloTornozelo,
        "p1": d.p1, "r1": d.r1, "y1": d.y1, "p2": d.p2, "r2": d.r2, "y2": d.y2, "p3": d.p3, "r3": d.r3, "y3": d.y3, "tMs": d.tMs
      }).toList()
    };

    try {
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.statusCode == 200 ? "Salvo no PC com Sucesso!" : "Erro no Servidor"), backgroundColor: resp.statusCode == 200 ? Colors.green : Colors.red));
    } catch(e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro envio: $e"), backgroundColor: Colors.red)); 
    }
  }

  void _handleData(List<int> d) {
    String m = String.fromCharCodes(d).trim();
    for (var line in m.split('\n')) {
      if (line.isEmpty) continue;
      try {
        var json = jsonDecode(line);
          if (json.containsKey('type')) {
             String t = json['type'];
             if (t == 'CAL_DONE') {
               _stopCalibrationTimer();
               if (mounted) setState(() { isCalibrated = true; calibrationPercent = 100; });
             }
             else if (t == 'ZERO_DONE') setState(() => isZeroed = true);
        } 
        else if (json.containsKey('sensor1') && isCollecting) {
           var s1 = json['sensor1'], s2 = json['sensor2'], s3 = json['sensor3'];
           int tMs = json['t'];
           if (_startTimeMs == null) _startTimeMs = tMs;
           
           double valJoelho = (s2['pitch'] as num).toDouble() - (s1['pitch'] as num).toDouble();
           double valTornozelo = (s3['pitch'] as num).toDouble() - (s2['pitch'] as num).toDouble();

           var newData = SensorData(
             tempoS: (tMs - _startTimeMs!) / 1000.0,
             anguloJoelho: valJoelho,
             anguloTornozelo: valTornozelo,
             p1: (s1['pitch'] as num).toDouble(), r1: (s1['roll'] as num).toDouble(), y1: (s1['yaw'] as num).toDouble(),
             p2: (s2['pitch'] as num).toDouble(), r2: (s2['roll'] as num).toDouble(), y2: (s2['yaw'] as num).toDouble(),
             p3: (s3['pitch'] as num).toDouble(), r3: (s3['roll'] as num).toDouble(), y3: (s3['yaw'] as num).toDouble(),
             tMs: tMs
           );
           
           dataPoints.add(newData);
           _plotDecimationCounter++;
           
           if (_plotDecimationCounter % _plotDecimationRate == 0) {
             setState(() {
               _currentKnee = valJoelho;
               _currentAnkle = valTornozelo;
             });
             try { http.post(Uri.parse("http://$_flaskIp:5000/data"), headers: {'Content-Type':'application/json'}, body: jsonEncode(json)).timeout(const Duration(milliseconds: 100)); } catch(e){}
           }
        }
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.nomeExercicio, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: isZeroed ? _buildMonitorDashboard() : _buildSetupWizard(),
          ),
        ],
      ),
      floatingActionButton: isZeroed ? FloatingActionButton.extended(
        onPressed: isCollecting ? _stopCollecting : _startCollecting,
        backgroundColor: isCollecting ? Colors.green : const Color(0xFF006A6A), // Verde quando parar
        icon: Icon(isCollecting ? Icons.stop : Icons.play_arrow),
        label: Text(isCollecting ? "PARAR" : "INICIAR"),
      ) : null,
    );
  }

  Widget _buildStatusBar() {
    Color statusColor = Colors.grey;
    String statusText = "Desconectado";
    if (isCollecting) { statusColor = Colors.green; statusText = "Coletando Dados"; }
    else if (isZeroed) { statusColor = Colors.blue; statusText = "Pronto para Iniciar"; }
    else if (isConnected) { statusColor = Colors.orange; statusText = "Aguardando Calibração"; }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (isCollecting) Text("${dataPoints.length} pts", style: const TextStyle(color: Colors.grey, fontSize: 12))
        ],
      ),
    );
  }

  Widget _buildSetupWizard() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildWizardStep("1. Conexão", "Conecte-se ao Wifi e ao ESP32.", "CONECTAR", isConnected, _connect),
        _buildWizardStep("2. Calibração", "Mantenha os sensores parados.", "CALIBRAR (Giroscópio)", isCalibrated, _startCalibration, enabled: isConnected, isRunning: isCalibrating, progress: calibrationPercent),
        _buildWizardStep("3. Posição Zero", "Coloque o paciente na posição inicial.", "ZERAR ANGULOS", isZeroed, () => _cmd('z'), enabled: isCalibrated),
      ],
    );
  }

  Widget _buildWizardStep(String title, String sub, String btnText, bool isDone, VoidCallback onAction, {bool enabled = true, bool isRunning = false, int progress = 0}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if(isDone) const Icon(Icons.check_circle, color: Colors.green)
              ]),
              Text(sub, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
                if(!isDone)
                if (isRunning)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(value: (progress / 100.0)),
                      const SizedBox(height: 8),
                      Text('$progress% - Calibrando...', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _stopCalibrationTimer();
                                try { _cmd('c_stop'); } catch(_){}
                              },
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _calibrationTimer?.cancel();
                                if (mounted) setState(() { calibrationPercent = 100; isCalibrating = false; isCalibrated = true; });
                              },
                              child: const Text('Simular CAL_DONE'),
                            ),
                          ),
                        ],
                      )
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(onPressed: enabled ? onAction : null, child: Text(btnText)),
                      ),
                      if (!enabled && !isRunning) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando calibração (debug)...'), backgroundColor: Colors.blue));
                                setState(() { isCalibrating = true; calibrationPercent = 1; });
                                _calibrationTimer?.cancel();
                                _calibrationTimer = Timer.periodic(const Duration(milliseconds: 300), (t) {
                                  if (!mounted) return;
                                  setState(() { if (calibrationPercent < 98) calibrationPercent += 3; });
                                });
                              }
                            },
                            child: const Text('Iniciar (debug)'),
                          ),
                        )
                      ]
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: enabled ? onAction : null, child: Text(btnText)),
                  )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonitorDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildValueCard("JOELHO", _currentKnee, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildValueCard("TORNOZELO", _currentAnkle, Colors.green)), // Verde pedido
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
                      lineBarsData: [
                        LineChartBarData(
                          spots: dataPoints.map((e) => FlSpot(e.tempoS, e.anguloJoelho)).toList(),
                          isCurved: true, 
                          color: Colors.blue,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                        ),
                        LineChartBarData(
                          spots: dataPoints.map((e) => FlSpot(e.tempoS, e.anguloTornozelo)).toList(),
                          isCurved: true,
                          color: Colors.green, // Verde pedido
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showGeneratingOverlay)
                  Container(
                    height: 300,
                    color: Colors.white.withOpacity(0.85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset('assets/doctor.json', width: 182, height: 182, repeat: true),
                          const SizedBox(height: 12),
                          Text(
                            _overlayTimer != null && _overlayTimer!.isActive && _overlayMessageIndex < _overlayMessages.length
                                ? _overlayMessages[_overlayMessageIndex]
                                : 'Processando...',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          if (!isCollecting && dataPoints.isNotEmpty) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _uploadToPC, 
              icon: const Icon(Icons.cloud_upload), 
              label: const Text("ENVIAR PARA PRONTUÁRIO"),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF006A6A), minimumSize: const Size(double.infinity, 50)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildValueCard(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.3), width: 2)
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("${val.toStringAsFixed(1)}°", style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}