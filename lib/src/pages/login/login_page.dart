import 'package:flutter/material.dart';
import 'package:grupo_alessat_app/src/api/api_service.dart';
import 'package:grupo_alessat_app/src/models/login_request.dart';
import 'package:grupo_alessat_app/src/pages/home/home_page.dart';
import 'package:window_manager/window_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false; // Estado para controlar a visibilidade da senha
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _setWindowBehavior();
  }

  @override
  void dispose() {
    _resetWindowBehavior();
    super.dispose();
  }

  Future<void> _setWindowBehavior() async {
    await windowManager.ensureInitialized();
    // Configurar a janela para tamanho fixo e desativar maximização
    await windowManager.setSize(const Size(800, 600)); // Tamanho fixo
    await windowManager.setResizable(false); // Desativar redimensionamento
    await windowManager.setMaximizable(false); // Desativar maximização
  }

  Future<void> _resetWindowBehavior() async {
    await windowManager.setMaximizable(true);
    // Restaura o comportamento padrão (permitir redimensionar e maximizar)
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final request = LoginRequest(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final response = await _apiService.login(request);

      if (response.token.isNotEmpty) {
        await _resetWindowBehavior();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(token: response.token)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    }
  }

  void _showRecoverPasswordDialog() {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1e262d),
          title: const Text(
            'Recuperar Senha',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Digite seu e-mail',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF2C333A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0794bc),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
                onPressed: () {
                  // Validação do e-mail
                  final email = emailController.text.trim();
                  if (_isValidEmail(email)) {
                    // Simula o envio do e-mail
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Instruções de recuperação enviadas para $email',
                        ),
                      ),
                    );
                    Navigator.pop(context); // Fechar o diálogo
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, insira um e-mail válido'),
                      ),
                    );
                  }
                },
                child: const Text('Enviar'),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isValidEmail(String email) {
    // Validação básica de e-mail com regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$',
    );
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF1e262d),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/logo-login-alessat-dark.png'),
                  const SizedBox(height: 20),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome de usuário ou chave de acesso',
                        labelStyle: TextStyle(color: Colors.white),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Campo obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: const TextStyle(color: Colors.white),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_passwordVisible, // Controla a visibilidade da senha
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Campo obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                  // const SizedBox(height: 20),
                  // Center(
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.center,
                  //     children: [
                  //       Transform.scale(
                  //         scale: 0.7,
                  //         child: Switch(
                  //           value: _rememberPassword,
                  //           onChanged: (value) {
                  //             setState(() {
                  //               _rememberPassword = value;
                  //             });
                  //           },
                  //           activeColor: Colors.blue,
                  //         ),
                  //       ),
                  //       const Text(
                  //         'Lembrar senha',
                  //         style: TextStyle(color: Colors.white),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0794bc),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                      ),
                      onPressed: _login,
                      child: const Text('Confirmar'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // SizedBox(
                  //   width: 250,
                  //   height: 40,
                  //   child: ElevatedButton(
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.transparent,
                  //       foregroundColor: Colors.white,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(5.0),
                  //         side: const BorderSide(color: Colors.white, width: 1.0),
                  //       ),
                  //     ),
                  //     onPressed: _showRecoverPasswordDialog,
                  //     child: const Text('Recuperar Senha'),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
