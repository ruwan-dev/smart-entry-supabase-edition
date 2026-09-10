import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/features/dashboard/dashboard_screen.dart';
// (හෝ DashboardScreen එක තියෙන නිවැරදි path එක)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  
  // Hardcoded password එක ඉවත් කළා.
  // final String _correctPassword = "123"; 
  
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Loading තත්ත්වය පරීක්ෂා කිරීමට

  // Supabase වෙතින් මුරපදය පරීක්ෂා කරන අලුත් login function එක
  Future<void> _login() async {
    String inputPassword = _passwordController.text.trim();

    if (inputPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර මුරපදය ඇතුළත් කරන්න.')),
      );
      return;
    }

    setState(() { _isLoading = true; }); // Loading ආරම්භය

    try {
      // Supabase වෙතින් මුරපදය ලබා ගැනීම
      var adminDoc = await Supabase.instance.client
          .from('global_settings')
          .select('password')
          .eq('id', 'auth')
          .maybeSingle();

      if (adminDoc == null) {
        // ජාල දෝෂයක් හෝ document එක නැතිනම්
        throw Exception("මුරපද දත්ත සොයාගත නොහැකි විය. (Database error)");
      }

      String dbPassword = adminDoc['password'].toString();

      if (inputPassword == dbPassword) {
        // Navigate to Dashboard and remove Login Screen from backstack
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('මුරපදය වැරදියි! කරුණාකර නැවත උත්සාහ කරන්න.'),
              backgroundColor: Colors.red,
            ),
          );
          _passwordController.clear(); // input එක clear කිරීම
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('දෝෂයක් ඇති විය: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); } // Loading අවසන්
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading අවස්ථාවේදී පෙන්වන UI එක
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("මුරපදය පරීක්ෂා කරමින්...", style: TextStyle(color: Colors.grey),)
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true, // keyboard එක ආවම scroll වෙන්න ඉඩ දෙන්න
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.05),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco, // Tea leaf icon representation
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Smart Entry',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'කරුණාකර පරිපාලක මුරපදය ඇතුළත් කරන්න',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    onSubmitted: (_) => _login(), // Login when pressing enter on keyboard
                  ),
                  const SizedBox(height: 32),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text('ඇතුළු වන්න', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}