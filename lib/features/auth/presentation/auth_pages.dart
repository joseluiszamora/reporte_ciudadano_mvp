import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validation/input_limits.dart';
import '../domain/app_user.dart';
import 'auth_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.auth});
  final AuthCubit auth;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Iniciar sesión'),
      leading: IconButton(
        tooltip: 'Volver al mapa',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/mapa'),
      ),
    ),
    body: BlocBuilder<AuthCubit, AuthState>(
      bloc: auth,
      builder: (context, state) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Participa con tu cuenta de Google',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Después de iniciar sesión elegirás tu nombre público. Podrás publicar cada reporte de forma anónima.',
                ),
                const SizedBox(height: 16),
                if (state.initializing || state.busy)
                  const CircularProgressIndicator(),
                if (state.issue != null) Text(state.issue!),
                if (state.message != null)
                  Text(
                    state.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      state.initializing || state.busy || state.issue != null
                      ? null
                      : auth.signIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continuar con Google'),
                ),
                TextButton(
                  onPressed: () => context.go('/mapa'),
                  child: const Text('Seguir explorando sin sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PublicNameForm extends StatefulWidget {
  const PublicNameForm({super.key, required this.auth, this.initialName = ''});
  final AuthCubit auth;
  final String initialName;
  @override
  State<PublicNameForm> createState() => _PublicNameFormState();
}

class _PublicNameFormState extends State<PublicNameForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    bloc: widget.auth,
    builder: (context, state) => Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: name,
            enabled: !state.busy,
            maxLength: InputLimits.nameMax,
            decoration: const InputDecoration(labelText: 'Nombre público'),
            textCapitalization: TextCapitalization.words,
            validator: (value) => InputLimits.text(
              value ?? '',
              min: InputLimits.nameMin,
              max: InputLimits.nameMax,
            ),
          ),
          const Text(
            'Este nombre se mostrará solo cuando elijas publicar con atribución. No modifica el nombre de tus reportes anteriores.',
          ),
          const SizedBox(height: 12),
          if (state.message != null)
            Text(
              state.message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: state.busy
                ? null
                : () {
                    if (form.currentState!.validate()) {
                      widget.auth.completeName(name.text.trim());
                    }
                  },
            child: Text(state.busy ? 'Guardando…' : 'Guardar nombre'),
          ),
        ],
      ),
    ),
  );
}

class PublicNamePage extends StatelessWidget {
  const PublicNamePage({super.key, required this.auth});
  final AuthCubit auth;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Elige tu nombre público')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Completa tu perfil para crear reportes y proponer soluciones.',
          ),
          const SizedBox(height: 20),
          PublicNameForm(auth: auth),
          TextButton(
            onPressed: () => context.go('/mapa'),
            child: const Text('Completar más tarde y explorar'),
          ),
          TextButton(
            onPressed: auth.state.busy ? null : auth.signOut,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    ),
  );
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.user, required this.auth});
  final AppUser user;
  final AuthCubit auth;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            foregroundImage: user.photoUrl?.startsWith('https://') ?? false
                ? NetworkImage(user.photoUrl!)
                : null,
            onForegroundImageError:
                user.photoUrl?.startsWith('https://') ?? false
                ? (_, _) {}
                : null,
            child: const Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.googleName ??
                  (user.publicName.isEmpty
                      ? 'Completa tu perfil'
                      : user.publicName),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
      if (user.role == UserRole.admin) const Text('Administrador local'),
      const SizedBox(height: 16),
      PublicNameForm(
        key: ValueKey(user.uid),
        auth: auth,
        initialName: user.publicName,
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: auth.state.busy ? null : auth.signOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Cerrar sesión'),
      ),
    ],
  );
}
