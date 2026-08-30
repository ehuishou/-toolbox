import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tool/tool_descriptor.dart';
import '../../core/tool/tool_module.dart';
import 'data/ledger_dao.dart';
import 'presentation/entry_editor_page.dart';
import 'presentation/ledger_page.dart';

class LedgerModule extends ToolModule {
  const LedgerModule();

  @override
  ToolDescriptor get descriptor => const ToolDescriptor(
        id: 'ledger',
        name: '记账',
        description: '收支记录与统计',
        icon: Icons.account_balance_wallet_outlined,
        color: Color(0xFF10B981),
        route: '/ledger',
        category: ToolCategory.life,
      );

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/ledger',
          builder: (_, __) => const LedgerPage(),
          routes: [
            GoRoute(
              path: 'entry',
              builder: (_, state) => EntryEditorPage(
                initial: state.extra as EntryDetail?,
              ),
            ),
          ],
        ),
      ];
}
