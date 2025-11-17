import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const FisioTrackApp());
}

class FisioTrackApp extends StatelessWidget {
  const FisioTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FisioTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------- SPLASH (abre primeiro) ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedUser = prefs.getString('loggedUser');
    await Future.delayed(const Duration(seconds: 2));

    if (loggedUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: loggedUser)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "FisioTrack 💪",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
}

// ---------------- LOGIN ----------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];

    final user = userController.text.trim();
    final pass = passController.text.trim();

    for (var u in users) {
      final data = u.split(':');
      if (data.length == 2 && data[0] == user && data[1] == pass) {
        await prefs.setString('loggedUser', user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(userName: user)),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuário ou senha incorretos!')),
    );
  }

  void _goToRegister() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("FisioTrack 💪",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 40),
              TextField(
                controller: userController,
                decoration: const InputDecoration(
                  labelText: "Usuário",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Senha",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Entrar", style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: _goToRegister,
                child: const Text("Criar conta", style: TextStyle(color: Colors.green, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- CADASTRO ----------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController idadeController = TextEditingController();
  final TextEditingController diagnosticoController = TextEditingController();
  final TextEditingController telefoneController = TextEditingController();

  bool semDiagnostico = false;

  Future<void> _register() async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];

    final user = userController.text.trim();
    final pass = passController.text.trim();
    final nome = nomeController.text.trim();
    final idade = idadeController.text.trim();
    final diagnostico =
        semDiagnostico ? "Sem diagnóstico" : diagnosticoController.text.trim();
    final telefone = telefoneController.text.trim();

    if (user.isEmpty ||
        pass.isEmpty ||
        nome.isEmpty ||
        idade.isEmpty ||
        telefone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios!')),
      );
      return;
    }

    if (users.any((u) => u.startsWith('$user:'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário já existe!')),
      );
      return;
    }

    // Armazena usuário e senha
    users.add('$user:$pass');
    await prefs.setStringList('users', users);

    // Armazena dados extras do paciente
  await prefs.setString('user_${user}_nome', nome);
  await prefs.setString('user_${user}_idade', idade);
  await prefs.setString('user_${user}_diagnostico', diagnostico);
  await prefs.setString('user_${user}_telefone', telefone);




    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastro realizado com sucesso!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text("Cadastro de Paciente"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: "Nome completo",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: idadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Idade",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: semDiagnostico,
                  onChanged: (value) {
                    setState(() => semDiagnostico = value ?? false);
                  },
                ),
                const Text("Não tenho diagnóstico"),
              ],
            ),
            if (!semDiagnostico)
              TextField(
                controller: diagnosticoController,
                decoration: const InputDecoration(
                  labelText: "Diagnóstico",
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: telefoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Telefone",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                labelText: "Usuário (login)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Senha",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Cadastrar", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- HOME ----------------
class HomeScreen extends StatelessWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  final List<String> exercicios = const [
    "Flexão de Cotovelo",
    "Elevação de Braço",
    "Rotação de Ombro",
  ];

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedUser');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Olá, $userName 👋"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: exercicios.length,
        itemBuilder: (context, index) {
          final exercicio = exercicios[index];
          return Card(
            margin: const EdgeInsets.all(10),
            elevation: 4,
            child: ListTile(
              title: Text(exercicio),
              trailing: const Icon(Icons.play_arrow, color: Colors.green),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExercicioScreen(nomeExercicio: exercicio),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------- EXERCÍCIO ----------------
class ExercicioScreen extends StatefulWidget {
  final String nomeExercicio;
  const ExercicioScreen({super.key, required this.nomeExercicio});

  @override
  State<ExercicioScreen> createState() => _ExercicioScreenState();
}

class _ExercicioScreenState extends State<ExercicioScreen> {
  int segundos = 0;
  int repeticoes = 0;
  int angulo = 0;
  Timer? timer;
  bool emExecucao = false;

  void iniciarExercicio() {
    setState(() {
      emExecucao = true;
      segundos = 0;
      repeticoes = 0;
      angulo = 0;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        segundos++;
        angulo = 90 + (segundos % 10) * 3;
        if (segundos % 5 == 0) repeticoes++;
      });
    });
  }

  void concluirExercicio() {
    timer?.cancel();
    setState(() => emExecucao = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Exercício concluído! 🎉"),
        content: Text("Você completou $repeticoes repetições em $segundos segundos."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeExercicio),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Tempo: $segundos s", style: const TextStyle(fontSize: 22)),
            Text("Repetições: $repeticoes", style: const TextStyle(fontSize: 22)),
            Text("Ângulo: $angulo°", style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 40),
            emExecucao
                ? ElevatedButton(
                    onPressed: concluirExercicio,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text("Concluir"),
                  )
                : ElevatedButton(
                    onPressed: iniciarExercicio,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("Iniciar Exercício"),
                  ),
          ],
        ),
      ),
    );
  }
}
