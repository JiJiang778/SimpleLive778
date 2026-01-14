import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("账号管理"),
      ),
      body: ListView(
        children: [
          // 顶部提示区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // 哔哩哔哩提示
                const Text(
                  "哔哩哔哩账号需要登录才能看高清晰度的直播，其他平台暂无此限制。",
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // 抖音提示
                const Text(
                  "抖音直播需要添加Cookie（ttwid就足够）才能正常进入直播间。",
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // 获取Cookie教程链接
                GestureDetector(
                  onTap: controller.showCookieTutorial,
                  child: const Text(
                    "获取Cookie教程",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Obx(
            () => ListTile(
              leading: Image.asset(
                'assets/images/bilibili_2.png',
                width: 36,
                height: 36,
              ),
              title: const Text("哔哩哔哩"),
              subtitle: Text(BiliBiliAccountService.instance.name.value),
              trailing: BiliBiliAccountService.instance.logined.value
                  ? const Icon(Icons.logout)
                  : const Icon(Icons.chevron_right),
              onTap: controller.bilibiliTap,
            ),
          ),
          ListTile(
            leading: Image.asset(
              'assets/images/douyu.png',
              width: 36,
              height: 36,
            ),
            title: const Text("斗鱼直播"),
            subtitle: const Text("无需登录"),
            enabled: false,
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            leading: Image.asset(
              'assets/images/huya.png',
              width: 36,
              height: 36,
            ),
            title: const Text("虎牙直播"),
            subtitle: const Text("无需登录"),
            enabled: false,
            trailing: const Icon(Icons.chevron_right),
          ),
          Obx(
            () => ListTile(
              leading: Image.asset(
                'assets/images/douyin.png',
                width: 36,
                height: 36,
              ),
              title: const Text("抖音直播 - Cookie池"),
              subtitle: Text("已配置 ${DouyinAccountService.instance.cookiePool.length} 个ttwid"),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.douyinTap,
            ),
          ),
        ],
      ),
    );
  }
}
