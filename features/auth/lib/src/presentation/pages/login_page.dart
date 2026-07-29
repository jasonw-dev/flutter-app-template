import 'dart:async';

import 'package:auth/src/presentation/blocs/login/login_cubit.dart';
import 'package:auth/src/presentation/blocs/login/login_state.dart';
import 'package:core/core.dart';
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
  final _formKey = GlobalKey<FormState>();
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
          body: Form(
            key: _formKey,
            // 使用者改過的欄位即時顯示錯誤,沒碰過的不要一進頁面就紅一片。
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    key: const Key('login_email_field'),
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: context.l10n.authEmailLabel,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => localizeValidationError(
                      context,
                      Validators.all(value, [
                        Validators.required,
                        Validators.email,
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('login_password_field'),
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: context.l10n.authPasswordLabel,
                    ),
                    obscureText: true,
                    // **登入表單刻意只檢查必填,不檢查密碼長度。** 長度規則
                    // 屬於註冊/改密碼流程;既有使用者可能持有較短的舊密碼,
                    // 在登入頁跟他說「至少 N 個字元」是誤導,而且會擋掉本來
                    // 該由後端回「帳密錯誤」的正常失敗路徑。
                    validator: (value) => localizeValidationError(
                      context,
                      Validators.required(value),
                    ),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<LoginCubit, LoginState>(
                    builder: (context, state) {
                      return AppPrimaryButton(
                        label: context.l10n.authLoginButton,
                        loading: state is LoginSubmitting,
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          unawaited(
                            context.read<LoginCubit>().submit(
                              email: _emailController.text,
                              password: _passwordController.text,
                            ),
                          );
                        },
                      );
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
}
