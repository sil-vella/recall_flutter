import 'package:flutter/material.dart';
import 'package:recall/utils/consts/theme_consts.dart';

class RegisterWidget extends StatefulWidget {
  final Future<void> Function(String username, String email, String password) onRegister;
  final VoidCallback onBackToLogin;

  const RegisterWidget({
    Key? key,
    required this.onRegister,
    required this.onBackToLogin,
  }) : super(key: key);

  @override
  _RegisterWidgetState createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegistering = false;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
    });

    await widget.onRegister(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() {
      _isRegistering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // **Register Title**
            Text(
              "Register",
              style: AppTextStyles.headingLarge(color: AppColors.accentColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // **Username Field**
            TextFormField(
              controller: _usernameController,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: "Username",
                prefixIcon: const Icon(Icons.person, color: AppColors.accentColor),
              ),
              validator: (value) => value!.length < 5 ? "Username must be at least 5 characters long." : null,
            ),
            const SizedBox(height: 12),

            // **Email Field**
            TextFormField(
              controller: _emailController,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email, color: AppColors.accentColor),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(value!)
                  ? "Enter a valid email."
                  : null,
            ),
            const SizedBox(height: 12),

            // **Password Field**
            TextFormField(
              controller: _passwordController,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock, color: AppColors.accentColor),
              ),
              obscureText: true,
              validator: (value) => value!.length < 8 ? "Password must be at least 8 characters long." : null,
            ),
            const SizedBox(height: 20),

            // **Register Button**
            ElevatedButton(
              onPressed: _isRegistering ? null : _registerUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isRegistering
                  ? const CircularProgressIndicator()
                  : Text("Create Account", style: AppTextStyles.buttonText),
            ),
            const SizedBox(height: 12),

            // **Toggle to Login Form**
            TextButton(
              onPressed: widget.onBackToLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentColor,
              ),
              child: const Text("Back to login", style: AppTextStyles.buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
