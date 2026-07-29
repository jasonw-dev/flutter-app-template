import 'dart:async';

import 'package:auth/src/presentation/blocs/login/login_cubit.dart';
import 'package:auth/src/presentation/blocs/login/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:localization/localization.dart';
import 'package:ui/ui.dart';

/// 登入頁。成功後不手動導航——session 狀態變更觸發 router redirect(app 層守衛唯一處)。
class LoginPage extends StatefulWidget {
  /// 建立登入頁。
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => context.read<GetIt>()<LoginCubit>(),
      child: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.authLoginFailed)),
            );
          }
        },
        child: AppPageScaffold(
          title: context.l10n.authLoginTitle,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  key: const Key('login_email_field'),
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: context.l10n.authEmailLabel,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login_password_field'),
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: context.l10n.authPasswordLabel,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                BlocBuilder<LoginCubit, LoginState>(
                  builder: (context, state) {
                    return AppPrimaryButton(
                      label: context.l10n.authLoginButton,
                      loading: state is LoginSubmitting,
                      onPressed: () => unawaited(
                        context.read<LoginCubit>().submit(
                          email: _emailController.text,
                          password: _passwordController.text,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
