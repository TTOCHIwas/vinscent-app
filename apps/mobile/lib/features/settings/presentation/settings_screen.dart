import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/assets/app_icons.dart';
import '../application/policy_document_links.dart';
import '../data/policy_document_launcher.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.policyDocumentLinks = PolicyDocumentLinks.configured,
    this.policyDocumentLauncher =
        const UrlLauncherPolicyDocumentLauncher(),
  });

  final PolicyDocumentLinks policyDocumentLinks;
  final PolicyDocumentLauncher policyDocumentLauncher;

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: '설정',
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/home');
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SettingsGroup(
            key: const Key('settings-group-notifications'),
            label: '알림',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-notifications'),
                icon: AppIcons.alarm,
                title: '알림 설정',
                onTap: () => context.push('/settings/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            key: const Key('settings-group-couple'),
            label: '커플',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-character'),
                icon: AppIcons.user,
                title: '캐릭터 꾸미기',
                onTap: () => context.push('/settings/character'),
              ),
              SettingsNavigationRow(
                key: const Key('settings-row-couple'),
                icon: AppIcons.heart,
                title: '커플 설정',
                onTap: () => context.push('/settings/couple'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            key: const Key('settings-group-safety'),
            label: '안전',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-blocked-users'),
                icon: AppIcons.user,
                title: '차단한 사용자',
                onTap: () => context.push('/settings/blocked-users'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            key: const Key('settings-group-account'),
            label: '계정',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-account'),
                icon: AppIcons.user,
                title: '계정 관리',
                onTap: () => context.push('/settings/account'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            key: const Key('settings-group-policy'),
            label: '서비스 정보',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-privacy'),
                iconData: LucideIcons.shieldCheck,
                title: '개인정보처리방침',
                onTap: () => _openPolicyDocument(
                  context,
                  policyDocumentLinks.privacy,
                ),
              ),
              SettingsNavigationRow(
                key: const Key('settings-row-terms'),
                iconData: LucideIcons.fileText,
                title: '서비스 이용약관',
                onTap: () => _openPolicyDocument(
                  context,
                  policyDocumentLinks.terms,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPolicyDocument(BuildContext context, Uri? uri) async {
    if (uri == null) {
      _showMessage(context, '정책 페이지를 준비하고 있어요');
      return;
    }

    try {
      final launched = await policyDocumentLauncher.launch(uri);
      if (!launched && context.mounted) {
        _showMessage(context, '정책 페이지를 열지 못했어요');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '정책 페이지를 열지 못했어요');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
