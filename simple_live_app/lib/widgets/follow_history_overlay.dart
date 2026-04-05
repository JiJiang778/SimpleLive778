import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class FollowHistoryOverlay extends StatefulWidget {
  final LiveRoomController controller;
  final VoidCallback onDismiss;
  final bool isBottomSheet;

  const FollowHistoryOverlay({
    required this.controller,
    required this.onDismiss,
    this.isBottomSheet = false,
    Key? key,
  }) : super(key: key);

  @override
  State<FollowHistoryOverlay> createState() => _FollowHistoryOverlayState();
}

class _FollowHistoryOverlayState extends State<FollowHistoryOverlay>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _initialIndex;
  List<History> _historyList = [];

  @override
  void initState() {
    super.initState();
    _initialIndex = AppSettingsController.instance.overlayTabOrder.value;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _initialIndex,
    );
    _tabController.addListener(_onTabChanged);
    _loadHistory();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
      AppSettingsController.instance.setOverlayTabOrder(_tabController.index);
    }
  }

  void _loadHistory() {
    setState(() {
      _historyList = DBService.instance.getHistores();
    });
  }

  Future<void> _clearAllHistory() async {
    var result = await Utils.showAlertDialog(
      "确定要清空所有观看记录吗？",
      title: "清空记录",
    );
    if (!result) return;
    await DBService.instance.historyBox.clear();
    _loadHistory();
    SmartDialog.showToast("已清空观看记录");
  }

  Future<void> _deleteHistoryItem(History item) async {
    HapticFeedback.mediumImpact();
    await DBService.instance.historyBox.delete(item.id);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Tab bar header
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withAlpha(30),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (!widget.isBottomSheet)
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.arrow_back, size: 20),
                ),
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  dividerHeight: 0,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Remix.heart_3_line, size: 15),
                          SizedBox(width: 5),
                          Text("关注"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Remix.history_line, size: 15),
                          SizedBox(width: 5),
                          Text("记录"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right side action button area
              if (_tabController.index == 1 && _historyList.isNotEmpty)
                IconButton(
                  onPressed: _clearAllHistory,
                  tooltip: "清空记录",
                  icon: const Icon(Remix.delete_bin_line, size: 19, color: Colors.red),
                )
              else if (widget.isBottomSheet)
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Remix.close_line, size: 20),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFollowList(),
              _buildHistoryList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowList() {
    return Obx(
      () => Stack(
        children: [
          RefreshIndicator(
            onRefresh: FollowService.instance.loadData,
            child: FollowService.instance.liveList.isEmpty
                ? _buildEmptyState("暂无正在直播的关注", Remix.heart_3_line)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    itemCount: FollowService.instance.liveList.length,
                    itemBuilder: (_, i) {
                      var item = FollowService.instance.liveList[i];
                      return Obx(
                        () => FollowUserItem(
                          item: item,
                          playing:
                              widget.controller.rxSite.value.id == item.siteId &&
                                  widget.controller.rxRoomId.value ==
                                      item.roomId,
                          onTap: () {
                            widget.onDismiss();
                            widget.controller.resetRoom(
                              Sites.allSites[item.siteId]!,
                              item.roomId,
                            );
                          },
                          onLongPress:
                              (Platform.isAndroid || Platform.isIOS)
                                  ? () => _showFollowOptions(item)
                                  : null,
                          onSecondaryTap: (Platform.isWindows ||
                                  Platform.isMacOS ||
                                  Platform.isLinux)
                              ? () => _showFollowOptions(item)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            Positioned(
              right: 12,
              bottom: 12,
              child: Obx(
                () => _buildRefreshButton(
                  refreshing: FollowService.instance.updating.value,
                  onPressed: FollowService.instance.loadData,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_historyList.isEmpty) {
      return _buildEmptyState("暂无观看记录", Remix.history_line);
    }
    return RefreshIndicator(
      onRefresh: () async {
        _loadHistory();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        itemCount: _historyList.length,
        itemBuilder: (_, i) {
          var item = _historyList[i];
          var site = Sites.allSites[item.siteId];
          if (site == null) return const SizedBox.shrink();
          bool isPlaying =
              widget.controller.rxSite.value.id == item.siteId &&
                  widget.controller.rxRoomId.value == item.roomId;
          return _buildHistoryItem(item, site, isPlaying);
        },
      ),
    );
  }

  Widget _buildHistoryItem(History item, dynamic site, bool isPlaying) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        widget.onDismiss();
        widget.controller.resetRoom(
          Sites.allSites[item.siteId]!,
          item.roomId,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isPlaying
              ? theme.colorScheme.primaryContainer.withAlpha(60)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(
                  color: theme.colorScheme.primary.withAlpha(80),
                  width: 1.5,
                )
              : Border.all(
                  color: Colors.grey.withAlpha(30),
                  width: 0.5,
                ),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withAlpha(Get.isDarkMode ? 20 : 12),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10, right: 4),
          child: Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withAlpha(40),
                    width: 1.5,
                  ),
                ),
                child: NetImage(
                  item.face,
                  width: 44,
                  height: 44,
                  borderRadius: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isPlaying ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Image.asset(
                          site.logo,
                          width: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          site.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Remix.time_line,
                          size: 11,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatTime(item.updateTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right side
              if (isPlaying)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "观看中",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Delete button
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteHistoryItem(item),
                    tooltip: "删除记录",
                    icon: Icon(
                      Remix.close_circle_line,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowOptions(item) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  item.userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  item.pinned ? Remix.unpin_line : Remix.pushpin_line,
                  color: item.pinned ? Colors.orange : null,
                ),
                title: Text(item.pinned ? "取消置顶" : "置顶"),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  Get.back();
                  if (item.pinned) {
                    item.pinned = false;
                    item.pinnedTime = null;
                  } else {
                    item.pinned = true;
                    item.pinnedTime = DateTime.now();
                  }
                  await DBService.instance.addFollow(item);
                  FollowService.instance.filterData();
                },
              ),
              ListTile(
                leading: const Icon(Remix.dislike_line, color: Colors.red),
                title: const Text(
                  "取消关注",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  Get.back();
                  await DBService.instance.followBox.delete(item.id);
                  FollowService.instance.filterData();
                  if (widget.controller.rxSite.value.id == item.siteId &&
                      widget.controller.rxRoomId.value == item.roomId) {
                    widget.controller.followed.value = false;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.grey.withAlpha(80),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton({
    required bool refreshing,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      onPressed: refreshing ? null : onPressed,
      child: refreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Remix.refresh_line, size: 20),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return "刚刚";
    if (diff.inMinutes < 60) return "${diff.inMinutes}分钟前";
    if (diff.inHours < 24) return "${diff.inHours}小时前";
    if (diff.inDays < 7) return "${diff.inDays}天前";
    return "${time.month}/${time.day}";
  }
}
