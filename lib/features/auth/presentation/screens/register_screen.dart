import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/presentation/providers/auth_state_notifier.dart';
import 'package:flutter_learn/features/auth/presentation/widgets/auth_text_field.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final formKey = useState(GlobalKey<FormState>());

    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      next.maybeWhen(
        error: (failure) {
          final message = switch (failure) {
            AuthFailure(:final message) => message,
            NetworkFailure() => 'ネットワークエラーが発生しました',
            UnexpectedFailure() => '予期しないエラーが発生しました',
          };
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        orElse: () {},
      );
    });

    final isLoading = ref.watch(
      authStateNotifierProvider
          .select((s) => s.maybeWhen(loading: () => true, orElse: () => false)),
    );

    Future<void> onRegister() async {
      if (!formKey.value.currentState!.validate()) return;
      await ref.read(authStateNotifierProvider.notifier).signUpWithEmail(
            emailController.text.trim(),
            passwordController.text,
          );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント作成')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                AuthTextField(
                  controller: emailController,
                  label: 'メールアドレス',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
                    if (!value.contains('@')) return '正しいメールアドレスを入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: passwordController,
                  label: 'パスワード',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'パスワードを入力してください';
                    if (value.length < 6) return 'パスワードは6文字以上で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: confirmPasswordController,
                  label: 'パスワード（確認）',
                  obscureText: true,
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'パスワードが一致しません';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : onRegister,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('アカウントを作成する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
