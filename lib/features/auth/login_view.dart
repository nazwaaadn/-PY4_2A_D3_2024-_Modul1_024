import 'package:flutter/material.dart';
import 'package:logbook_app_024/features/auth/login_controller.dart';
import 'package:logbook_app_024/features/alert_helper.dart';
import 'package:logbook_app_024/features/logbook/log_view.dart';
import 'dart:async';

class LoginView extends StatefulWidget {
  final bool fromLogout;
  const LoginView({super.key, this.fromLogout = false});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  int _failedAttempts = 0;
  bool _isButtonDisabled = false;
  Timer? _lockTimer;
  bool _isPasswordHidden = true;

  // Primary Color App
  final Color primaryColor = const Color.fromARGB(255, 0, 38, 77);

  void _handleLogin() {
    if (_isButtonDisabled) return;

    String user = _userController.text.trim();
    String pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      AlertHelper.show(
        context,
        type: 'error',
        message: 'Field tidak boleh kosong',
      );
      return;
    }

    bool isSuccess = _controller.login(user, pass);

    if (isSuccess) {
      _failedAttempts = 0;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LogView(currentUser: _controller.getUserData(user)),
        ),
      );
    } else {
      setState(() => _failedAttempts++);

      if (_failedAttempts >= 3) {
        setState(() => _isButtonDisabled = true);
        AlertHelper.show(
          context,
          type: 'error',
          message: "Terlalu banyak percobaan. Tunggu 10 detik.",
        );

        _lockTimer = Timer(const Duration(seconds: 10), () {
          if (!mounted) return;
          setState(() {
            _failedAttempts = 0;
            _isButtonDisabled = false;
          });
        });
      } else {
        AlertHelper.show(
          context,
          type: 'warning',
          message: "Login gagal ($_failedAttempts/3)",
        );
      }
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Jika dari logout, jangan izinkan back sama sekali
        if (widget.fromLogout) return false;
        // Jika dari onboarding, izinkan back jika ada route sebelumnya
        return Navigator.canPop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                // Back Button - hanya muncul jika BUKAN dari logout dan bisa pop
                if (!widget.fromLogout && Navigator.canPop(context))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: primaryColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                SizedBox(
                  height: (!widget.fromLogout && Navigator.canPop(context))
                      ? 20
                      : 60,
                ),
                // Logo Section
                Hero(
                  tag: 'logo',
                  child: Image.asset("assets/images/lingko.png", height: 180),
                ),
                const SizedBox(height: 30),

                // Text Header
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Masuk ke Akun",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 35),

                // Form Section
                _buildTextField(
                  controller: _userController,
                  label: "Username",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      "Lupa Password?",
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isButtonDisabled ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: _isButtonDisabled
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 25),

                // // Social Login Divider
                // Row(
                //   children: [
                //     Expanded(child: Divider(color: Colors.grey[300])),
                //     Padding(
                //       padding: const EdgeInsets.symmetric(horizontal: 10),
                //       child: Text(
                //         "O conéctate con",
                //         style: TextStyle(color: Colors.grey[500]),
                //       ),
                //     ),
                //     Expanded(child: Divider(color: Colors.grey[300])),
                //   ],
                // ),

                // const SizedBox(height: 20),

                // // Google Login
                // IconButton(
                //   iconSize: 40,
                //   icon: const FaIcon(
                //     FontAwesomeIcons.google,
                //     color: Colors.redAccent,
                //   ),
                //   onPressed: () {},
                // ),

                // const SizedBox(height: 20),

                // // Sign up Link
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     const Text("¿No tienes cuenta?"),
                //     TextButton(
                //       onPressed: () {},
                //       child: Text(
                //         "Regístrate",
                //         style: TextStyle(
                //           fontWeight: FontWeight.bold,
                //           color: primaryColor,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget untuk TextField agar kode lebih bersih
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isPasswordHidden : false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordHidden = !_isPasswordHidden),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 20,
          ),
        ),
      ),
    );
  }
}
