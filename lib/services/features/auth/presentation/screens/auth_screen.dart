import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatbox/services/features/home/home_screen.dart';
import 'package:chatbox/services/features/courier/presentation/screens/radar_screen.dart';
import 'package:chatbox/core/config/api_config.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthState {
  final String? token;
  final String? role;
  final String? name;
  final String? userId;

  const AuthState({this.token, this.role, this.name, this.userId});

  bool get isLoggedIn => token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadSession();
  }

  /// Carga la sesión guardada al iniciar la app
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final role = prefs.getString('auth_role');
    final name = prefs.getString('auth_name');
    final userId = prefs.getString('auth_user_id');
    if (token != null && role != null && name != null && userId != null) {
      state = AuthState(token: token, role: role, name: name, userId: userId);
    }
  }

  Future<void> setSession(String token, String role, String name, String userId) async {
    state = AuthState(token: token, role: role, name: name, userId: userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_role', role);
    await prefs.setString('auth_name', name);
    await prefs.setString('auth_user_id', userId);
  }

  Future<void> logout() async {
    state = const AuthState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_role');
    await prefs.remove('auth_name');
    await prefs.remove('auth_user_id');
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Register controllers
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  
  // Courier specific controllers
  final _regPhoneCtrl = TextEditingController();
  final _regIdCtrl = TextEditingController();
  String _vehicleType = 'MOTORCYCLE';
  bool _isAdult = false;
  bool _acceptedTerms = false;
  
  // Fotos de verificación
  File? _idFrontImage;
  File? _idBackImage;
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Chequear sesión guardada y redirigir automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final role = prefs.getString('auth_role');
      final name = prefs.getString('auth_name');
      final userId = prefs.getString('auth_user_id');
      if (token != null && role != null && name != null && userId != null) {
        ref.read(authProvider.notifier).setSession(token, role, name, userId);
        if (mounted) _navigateByRole(role);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loginEmailCtrl.text.isEmpty || _loginPassCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': _loginEmailCtrl.text.trim(),
          'password': _loginPassCtrl.text,
        },
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ref.read(authProvider.notifier).setSession(
          data['access_token'], data['role'], data['name'], data['user_id']
        );
        _navigateByRole(data['role']);
      } else {
        _showError(data['detail'] ?? 'Error al iniciar sesión');
      }
    } catch (e) {
      _showError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (_regNameCtrl.text.isEmpty || _regEmailCtrl.text.isEmpty || _regPassCtrl.text.isEmpty) return;
    
    if (!_acceptedTerms) {
      _showError('Debes aceptar los términos, condiciones y derechos para continuar');
      return;
    }

    final currentRole = ref.read(appRoleProvider);
    if (currentRole == 'COURIER') {
      if (_idFrontImage == null || _idBackImage == null || _selfieImage == null) {
        _showError('Debes subir las 3 fotos obligatorias (Cédula y Selfie)');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> payload = {
        'name': _regNameCtrl.text.trim(),
        'email': _regEmailCtrl.text.trim(),
        'password': _regPassCtrl.text,
        'role': currentRole,
      };

      if (currentRole == 'COURIER') {
        if (!_isAdult) {
          _showError('Debes confirmar que eres mayor de edad');
          setState(() => _isLoading = false);
          return;
        }
        if (_regPhoneCtrl.text.isEmpty || _regIdCtrl.text.isEmpty) {
          _showError('Cédula y teléfono son obligatorios');
          setState(() => _isLoading = false);
          return;
        }
        payload['phone_number'] = _regPhoneCtrl.text.trim();
        payload['national_id'] = _regIdCtrl.text.trim();
        payload['vehicle_type'] = _vehicleType;
        payload['is_adult'] = _isAdult;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final token = data['access_token'];
        ref.read(authProvider.notifier).setSession(
          token, data['role'], data['name'], data['user_id']
        );

        // Si es repartidor, subimos las imágenes
        if (currentRole == 'COURIER') {
          var uri = Uri.parse('${ApiConfig.baseUrl}/couriers/documents');
          var request = http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $token'
            ..files.add(await http.MultipartFile.fromPath('id_front', _idFrontImage!.path))
            ..files.add(await http.MultipartFile.fromPath('id_back', _idBackImage!.path))
            ..files.add(await http.MultipartFile.fromPath('selfie', _selfieImage!.path));

          var res = await request.send();
          if (res.statusCode != 200) {
            _showError('Cuenta creada, pero hubo un error subiendo fotos.');
            setState(() => _isLoading = false);
            return;
          }
        }

        _navigateByRole(data['role']);
      } else {
        _showError(data['detail'] ?? 'Error al registrarse');
      }
    } catch (e) {
      _showError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(String role) {
    if (role == 'COURIER') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RadarScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // Panel modal actualizado con Términos, Condiciones y Derechos
  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Términos, Condiciones y Derechos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                'Última actualización: Septiembre 2026\n\n'
                'Bienvenido a Lorivery. Al registrarte y utilizar nuestra plataforma en Lorica, aceptas las normativas de intermediación para servicios de entrega y movilidad.\n\n'
                '1. Derechos de los Usuarios (Clientes y Repartidores):\n'
                '• Derecho a la privacidad y protección de tus datos personales conforme a la ley vigente.\n'
                '• Derecho a recibir un servicio transparente, con tarifas de entrega claras y sin cobros ocultos.\n'
                '• Derecho a soporte y asistencia ante cualquier incidencia reportada con tus pedidos o rutas.\n'
                '• Derecho a solicitar la actualización, rectificación o eliminación de tu cuenta y datos asociados en cualquier momento.\n\n'
                '2. Términos y Condiciones de Uso:\n'
                '• Lorivery actúa como una plataforma tecnológica que conecta comercios, usuarios y repartidores independientes.\n'
                '• Eres responsable de mantener la seguridad de tu cuenta y contraseña de acceso.\n'
                '• Tanto clientes como repartidores deben mantener un trato respetuoso. Nos reservamos el derecho de suspender cuentas que incumplan las normas de convivencia y seguridad ciudadana.\n\n'
                '3. Privacidad:\n'
                'Tus datos de ubicación y contacto son utilizados estrictamente para la operatividad y seguimiento de los servicios solicitados dentro del municipio.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentRole = ref.watch(appRoleProvider);
    final isCourierApp = currentRole == 'COURIER';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCourierApp ? Icons.motorcycle_rounded : Icons.electric_moped_rounded,
                        size: 36,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCourierApp ? 'Lorivery Repartidores' : 'Lorivery',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCourierApp ? 'Panel exclusivo para motorizados' : 'La ciudad en tus manos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [Tab(text: 'Iniciar Sesión'), Tab(text: 'Registrarse')],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      return _tabController.index == 0 ? _buildLoginView() : _buildRegisterView(isCourierApp);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(_loginEmailCtrl, 'Correo electrónico', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildPasswordField(_loginPassCtrl, 'Contraseña'),
        const SizedBox(height: 24),
        _buildButton('Entrar', _login),
      ],
    );
  }

  Widget _buildRegisterView(bool isCourierApp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(_regNameCtrl, 'Nombre completo', Icons.person_outline),
        const SizedBox(height: 12),
        _buildTextField(_regEmailCtrl, 'Correo electrónico', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildPasswordField(_regPassCtrl, 'Contraseña'),
        
        if (isCourierApp) ...[
          const SizedBox(height: 12),
          _buildTextField(_regPhoneCtrl, 'Teléfono móvil', Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _buildTextField(_regIdCtrl, 'Cédula de ciudadanía', Icons.badge_outlined, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _vehicleType,
            decoration: InputDecoration(
              labelText: 'Tipo de Vehículo',
              prefixIcon: const Icon(Icons.two_wheeler, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            items: const [
              DropdownMenuItem(value: 'MOTORCYCLE', child: Text('Motocicleta')),
              DropdownMenuItem(value: 'BICYCLE', child: Text('Bicicleta')),
            ],
            onChanged: (v) => setState(() => _vehicleType = v!),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('Confirmo que soy mayor de edad (18+)', style: TextStyle(fontSize: 13)),
            value: _isAdult,
            onChanged: (v) => setState(() => _isAdult = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 12),
          const Text('Verificación de Identidad (Requerido)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          _buildImagePicker('Cédula Frontal', _idFrontImage, () async {
            final xfile = await _picker.pickImage(source: ImageSource.camera);
            if (xfile != null) setState(() => _idFrontImage = File(xfile.path));
          }),
          const SizedBox(height: 8),
          _buildImagePicker('Cédula Posterior', _idBackImage, () async {
            final xfile = await _picker.pickImage(source: ImageSource.camera);
            if (xfile != null) setState(() => _idBackImage = File(xfile.path));
          }),
          const SizedBox(height: 8),
          _buildImagePicker('Selfie (Rostro)', _selfieImage, () async {
            final xfile = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
            if (xfile != null) setState(() => _selfieImage = File(xfile.path));
          }),
        ],

        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: Wrap(
                children: [
                  const Text('Acepto los ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  GestureDetector(
                    onTap: _showTermsModal,
                    child: Text(
                      'Términos, Condiciones y Derechos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        _buildButton('Crear Cuenta', _register),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade600),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey.shade600),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  Widget _buildImagePicker(String label, File? imageFile, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(imageFile != null ? Icons.check_circle : Icons.camera_alt, 
                 color: imageFile != null ? Colors.green : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                imageFile != null ? '$label (Capturada)' : 'Tomar foto: $label',
                style: TextStyle(
                  color: imageFile != null ? Colors.green.shade700 : Colors.black87,
                  fontWeight: imageFile != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}