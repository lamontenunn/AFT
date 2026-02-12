import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/screens/edit_default_profile_screen.dart';
import 'package:aft_firebase_app/features/auth/account_deletion_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Body-only settings screen. Wrapped by AftScaffold(showHeader: false).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _displayName(DefaultProfileSettings dp) {
    final first = dp.firstName?.trim();
    final last = dp.lastName?.trim();
    final mi = dp.middleInitial?.trim();

    final parts = <String>[];
    if (last != null && last.isNotEmpty) parts.add(last);
    if (first != null && first.isNotEmpty) parts.add(first);
    if (mi != null && mi.isNotEmpty) parts.add('$mi.');

    if (parts.isEmpty) return 'Not set';
    if (last != null && last.isNotEmpty && first != null && first.isNotEmpty) {
      // "Last, First M."
      final firstPart = mi != null && mi.isNotEmpty ? '$first $mi.' : first;
      return '$last, $firstPart';
    }
    // fallback
    return parts.join(' ');
  }

  static String _accountStatusLabel(User? user) {
    if (user == null) return 'Signed out';
    if (user.isAnonymous) return 'Guest';
    return 'Signed in';
  }

  static String _accountMethodLabel(User? user) {
    if (user == null) return 'Not signed in';
    if (user.isAnonymous) return 'Anonymous session';
    final providerId = _primaryProviderId(user);
    if (providerId == null) return 'Unknown';
    return switch (providerId) {
      'google.com' => 'Google',
      'apple.com' => 'Apple',
      'password' => 'Email',
      'phone' => 'Phone',
      'facebook.com' => 'Facebook',
      'github.com' => 'GitHub',
      'twitter.com' => 'X',
      'microsoft.com' => 'Microsoft',
      _ => 'Other',
    };
  }

  static String? _primaryProviderId(User user) {
    for (final info in user.providerData) {
      if (info.providerId != 'firebase') return info.providerId;
    }
    return user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final dp = settings.defaultProfile;
    final user = ref.watch(authUserProvider);
    final packageInfoFuture = PackageInfo.fromPlatform();

    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String heightLabel() {
      if (dp.height == null) return 'Not set';
      if (dp.measurementSystem == MeasurementSystem.metric) {
        return '${dp.height!.toStringAsFixed(0)} cm';
      }
      final totalIn = dp.height!.round();
      final ft = totalIn ~/ 12;
      final inch = totalIn % 12;
      return "$ft' $inch\"";
    }

    String weightLabel() {
      if (dp.weight == null) return 'Not set';
      if (dp.measurementSystem == MeasurementSystem.metric) {
        return '${dp.weight!.toStringAsFixed(1)} kg';
      }
      return '${dp.weight!.toStringAsFixed(1)} lb';
    }

    String bodyFatLabel() {
      if (dp.bodyFatPercent == null) return 'Not set';
      return '${dp.bodyFatPercent!.toStringAsFixed(0)}%';
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ctrl.refreshProfileFromCloud();
        final syncError = ctrl.takeProfileSyncError();
        if (syncError != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(syncError)),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Profile (read-only)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Profile',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Name',
                      value: _displayName(dp),
                    ),
                    const Divider(height: 12),
                    _SummaryRow(
                      label: 'Unit',
                      value: dp.unit?.trim().isNotEmpty == true
                          ? dp.unit!.trim()
                          : 'Not set',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'MOS',
                      value: dp.mos?.trim().isNotEmpty == true
                          ? dp.mos!.trim()
                          : 'Not set',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Pay Grade',
                      value: dp.payGrade?.trim().isNotEmpty == true
                          ? dp.payGrade!.trim()
                          : 'Not set',
                    ),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Birthdate',
                      value: dp.birthdate == null
                          ? 'Not set'
                          : '${ymd(dp.birthdate!)} (Age ${_ageFromDob(dp.birthdate!)})',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Gender',
                      value: dp.sex == null
                          ? 'Not set'
                          : (dp.sex == AftSex.male ? 'Male' : 'Female'),
                    ),
                    const Divider(height: 20),
                    _SummaryRow(label: 'Height', value: heightLabel()),
                    const SizedBox(height: 8),
                    _SummaryRow(label: 'Weight', value: weightLabel()),
                    const SizedBox(height: 8),
                    _SummaryRow(label: 'Body fat %', value: bodyFatLabel()),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditDefaultProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Account
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Account',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Status',
                      value: _accountStatusLabel(user),
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Method',
                      value: _accountMethodLabel(user),
                    ),
                    if (user != null && !user.isAnonymous) ...[
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Delete account',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        subtitle: const Text(
                          'Permanently deletes your account, saved score sets, and cloud-synced profile data.',
                        ),
                        onTap: () =>
                            _showDeleteAccountDialog(context, ref, user),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Popups & tips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Popups & tips',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Show Combat info popup'),
            value: settings.showCombatInfo,
            onChanged: (v) => ctrl.setShowCombatInfo(v),
          ),
          const Divider(height: 1),

          // Data management
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Data',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear all saved tests'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear all saved tests?'),
                  content: const Text(
                      'This will delete all saved tests for the current user.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Clear all')),
                  ],
                ),
              );
              if (ok == true) {
                final repo = ref.read(aftRepositoryProvider);
                final userId = ref.read(effectiveUserIdProvider);
                await repo.clearScoreSets(userId: userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All sets cleared')));
                }
              }
            },
          ),
          const Divider(height: 1),

          // Appearance (moved to bottom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Appearance',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Card(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Theme selection is coming soon.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: null, // Disabled: coming soon
            ),
          ),
          const Divider(height: 1),

          // About & support
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'About & support',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: packageInfoFuture,
            builder: (context, snap) {
              final info = snap.data;
              final version = info?.version ?? '—';
              final build = info?.buildNumber ?? '—';
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text('Version $version ($build)'),
                    subtitle: const Text('AFT Calculator'),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('About'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Made by Nunn Technologies'),
                              const SizedBox(height: 8),
                              Text(
                                'Not affiliated with or endorsed by the U.S. Army or Department of War.',
                                style:
                                    Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lightbulb_outline),
                    title: const Text('Request a feature'),
                    subtitle: const Text('Share an idea or improvement'),
                    onTap: () => _showFeedbackDialog(
                      context,
                      ref,
                      kind: _FeedbackKind.feature,
                      version: version,
                      build: build,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Submit a bug'),
                    subtitle: const Text('Report a problem or crash'),
                    onTap: () => _showFeedbackDialog(
                      context,
                      ref,
                      kind: _FeedbackKind.bug,
                      version: version,
                      build: build,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    subtitle: const Text('View inside the app'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

// Local helper: compute age in years from DOB at today.
  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = (DateTime.now().year - dob.year).toInt();
    final hasHadBirthdayThisYear = (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hasHadBirthdayThisYear) age--;
    return age.clamp(0, 150);
  }
}

enum _FeedbackKind { support, feature, bug }

extension _FeedbackKindMeta on _FeedbackKind {
  String get key {
    return switch (this) {
      _FeedbackKind.support => 'support',
      _FeedbackKind.feature => 'feature',
      _FeedbackKind.bug => 'bug',
    };
  }

  String get dialogTitle {
    return switch (this) {
      _FeedbackKind.support => 'Contact support',
      _FeedbackKind.feature => 'Request a feature',
      _FeedbackKind.bug => 'Submit a bug',
    };
  }

  String get prompt {
    return switch (this) {
      _FeedbackKind.support => 'Tell us how we can help.',
      _FeedbackKind.feature => 'Describe the feature you would like to see.',
      _FeedbackKind.bug => 'Describe the issue and how to reproduce it.',
    };
  }
}

Future<void> _showFeedbackDialog(
  BuildContext context,
  WidgetRef ref, {
  required _FeedbackKind kind,
  required String version,
  required String build,
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (_) => _FeedbackDialog(
      kind: kind,
      version: version,
      build: build,
    ),
  );

  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks! Your message was sent.')),
    );
  }
}

Future<void> _showDeleteAccountDialog(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final service = ref.read(accountDeletionServiceProvider);
  final method = service.requiredReauthMethodFor(user);
  final deleted = await showDialog<bool>(
    context: context,
    builder: (_) => _DeleteAccountDialog(
      method: method,
    ),
  );

  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deleted.'),
      ),
    );
  }
}

String _accountDeletionErrorMessage(Object error) {
  if (error is AccountDeletionException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'wrong-password':
        return 'Incorrect password.';
      case 'requires-recent-login':
        return 'Please sign in again and retry account deletion.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
    }
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied while deleting cloud data.';
      case 'unavailable':
        return 'Cloud service is unavailable. Try again later.';
    }
  }
  return 'Unable to delete account right now. Please try again.';
}

String _feedbackErrorMessage(Object error) {
  if (error is _FeedbackSubmitException) {
    return error.message;
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Unable to submit. Please sign in again and try.';
      case 'unavailable':
        return 'Network unavailable. Try again later.';
    }
  }
  return 'Unable to submit. Please try again.';
}

Future<void> _submitFeedback(
  WidgetRef ref, {
  required _FeedbackKind kind,
  required String message,
  required String version,
  required String build,
}) async {
  final user = ref.read(authUserProvider);
  if (user == null) {
    throw _FeedbackSubmitException('Sign in required to submit.');
  }

  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  await FirebaseFirestore.instance.collection('feedback').add({
    'type': kind.key,
    'message': message,
    'userId': user.uid,
    'isAnonymous': user.isAnonymous,
    'appVersion': version,
    'buildNumber': build,
    'platform': platform,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

class _FeedbackSubmitException implements Exception {
  _FeedbackSubmitException(this.message);

  final String message;
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog({
    required this.kind,
    required this.version,
    required this.build,
  });

  final _FeedbackKind kind;
  final String version;
  final String build;

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'Please enter a message.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await _submitFeedback(
        ref,
        kind: widget.kind,
        message: trimmed,
        version: widget.version,
        build: widget.build,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _feedbackErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final canSubmit = trimmed.isNotEmpty && !_isSubmitting;
    return AlertDialog(
      title: Text(widget.kind.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.kind.prompt),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 4,
              maxLength: 1000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                errorText: _errorText,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                } else {
                  setState(() {});
                }
              },
            ),
            Text(
              'Includes app version and device platform.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit ? _handleSubmit : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({
    required this.method,
  });

  final AccountDeletionReauthMethod method;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _showPassword = false;
  String? _errorText;

  bool get _needsPassword =>
      widget.method == AccountDeletionReauthMethod.password;
  bool get _unsupported =>
      widget.method == AccountDeletionReauthMethod.unsupported;

  bool get _isConfirmed =>
      _confirmController.text.trim().toUpperCase() == 'DELETE';

  bool get _canSubmit {
    if (_submitting || _unsupported || !_isConfirmed) return false;
    if (_needsPassword) {
      return _passwordController.text.trim().isNotEmpty;
    }
    return true;
  }

  String _reauthHint() {
    switch (widget.method) {
      case AccountDeletionReauthMethod.password:
        return 'For security, enter your current password before deletion.';
      case AccountDeletionReauthMethod.google:
        return 'For security, Google will ask you to sign in again.';
      case AccountDeletionReauthMethod.apple:
        return 'For security, Apple will ask you to sign in again.';
      case AccountDeletionReauthMethod.unsupported:
        return 'This account uses an unsupported sign-in method for automated reauthentication.';
    }
  }

  Future<void> _handleDelete() async {
    if (!_canSubmit) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref.read(accountDeletionServiceProvider).deleteCurrentUserAccount(
            password: _needsPassword ? _passwordController.text : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _accountDeletionErrorMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final headline = theme.textTheme.titleMedium?.copyWith(
      color: cs.error,
      fontWeight: FontWeight.w800,
    );
    final deleteButtonStyle = FilledButton.styleFrom(
      backgroundColor: cs.error,
      foregroundColor: cs.onError,
    );

    return AlertDialog(
      title: Text('Delete account?', style: headline),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This permanently deletes your account, saved score sets, and cloud-synced profile data. '
              'This action cannot be undone.',
            ),
            const SizedBox(height: 10),
            Text(
              _reauthHint(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
              onChanged: (_) => setState(() {
                _errorText = null;
              }),
            ),
            if (_needsPassword) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                enabled: !_submitting,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {
                  _errorText = null;
                }),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: deleteButtonStyle,
          onPressed: _canSubmit ? _handleDelete : null,
          child: _submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onError,
                  ),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  static const List<String> _headerLines = [
    'Privacy Policy - AFT (Army Fitness Test)',
    'Last updated: February 12, 2026',
  ];

  static const List<_PolicySection> _sections = [
    _PolicySection(
      '1. Overview',
      [
        'This Privacy Policy explains how the AFT app (the "App") collects, uses, stores, and shares information when you use it.',
        'This policy applies to the App and related services we provide. It does not cover third-party services or websites you may access from the App.',
      ],
    ),
    _PolicySection(
      '2. Information We Collect',
      [
        'A. Account and authentication information (only if you choose to sign in)',
        '- A unique account identifier (cloud UID).',
        '- Email address (if you use email/password sign-in).',
        '- Basic sign-in metadata provided by Apple or Google (if you choose those methods).',
        'B. Fitness test data you enter',
        '- AFT event inputs (repetitions/times).',
        '- Calculated scores and totals.',
        '- Saved score sets and timestamps.',
        '- Profile defaults you configure (such as sex, age band, test date, and standard selection).',
        '- Guest mode: data may be stored locally on your device only.',
        '- Signed-in use: data may be synced to the cloud so you can access it on another device.',
        'C. Support messages',
        '- If you submit a support request, bug report, or feature request in the App, we collect your message and related metadata (such as user ID, app version, build number, platform, and timestamp).',
        'D. Operational diagnostics',
        '- If profile cloud sync fails, we may store a client event containing the error code, short error message, sync operation, user ID, platform, and timestamp to help troubleshoot reliability issues.',
        '- We do not use Google Analytics.',
        '- We do not use Google Crashlytics.',
      ],
    ),
    _PolicySection(
      '3. How We Use Your Information',
      [
        '- Provide core functionality (scoring, saving, exporting, and syncing when you sign in).',
        '- Maintain authentication and account access (if you sign in).',
        '- Sync saved data across devices when you are signed in.',
        '- Diagnose profile sync failures and improve app reliability.',
        '- Review and address support requests, bug reports, and feature suggestions.',
      ],
    ),
    _PolicySection(
      '4. Where Your Data Is Stored',
      [
        'A. On-device storage',
        '- Some data may be stored locally on your device (for example, preferences and saved score sets in guest mode).',
        'B. Cloud storage',
        '- If you sign in, your saved AFT data and related settings may be stored in Google cloud services (such as a cloud database) associated with your account.',
        '- Support messages may be stored in the cloud for review and triage.',
      ],
    ),
    _PolicySection(
      '5. Sharing of Information',
      [
        'We do not sell your personal information.',
        '- Service providers: We use third-party services to operate the App (for example, Google services for authentication and cloud storage).',
        '- User-initiated sharing: If you export and share a document (such as a PDF export), it will be shared with recipients you select using your device\'s sharing tools.',
        '- Legal compliance: We may share information if required by law or to protect rights, safety, or security.',
      ],
    ),
    _PolicySection(
      '6. Data Retention',
      [
        'We retain account and saved data as long as needed to provide the App\'s functionality. You can request deletion as described below.',
        'Some information may remain temporarily in backups for operational or legal reasons.',
      ],
    ),
    _PolicySection(
      '7. Your Choices and Controls',
      [
        'A. Guest mode',
        '- You can use the App without fully signing in. In guest mode, your saved data may remain on your device and may be lost if you delete the App or clear device storage.',
        'B. Account deletion / data deletion',
        '- You can delete your account, saved score sets, and associated cloud-synced profile data in the app: Settings > Account > Delete account.',
        '- We may need to verify your identity before processing deletion.',
        'C. Sign-out controls',
        '- You can sign out at any time. When signed out, cloud sync and account-linked support submission are unavailable until you sign in again.',
      ],
    ),
    _PolicySection(
      '8. Security',
      [
        'We use reasonable administrative, technical, and physical safeguards designed to protect your information.',
        'Data transmitted between the App and backend services is generally protected using encryption in transit.',
        'Access to cloud-stored user data is restricted to authenticated users.',
      ],
    ),
    _PolicySection(
      '9. International Users',
      [
        'If you use the App from outside the United States, your information may be processed and stored in the United States or other countries where our service providers operate.',
      ],
    ),
    _PolicySection(
      '10. Children\'s Privacy',
      [
        'The App is intended for a general audience and is not directed to children under 13.',
        'We do not knowingly collect personal information from children in a targeted manner. If you believe a child has provided personal information, contact us and we will address it.',
      ],
    ),
    _PolicySection(
      '11. Changes to This Policy',
      [
        'We may update this Privacy Policy from time to time. We will revise the "Last updated" date at the top when changes are made.',
      ],
    ),
    _PolicySection(
      '12. Contact',
      [
        'For privacy requests or questions, email privacy@nunntechnologies.com.',
        'You can also use the in-app support options to send us a message.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy policy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              _headerLines.first,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final line in _headerLines.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            for (final section in _sections) ...[
              _PolicySectionView(section: section),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection(this.title, this.lines);

  final String title;
  final List<String> lines;
}

class _PolicySectionView extends StatelessWidget {
  const _PolicySectionView({required this.section});

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final line in section.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
