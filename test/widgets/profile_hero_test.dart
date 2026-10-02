// 個人頁頂端：名稱放大、不再顯示等級標章。
//
// 取代的人工測試：在 360 寬手機切精簡模式，把名稱改成很長的字串，
// 看名稱是否兩行截斷、頭像有沒有被擠歪，以及名稱下方是否還有等級標章。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_typography.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/profile/widgets/profile_hero.dart';
import 'package:flutter_application_1/shared/widgets/user_avatar.dart';

const _narrowSurface = Size(360, 800);
const _longName = '太魯閣族語學習者暨部落文化推廣志工團隊召集人與傳統織布工藝傳承者';

UserModel _user({String displayName = 'Apyang'}) => UserModel(
  uid: 1,
  email: 'me@example.com',
  createdAt: DateTime(2026),
  displayName: displayName,
  isIndigenous: true,
  tribalName: 'Apyang Imiq',
  tribeName: '秀林部落',
  quizSuggestedLevel: '初級',
  listeningSuggestedLevel: null,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required UserModel user,
    required bool seniorMode,
    VoidCallback? onTribalNameTap,
  }) async {
    tester.view.physicalSize = _narrowSurface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHero(
              user: user,
              itemCatalogById: const {},
              seniorMode: seniorMode,
              onAvatarTap: () {},
              onTribalNameTap: onTribalNameTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  for (final senior in [false, true]) {
    final mode = senior ? '精簡模式' : '一般模式';

    testWidgets('$mode：名稱字級 display28（精簡 +2），沒有等級標章', (tester) async {
      await pump(tester, user: _user(), seniorMode: senior);

      final name = tester.widget<Text>(find.text('Apyang'));
      expect(
        name.style?.fontSize,
        AppTypography.size(AppTypography.display28, seniorMode: senior),
      );
      expect(find.textContaining('單字 ·'), findsNothing);
      expect(find.textContaining('聽力 ·'), findsNothing);
      expect(find.textContaining('未測驗'), findsNothing);
    });

    testWidgets('$mode：360 寬長名稱兩行截斷、不推擠頭像、不溢位', (tester) async {
      await pump(
        tester,
        user: _user(displayName: _longName),
        seniorMode: senior,
      );
      expect(tester.takeException(), isNull);

      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_longName),
      );
      expect(paragraph.didExceedMaxLines, isTrue, reason: '測試名稱要夠長才有驗到截斷');

      // 頭像固定 96 寬、貼左內距 20，名稱從頭像右邊 16 開始。
      final avatar = find.ancestor(
        of: find.byType(FramedUserAvatar),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 96 && w.height == 96,
        ),
      );
      expect(avatar, findsOneWidget);
      final avatarRect = tester.getRect(avatar);
      expect(avatarRect.left, 20);
      expect(avatarRect.width, 96);
      expect(tester.getTopLeft(find.text(_longName)).dx, 20 + 96 + 16);
    });

    testWidgets('$mode：族語名與部落仍在，點族語名照舊觸發編輯', (tester) async {
      var tapped = 0;
      await pump(
        tester,
        user: _user(),
        seniorMode: senior,
        onTribalNameTap: () => tapped++,
      );
      expect(find.text('秀林部落'), findsOneWidget);
      await tester.tap(find.text('Apyang Imiq'));
      expect(tapped, 1);
    });
  }
}
