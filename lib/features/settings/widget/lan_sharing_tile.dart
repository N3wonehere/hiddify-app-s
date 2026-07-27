import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/model/lan_proxy_credential_verifier.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LanSharingPreferenceWidget extends HookConsumerWidget {
  const LanSharingPreferenceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final verifier = ref.watch(ConfigOptions.lanSharingCredentialsVerifier);
    final credentialsSet = LanProxyCredentialVerifier.isValid(verifier);
    final sharingEnabled = ref.watch(ConfigOptions.allowConnectionFromLan) && credentialsSet;

    Future<void> configureCredentials() async {
      final credentials = await showDialog<({String username, String password})>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _LanCredentialsDialog(t: t),
      );
      if (credentials == null || !context.mounted) return;

      final ipResult = await ref.read(hiddifyCoreServiceProvider).getLANIP().run();
      final ip = ipResult.fold((_) => null, (result) => result.ip);
      if (ip == null) {
        ref.read(inAppNotificationControllerProvider).showErrorToast(t.pages.settings.inbound.lanIPError);
        return;
      }

      final newVerifier = await LanProxyCredentialVerifier.create(
        username: credentials.username,
        password: credentials.password,
      );
      if (!context.mounted) return;
      await ref.read(ConfigOptions.lanSharingCredentialsVerifier.notifier).update(newVerifier);
      await ref.read(ConfigOptions.allowConnectionFromLan.notifier).update(true);

      final link = LanProxyCredentialVerifier.buildProxyUri(
        username: credentials.username,
        password: credentials.password,
        host: ip,
        port: ref.read(ConfigOptions.mixedPort),
      );
      await Clipboard.setData(ClipboardData(text: link));
      ref.read(inAppNotificationControllerProvider).showSuccessToast(t.common.msg.export.clipboard.success);
      await ref
          .read(dialogNotifierProvider.notifier)
          .showQrCode(link, message: t.pages.settings.inbound.lanSharingSaveNow);
    }

    Future<void> setSharing(bool enabled) async {
      if (!enabled) {
        await ref.read(ConfigOptions.allowConnectionFromLan.notifier).update(false);
      } else if (credentialsSet) {
        await ref.read(ConfigOptions.allowConnectionFromLan.notifier).update(true);
      } else {
        await configureCredentials();
      }
    }

    return ListTile(
      leading: const Icon(Icons.share_rounded),
      title: Text(t.pages.settings.inbound.lanSharing),
      subtitle: Text(
        credentialsSet
            ? t.pages.settings.inbound.lanSharingCredentialsLocked
            : t.pages.settings.inbound.lanSharingPasswordNotSet,
      ),
      trailing: Switch.adaptive(value: sharingEnabled, onChanged: setSharing),
      onTap: credentialsSet ? null : configureCredentials,
    );
  }
}

class _LanCredentialsDialog extends StatefulWidget {
  const _LanCredentialsDialog({required this.t});

  final Translations t;

  @override
  State<_LanCredentialsDialog> createState() => _LanCredentialsDialogState();
}

class _LanCredentialsDialogState extends State<_LanCredentialsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  var _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.length < 4) return widget.t.pages.settings.inbound.lanSharingUsernameTooShort;
    if (username.contains('\u0000') || utf8.encode(username).length > LanProxyCredentialVerifier.maxCredentialBytes) {
      return widget.t.pages.settings.inbound.lanSharingCredentialInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 16) return widget.t.pages.settings.inbound.lanSharingPasswordTooShort;
    if (password.contains('\u0000') || utf8.encode(password).length > LanProxyCredentialVerifier.maxCredentialBytes) {
      return widget.t.pages.settings.inbound.lanSharingCredentialInvalid;
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((username: _usernameController.text.trim(), password: _passwordController.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return AlertDialog(
      title: Text(t.pages.settings.inbound.lanSharingCredentialsSetTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.pages.settings.inbound.lanSharingOneTimeWarning),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: t.pages.settings.inbound.lanSharingUsername),
                validator: _validateUsername,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.pages.settings.inbound.lanSharingPassword,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmationController,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: t.pages.settings.inbound.lanSharingPasswordConfirm),
                validator: (value) =>
                    value == _passwordController.text ? null : t.pages.settings.inbound.lanSharingPasswordMismatch,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.cancel)),
        FilledButton(onPressed: _submit, child: Text(t.common.save)),
      ],
    );
  }
}
