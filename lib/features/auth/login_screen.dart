import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/features/dashboard/dashboard_screen.dart';
import 'package:smart_entry/core/widgets/blinking_logo_loader.dart';
import 'package:smart_entry/core/app_state.dart';
import 'package:smart_entry/core/localization/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _savedUsername;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
  }

  Future<void> _loadSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('last_username');
    if (savedUser != null && savedUser.isNotEmpty) {
      setState(() {
        _savedUsername = savedUser;
        _usernameController.text = savedUser;
      });
    }
  }

  Future<void> _login() async {
    String inputUsername = _usernameController.text.trim();
    String inputPassword = _passwordController.text.trim();

    if (inputUsername.isEmpty || inputPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.enterUsernameAndPasswordPrompt)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var userDoc = await Supabase.instance.client
          .from('app_users')
          .select('password, organization_id')
          .eq('username', inputUsername)
          .maybeSingle();

      if (userDoc == null) {
        throw Exception(AppStrings.invalidUsername);
      }

      String dbPassword = userDoc['password'].toString();

      if (inputPassword == dbPassword) {
        // Set Organization ID globally
        AppState.currentOrganizationId.value = userDoc['organization_id'].toString();
        AppState.currentUsername.value = inputUsername;

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.invalidPassword),
              backgroundColor: Colors.red,
            ),
          );
          _passwordController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorPrefix}$e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildBrandingPanel(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.format_quote_rounded,
          size: 60,
          color: Theme.of(context).primaryColor.withOpacity(0.8),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.loginTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            color: Colors.blueGrey,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 40,
          height: 3,
          color: Theme.of(context).primaryColor.withOpacity(0.5),
        ),
        const SizedBox(height: 24),
        const Text(
          "SMART ENTRY",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, {bool isMobile = false}) {
    final borderRadius = isMobile
        ? const BorderRadius.vertical(top: Radius.circular(40))
        : BorderRadius.circular(24);

    return Container(
      width: isMobile ? double.infinity : null,
      constraints: isMobile ? null : const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 30,
            spreadRadius: 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: isMobile
                ? const EdgeInsets.only(left: 32, right: 32, top: 48, bottom: 48)
                : const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: borderRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.eco,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Smart Entry',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // If saved username, show Welcome, else show Username Field
                if (_savedUsername != null) ...[
                  Text(
                    AppStrings.isSinhala ? 'නැවත සාදරයෙන් පිළිගනිමු, $_savedUsername!' : 'Welcome back, $_savedUsername!',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Username Field
                  TextField(
                    controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: AppStrings.username,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
                const SizedBox(height: 16),
              ],

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: AppStrings.password,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 32),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF42A5F5).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: Text(
                      AppStrings.loginButton,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_savedUsername != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _savedUsername = null;
                        _usernameController.clear();
                        _passwordController.clear();
                      });
                    },
                    child: Text(AppStrings.logInWithAnotherAccount, style: const TextStyle(color: Colors.blueGrey)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.blue.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BlinkingLogoLoader(size: 60),
              const SizedBox(height: 16),
              Text(
                AppStrings.verifyingPassword,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.blue.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 800;

          if (isDesktop) {
            return Row(
              children: [
                // Left Side - Branding & Quote
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: _buildBrandingPanel(context),
                    ),
                  ),
                ),
                // Right Side - Login Form
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: _buildLoginForm(context),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile layout
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48.0, left: 32.0, right: 32.0, bottom: 32.0),
                        child: _buildBrandingPanel(context),
                      ),
                    ),
                  ),
                ),
                _buildLoginForm(context, isMobile: true),
              ],
            );
          }
        },
      ),
    );
  }
}
