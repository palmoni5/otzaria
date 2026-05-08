// a widget that contains two tabs: history and bookmarks.
// The bookmarks tab is BookmarkView and the history is HistoryView.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/history/view/history_screen.dart';
import 'package:otzaria/bookmarks/view/bookmark_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabBar(
          splashBorderRadius: BorderRadius.circular(12),
          tabs: [
            Tab(
              text: 'favorites.bookmarks'.tr(),
              icon: const Icon(
                FluentIcons.bookmark_24_regular,
              ),
            ),
            Tab(
              text: 'favorites.history'.tr(),
              icon: const Icon(
                FluentIcons.history_24_regular,
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            BookmarkView(),
            HistoryView(),
          ],
        ),
      ),
    );
  }
}
