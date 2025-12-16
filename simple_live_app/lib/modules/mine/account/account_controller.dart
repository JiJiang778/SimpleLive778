import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';

class AccountController extends GetxController {
  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyinTap() {
    showDouyinCookiePoolDialog();
  }
  
  /// 显示获取Cookie教程弹窗
  void showCookieTutorial() {
    Get.dialog(
      AlertDialog(
        title: const Text("获取抖音ttwid教程"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "方法一：电脑浏览器获取",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                "1. 电脑打开浏览器，访问 live.douyin.com\n"
                "2. 按 F12 打开开发者工具\n"
                "3. 切换到「应用程序」或「Application」标签\n"
                "4. 在左侧找到「Cookie」→「live.douyin.com」\n"
                "5. 找到名为「ttwid」的项，复制其值",
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                "方法二：手机抓包获取",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                "使用抓包工具（如HttpCanary、Charles等）\n"
                "抓取抖音直播请求中的Cookie，\n"
                "找到ttwid字段即可。",
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                "提示",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange),
              ),
              SizedBox(height: 8),
              Text(
                "• ttwid有效期较长，一般不需要频繁更换\n"
                "• 可以添加多个ttwid，失败时自动切换\n"
                "• 支持粘贴完整Cookie，会自动提取ttwid",
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("知道了"),
          ),
        ],
      ),
    );
  }
  
  /// 显示抖音Cookie池管理弹窗
  void showDouyinCookiePoolDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Text("抖音Cookie池"),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 20),
              onPressed: showCookieTutorial,
              tooltip: "获取Cookie教程",
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "进入直播间失败时会自动轮换ttwid尝试",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Obx(() => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: DouyinAccountService.instance.cookiePool.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Cookie池为空，请添加ttwid"),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: DouyinAccountService.instance.cookiePool.length,
                        itemBuilder: (context, index) {
                          var ttwid = DouyinAccountService.instance.cookiePool[index];
                          var shortId = _getShortTtwid(ttwid);
                          return ListTile(
                            dense: true,
                            title: Text(
                              "ttwid #${index + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              shortId,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () => _copyTtwid(ttwid),
                                  tooltip: "复制",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () => _deleteTtwid(index),
                                  tooltip: "删除",
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              DouyinAccountService.instance.resetCookiePool();
              SmartDialog.showToast("已恢复默认ttwid");
            },
            child: const Text("恢复默认"),
          ),
          TextButton(
            onPressed: () => _showAddTtwidDialog(),
            child: const Text("添加ttwid"),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }
  
  /// 获取ttwid的短显示形式
  String _getShortTtwid(String ttwid) {
    var value = ttwid;
    if (value.startsWith('ttwid=')) {
      value = value.substring(6);
    }
    if (value.length > 30) {
      return "${value.substring(0, 15)}...${value.substring(value.length - 10)}";
    }
    return value;
  }
  
  /// 复制ttwid
  void _copyTtwid(String ttwid) {
    var value = ttwid;
    if (value.startsWith('ttwid=')) {
      value = value.substring(6);
    }
    Clipboard.setData(ClipboardData(text: value));
    SmartDialog.showToast("已复制到剪贴板");
  }
  
  /// 删除ttwid
  void _deleteTtwid(int index) async {
    if (DouyinAccountService.instance.cookiePool.length <= 1) {
      SmartDialog.showToast("至少保留一个ttwid");
      return;
    }
    var result = await Utils.showAlertDialog("确定要删除这个ttwid吗？", title: "删除确认");
    if (result) {
      DouyinAccountService.instance.removeFromCookiePool(index);
      SmartDialog.showToast("已删除");
    }
  }
  
  /// 显示添加ttwid弹窗
  void _showAddTtwidDialog() {
    var controller = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("添加ttwid"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "支持以下格式：\n"
              "• 完整Cookie（会自动提取ttwid）\n"
              "• ttwid=xxx 格式\n"
              "• 纯ttwid值",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "粘贴ttwid或完整Cookie",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              if (input.isEmpty) {
                SmartDialog.showToast("请输入内容");
                return;
              }
              var success = DouyinAccountService.instance.addToCookiePool(input);
              if (success) {
                Get.back();
                SmartDialog.showToast("添加成功");
              } else {
                var ttwid = DouyinAccountService.extractTtwid(input);
                if (ttwid == null) {
                  SmartDialog.showToast("无法识别ttwid，请检查格式");
                } else {
                  SmartDialog.showToast("该ttwid已存在");
                }
              }
            },
            child: const Text("添加"),
          ),
        ],
      ),
    );
  }
}
