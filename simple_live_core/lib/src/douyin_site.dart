import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/http_client.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() =>
      DouyinDanmaku()..setSignatureFunction(getSignature);

  Future<String> Function(String, String) getAbogusUrl =
      (url, userAgent) async {
    throw Exception(
        "You must call setAbogusUrlFunction to set the function first");
  };

  void setAbogusUrlFunction(Future<String> Function(String, String) func) {
    getAbogusUrl = func;
  }

  Future<String> Function(String, String) getSignature =
      (roomId, uniqueId) async {
    throw Exception(
        "You must call setSignatureFunction to set the function first");
  };

  void setSignatureFunction(Future<String> Function(String, String) func) {
    getSignature = func;
  }

  /// 使用 QQBrowser User-Agent（参考原版 DouyinLiveRecorder）
  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.97 Safari/537.36 Core/1.116.567.400 QQBrowser/19.7.6764.400";

  static const String kDefaultReferer = "https://live.douyin.com";

  static const String kDefaultAuthority = "live.douyin.com";

  /// 默认 Cookie - 只需要 ttwid 字段即可获取所有画质（包括蓝光）
  static const String kDefaultCookie = "ttwid=1%7CB1qls3GdnZhUov9o2NxOMxxYS2ff6OSvEWbv0ytbES4%7C1680522049%7C280d802d6d478e3e78d0c807f7c487e7ffec0ae4e5fdd6a0fe74c3c6af149511";
  
  /// 抖音重要Cookie字段说明：
  /// 1. ttwid - 设备指纹，有效期最长（几个月），最重要
  /// 2. s_v_web_id - 访客ID，有效期较长（约30天）
  /// 3. passport_csrf_token - CSRF令牌，有效期中等（约7天）
  /// 4. odin_tt - 设备追踪ID，有效期较长（约30天）
  /// 5. sid_guard - 会话保护，有效期中等（约7天）
  /// 6. uid_tt - 用户追踪ID，有效期较长（约30天）
  /// 7. sid_tt - 会话ID，有效期短（约1天）
  /// 8. sessionid - 登录会话，有效期短（约1天）
  /// 9. __ac_nonce - 临时验证，有效期很短（几分钟）
  /// 10. msToken - 微软令牌，有效期中等（约1天）
  
  /// 默认Cookie池（不可修改的原始列表）
  static const List<String> kDefaultCookiePool = [
    "ttwid=1%7CB1qls3GdnZhUov9o2NxOMxxYS2ff6OSvEWbv0ytbES4%7C1680522049%7C280d802d6d478e3e78d0c807f7c487e7ffec0ae4e5fdd6a0fe74c3c6af149511",
    "ttwid=1%7CCQUSKtvKnhhPr2-LZZPi8gotooa5g8mKBS2MTsVWqM0%7C1765287876%7C04a6d728a198c6a0e49695dbc66c8cc96959eff6d5119cf0f5ef2cf33dfe0f6b",
  ];
  
  /// Cookie池 - 可动态修改（由DouyinAccountService同步）
  static List<String> kCookiePool = List.from(kDefaultCookiePool);
  
  /// 当前使用的cookie索引
  static int _currentCookieIndex = 0;
  
  /// 记录每个cookie的最后使用时间和失败次数
  static final Map<String, DateTime> _cookieLastUsed = {};
  static final Map<String, int> _cookieFailCount = {};
  
  /// 获取下一个可用的cookie
  static String getNextCookie() {
    // 找到失败次数最少且超过冷却时间的cookie
    String? bestCookie;
    int minFailCount = 999;
    
    for (int i = 0; i < kCookiePool.length; i++) {
      String cookie = kCookiePool[i];
      int failCount = _cookieFailCount[cookie] ?? 0;
      DateTime? lastUsed = _cookieLastUsed[cookie];
      
      // 如果这个cookie从未使用过，直接使用
      if (lastUsed == null) {
        _currentCookieIndex = i;
        return cookie;
      }
      
      // 检查冷却时间（根据失败次数调整冷却时间）
      int cooldownSeconds = failCount * 30 + 10; // 基础10秒，每次失败增加30秒
      if (DateTime.now().difference(lastUsed).inSeconds > cooldownSeconds) {
        if (failCount < minFailCount) {
          minFailCount = failCount;
          bestCookie = cookie;
          _currentCookieIndex = i;
        }
      }
    }
    
    // 如果找到了合适的cookie，返回它
    if (bestCookie != null) {
      return bestCookie;
    }
    
    // 如果所有cookie都在冷却中，使用失败次数最少的
    _currentCookieIndex = (_currentCookieIndex + 1) % kCookiePool.length;
    return kCookiePool[_currentCookieIndex];
  }
  
  /// 标记当前cookie失败
  static void markCookieAsFailed() {
    String currentCookie = kCookiePool[_currentCookieIndex];
    _cookieFailCount[currentCookie] = (_cookieFailCount[currentCookie] ?? 0) + 1;
    _logDebug("Cookie #${_currentCookieIndex + 1} 失败次数: ${_cookieFailCount[currentCookie]}");
  }
  
  /// 重置cookie失败计数（成功时调用）
  static void resetCookieFailCount() {
    String currentCookie = kCookiePool[_currentCookieIndex];
    _cookieFailCount[currentCookie] = 0;
  }
  
  /// 获取当前cookie索引
  static int getCurrentCookieIndex() {
    return _currentCookieIndex;
  }
  
  /// 获取指定cookie的失败次数
  static int getCookieFailCount(String cookie) {
    return _cookieFailCount[cookie] ?? 0;
  }
  
  /// 用户设置的 cookie
  String cookie = "";
  
  static void _logDebug(String msg) {
    // 只使用 CoreLog，不使用 print  
    CoreLog.d("[Douyin] $msg");
  }

  Map<String, dynamic> headers = {
    "User-Agent": kDefaultUserAgent,
    "Referer": kDefaultReferer,
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      // 如果用户已设置 cookie，直接使用用户的 cookie
      if (cookie.isNotEmpty) {
        headers["cookie"] = cookie;
        return headers;
      }

      // 使用cookie池系统
      String selectedCookie = getNextCookie();
      _cookieLastUsed[selectedCookie] = DateTime.now();
      
      headers["cookie"] = selectedCookie;
      _logDebug("使用Cookie #${_currentCookieIndex + 1}/${kCookiePool.length}");
      
      return headers;
    } catch (e) {
      CoreLog.error(e);
      // 如果出错，使用第一个cookie作为后备
      if (!(headers["cookie"]?.toString().isNotEmpty ?? false)) {
        headers["cookie"] = kCookiePool.first;
      }
      return headers;
    }
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {},
      header: await getRequestHeaders(),
    );

    var renderData =
        RegExp(r'\{\\"pathname\\":\\"\/\\",\\"categoryData.*?\]\\n')
                .firstMatch(result)
                ?.group(0) ??
            "";
    
    // 检查是否成功获取到数据
    if (renderData.isEmpty) {
      throw Exception("无法获取抖音分类数据，可能是页面结构已变化");
    }
    
    var renderDataStr = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    
    Map<String, dynamic> renderDataJson;
    try {
      renderDataJson = json.decode(renderDataStr);
    } catch (e) {
      if (e is FormatException) {
        throw Exception("抖音分类数据解析失败：${e.message}");
      }
      rethrow;
    }

    for (var item in renderDataJson["categoryData"]) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveSubCategory(
          id: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          name: asT<String?>(subItem["partition"]["title"]) ?? "",
          parentId: id,
          pic: "",
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
          0,
          LiveSubCategory(
            id: category.id,
            name: category.name,
            parentId: category.id,
            pic: "",
          ));
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category,
      {int page = 1}) async {
    var ids = category.id.split(',');
    var partitionId = ids[0];
    var partitionType = ids[1];

    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "enter_from": "link_share",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "142.0.0.0",
      "browser_online": "true",
      "count": '15',
      "offset": ((page - 1) * 15).toString(),
      "partition": partitionId,
      "partition_type": partitionType,
      "req_from": '2'
    });
    var requestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: await getRequestHeaders(),
    );

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online: int.tryParse(
                item["room"]["room_view_stats"]["display_value"].toString()) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "enter_from": "link_share",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "142.0.0.0",
      "browser_online": "true",
      "count": '15',
      "offset": ((page - 1) * 15).toString(),
      "partition": '720',
      "partition_type": '1',
      "req_from": '2'
    });
    var requestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: await getRequestHeaders(),
    );

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online: int.tryParse(
                item["room"]["room_view_stats"]["display_value"].toString()) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    // 有两种roomId，一种是webRid，一种是roomId
    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // roomId一般长度为19位，例如：7376429659866598196
    // webRid是固定的，用户每次开播都是同一个webRid
    // webRid一般长度为11-12位，例如：416144012050
    // 这里简单进行判断，如果roomId长度小于15，则认为是webRid
    if (roomId.length <= 16) {
      var webRid = roomId;
      return await getRoomDetailByWebRid(webRid);
    }

    return await getRoomDetailByRoomId(roomId);
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByRoomId(String roomId) async {
    // 读取房间信息
    var roomData = await _getRoomDataByRoomId(roomId);

    // 检查数据有效性
    if (roomData["data"] == null || 
        roomData["data"]["room"] == null) {
      throw Exception("Invalid room data structure from roomId API");
    }

    // 通过房间信息获取WebRid
    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var room = roomData["data"]["room"];
    var owner = room["owner"];

    var status = asT<int?>(room["status"]) ?? 0;

    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // 所以如果roomId对应的直播间状态不是直播中，就通过webRid获取直播间信息
    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      return result;
    }

    var roomStatus = status == 2;
    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    // 获取在线人数，优先使用 display_value（真实人数，和首页一致）
    int onlineCount = 0;
    if (roomStatus) {
      // 优先从 room_view_stats 获取真实人数（和首页展示一致）
      var roomViewStats = room["room_view_stats"];
      if (roomViewStats != null) {
        onlineCount = asT<int?>(roomViewStats["display_value"]) ?? 0;
      }
      // 如果 display_value 获取不到，才尝试从 stats.total_user 获取
      if (onlineCount == 0 && room["stats"] != null) {
        onlineCount = asT<int?>(room["stats"]["total_user"]) ?? 0;
      }
    }

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: owner["nickname"].toString(),
      userAvatar: owner["avatar_thumb"]["url_list"][0].toString(),
      online: onlineCount,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner["signature"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: room["stream_url"],
    );
  }

  /// 通过WebRid获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      // 成功时重置失败计数
      resetCookieFailCount();
      return result;
    } catch (e) {
      CoreLog.error(e);
      // 标记当前cookie失败，触发切换
      String errorStr = e.toString();
      if (errorStr.contains("频繁") || errorStr.contains("444") || errorStr.contains("403") || errorStr.contains("格式")) {
        markCookieAsFailed();
      }
    }
    return await _getRoomDetailByWebRidHtml(webRid);
  }

  /// 通过WebRid访问直播间API，从API中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidApi(String webRid) async {
    // 读取房间信息
    var data = await _getRoomDataByApi(webRid);
    
    // 检查数据有效性
    if (data["data"] == null || data["data"].isEmpty) {
      throw Exception("Invalid room data structure from API");
    }
    
    var roomData = data["data"][0];
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var owner = roomData["owner"];

    var roomStatus = (asT<int?>(roomData["status"]) ?? 0) == 2;

    // 获取在线人数，优先使用 display_value（真实人数，和首页一致）
    int onlineCount = 0;
    if (roomStatus) {
      // 优先从 room_view_stats 获取真实人数（和首页展示一致）
      var roomViewStats = roomData["room_view_stats"];
      if (roomViewStats != null) {
        onlineCount = asT<int?>(roomViewStats["display_value"]) ?? 0;
      }
      // 如果 display_value 获取不到，才尝试从 stats.total_user 获取
      if (onlineCount == 0 && roomData["stats"] != null) {
        onlineCount = asT<int?>(roomData["stats"]["total_user"]) ?? 0;
      }
    }

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();
    return LiveRoomDetail(
      roomId: webRid,
      title: roomData["title"].toString(),
      cover: roomStatus ? roomData["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : userData["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : userData["avatar_thumb"]["url_list"][0].toString(),
      online: onlineCount,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? roomData["stream_url"] : {},
    );
  }

  /// 通过WebRid访问直播间网页，从网页HTML中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidHtml(String webRid) async {
    var roomData = await _getRoomDataByHtml(webRid);
    var roomId = roomData["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    
    // 安全获取user_unique_id，防止空指针
    var userUniqueId = "";
    try {
      if (roomData["userStore"] != null && 
          roomData["userStore"]["odin"] != null &&
          roomData["userStore"]["odin"]["user_unique_id"] != null) {
        userUniqueId = roomData["userStore"]["odin"]["user_unique_id"].toString();
      } else {
        userUniqueId = generateRandomNumber(12).toString();
      }
    } catch (e) {
      userUniqueId = generateRandomNumber(12).toString();
    }

    var room = roomData["roomStore"]["roomInfo"]["room"];
    var owner = room["owner"];
    var anchor = roomData["roomStore"]["roomInfo"]["anchor"];
    var roomStatus = (asT<int?>(room["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : anchor["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : anchor["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? room["stream_url"] : {},
    );
  }

  /// 读取用户的唯一ID
  /// - [webRid] 直播间RID
  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      // 安全检查嵌套对象
      if (webInfo["userStore"] != null && 
          webInfo["userStore"]["odin"] != null &&
          webInfo["userStore"]["odin"]["user_unique_id"] != null) {
        return webInfo["userStore"]["odin"]["user_unique_id"].toString();
      }
      return generateRandomNumber(12).toString();
    } catch (e) {
      return generateRandomNumber(12).toString();
    }
  }

  /// 进入直播间前需要先获取cookie
  /// - [webRid] 直播间RID
  Future<String> _getWebCookie(String webRid) async {
    var headResp = await HttpClient.instance.head(
      "https://live.douyin.com/$webRid",
      header: headers,
    );
    var dyCookie = "";
    headResp.headers["set-cookie"]?.forEach((element) {
      var cookie = element.split(";")[0];
      if (cookie.contains("ttwid")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("__ac_nonce")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("msToken")) {
        dyCookie += "$cookie;";
      }
    });
    return dyCookie;
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByHtml(String webRid) async {
    var dyCookie = await _getWebCookie(webRid);
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: {
        "User-Agent": kDefaultUserAgent,
        "Referer": "https://live.douyin.com/",
        "Cookie": dyCookie,
      },
    );

    var renderData = RegExp(r'\{\\"state\\":\{\\"appStore.*?\]\\n')
            .firstMatch(result)
            ?.group(0) ??
        "";
    var str = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    
    // 检查是否成功获取到数据
    if (str.isEmpty || str.length < 2) {
      throw Exception("抖音直播间页面加载失败，可能是访问频率过高或直播间不存在。请稍后再试。");
    }
    
    try {
      var renderDataJson = json.decode(str);
      return renderDataJson["state"];
    } catch (e) {
      // 如果是JSON解析错误，提供更友好的错误信息
      if (e is FormatException) {
        throw Exception("抖音直播间数据解析失败，可能页面结构已变化。错误详情：${e.message}");
      }
      rethrow;
    }
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByApi(String webRid) async {
    String serverUrl = "https://live.douyin.com/webcast/room/web/enter/";
        // 提前获取 headers
    var requestHeader = await getRequestHeaders();

    // 使用动态 Referer（包含房间号，参考 DouyinLiveRecorder）
    requestHeader["Referer"] = "https://live.douyin.com/$webRid";
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "browser_language": "zh-CN",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
      "web_rid": webRid,
      "msToken": "",
    });
    var requestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: requestHeader,
    );

    if (result is! Map) {
      throw Exception("抖音接口返回格式异常");
    }

    return result["data"];
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  Future<Map> _getRoomDataByRoomId(String roomId) async {
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: await getRequestHeaders(),
    );
    
    if (result == null) {
      throw Exception("Failed to get room data by roomId: result is null");
    }
    
    return result;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoomDetail detail}) async {
    List<LivePlayQuality> qualities = [];
    try {
      var liveCoreData = detail.data["live_core_sdk_data"];

      if (liveCoreData == null) {
        return qualities;
      }
      var pullData = liveCoreData["pull_data"];

      if (pullData == null) {
        return qualities;
      }

      var options = pullData["options"];

      var qulityList = options?["qualities"];

      var streamData = pullData["stream_data"]?.toString() ?? "";

      if (!streamData.startsWith('{')) {
        var flvList =
            (detail.data["flv_pull_url"] as Map).values.cast<String>().toList();
        var hlsList = (detail.data["hls_pull_url_map"] as Map)
            .values
            .cast<String>()
            .toList();
        for (var quality in qulityList) {
          int level = quality["level"];
          List<String> urls = [];
          var flvIndex = flvList.length - level;
          if (flvIndex >= 0 && flvIndex < flvList.length) {
            urls.add(flvList[flvIndex]);
          }
          var hlsIndex = hlsList.length - level;
          if (hlsIndex >= 0 && hlsIndex < hlsList.length) {
            urls.add(hlsList[hlsIndex]);
          }
          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: level,
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      } else {
        Map<String, dynamic> qualityData;
        try {
          var decodedData = json.decode(streamData);
          qualityData = Map<String, dynamic>.from(decodedData["data"] as Map);
        } catch (e) {
          if (e is FormatException) {
            CoreLog.error("解析streamData失败: ${e.message}");
            return qualities;
          }
          rethrow;
        }

        for (var quality in qulityList) {
          List<String> urls = [];

          var flvUrl =
              qualityData[quality["sdk_key"]]?["main"]?["flv"]?.toString();

          if (flvUrl != null && flvUrl.isNotEmpty) {
            urls.add(flvUrl);
          }
          var hlsUrl =
              qualityData[quality["sdk_key"]]?["main"]?["hls"]?.toString();

          if (hlsUrl != null && hlsUrl.isNotEmpty) {
            urls.add(hlsUrl);
          }

          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: quality["level"],
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      }
    } catch (e, stackTrace) {
      CoreLog.error(e);
      CoreLog.error(stackTrace);
    }
    // var qualityData = json.decode(
    //     detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    _logDebug("获取到的画质列表: ${qualities.map((q) => q.quality).toList()}");
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    // 返回列表的副本，防止外部 clear() 影响原始数据
    return LivePlayUrl(urls: List<String>.from(quality.data));
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword,
      {int page = 1}) async {
    
    // 使用抖音通用搜索接口
    String serverUrl = "https://www.douyin.com/aweme/v1/web/general/search/single/";
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "device_platform": "webapp",
      "aid": "6383",
      "channel": "channel_pc_web",
      "search_channel": "aweme_general",
      "keyword": keyword,
      "search_source": "tab_search",
      "query_correct_type": "1",
      "is_filter_search": "0",
      "from_group_id": "",
      "offset": ((page - 1) * 15).toString(),
      "count": "15",
      "need_filter_settings": "0",
      "list_type": "single",
      "update_version_code": "170400",
      "pc_client_type": "1",
      "version_code": "170400",
      "version_name": "17.4.0",
      "cookie_enabled": "true",
      "screen_width": "1536",
      "screen_height": "864",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "143.0.0.0",
      "browser_online": "true",
      "engine_name": "Blink",
      "engine_version": "143.0.0.0",
      "os_name": "Windows",
      "os_version": "10",
      "device_memory": "8",
      "platform": "PC",
      "downlink": "10",
      "effective_type": "4g",
      "round_trip_time": "50",
      // 添加tab_name参数指定搜索直播
      "tab_name": "live",
    });
    
    
    String requlestUrl;
    try {
      requlestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);
      if (requlestUrl.isEmpty) {
        throw Exception("签名后URL为空");
      }
    } catch (e, stackTrace) {
      var errorInfo = StringBuffer();
      errorInfo.writeln("【抖音签名失败】");
      errorInfo.writeln("错误类型: ${e.runtimeType}");
      errorInfo.writeln("错误详情: $e");
      errorInfo.writeln("");
      errorInfo.writeln("【可能原因】");
      errorInfo.writeln("1. 签名算法需要更新");
      errorInfo.writeln("2. 网络请求被拦截");
      errorInfo.writeln("");
      errorInfo.writeln("【解决方案】");
      errorInfo.writeln("1. 等待应用更新");
      errorInfo.writeln("2. 在「我的-账号管理」设置自己的Cookie");
      throw Exception(errorInfo.toString());
    }
    // 使用 getRequestHeaders 获取 Cookie（包含默认 ttwid 或用户设置的 Cookie）
    var requestHeaders = await getRequestHeaders();
    var dyCookie = requestHeaders["cookie"] ?? "";
    
    dynamic result;
    try {
      result = await HttpClient.instance.getJson(
        requlestUrl,
        queryParameters: {},
        header: {
          "Authority": 'www.douyin.com',
          'accept': 'application/json, text/plain, */*',
          'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'cookie': dyCookie,
          'priority': 'u=1, i',
          'referer':
              'https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?type=live',
          'sec-ch-ua':
              '"Microsoft Edge";v="143", "Chromium";v="143", "Not.A/Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'same-origin',
          'user-agent': kDefaultUserAgent,
        },
      );
    } catch (e, stackTrace) {
      // 构建详细的错误信息
      var errorInfo = StringBuffer();
      errorInfo.writeln("【抖音搜索失败】");
      errorInfo.writeln("错误类型: ${e.runtimeType}");
      errorInfo.writeln("错误详情: $e");
      errorInfo.writeln("");
      errorInfo.writeln("【调试信息】");
      errorInfo.writeln("请求URL长度: ${requlestUrl.length}");
      errorInfo.writeln("Cookie长度: ${dyCookie.length}");
      if (dyCookie.isEmpty) {
        errorInfo.writeln("Cookie: 空（使用默认配置）");
      } else {
        errorInfo.writeln("Cookie前50字符: ${dyCookie.substring(0, dyCookie.length > 50 ? 50 : dyCookie.length)}...");
      }
      errorInfo.writeln("");
      
      // 提供解决建议
      var errorStr = e.toString();
      if (errorStr.contains('444')) {
        errorInfo.writeln("【原因】请求频率过高（错误444）");
        errorInfo.writeln("【解决方案】");
        errorInfo.writeln("1. 等待几秒后再试");
        errorInfo.writeln("2. 在「我的-账号管理」中设置自己的抖音Cookie");
      } else if (errorStr.contains('403')) {
        errorInfo.writeln("【原因】访问被限制（错误403）");
        errorInfo.writeln("【解决方案】");
        errorInfo.writeln("1. 稍后再试");
        errorInfo.writeln("2. 设置自己的Cookie");
      } else if (errorStr.contains('SocketException')) {
        errorInfo.writeln("【原因】网络连接失败");
        errorInfo.writeln("【解决方案】检查网络连接");
      } else if (errorStr.contains('Connection')) {
        errorInfo.writeln("【原因】连接被中断");
        errorInfo.writeln("【解决方案】检查网络或防火墙设置");
      } else if (errorStr.contains('TimeoutException')) {
        errorInfo.writeln("【原因】请求超时");
        errorInfo.writeln("【解决方案】检查网络速度");
      } else {
        errorInfo.writeln("【可能原因】");
        errorInfo.writeln("1. 网络问题");
        errorInfo.writeln("2. 抖音接口变化");
        errorInfo.writeln("3. Cookie过期或无效");
      }
      
      throw Exception(errorInfo.toString());
    }
    
    if (result == "" || result == 'blocked') {
      throw Exception("抖音直播搜索被限制，请稍后再试");
    }
    var items = <LiveRoomItem>[];
    
    // 检查返回数据格式 - 新接口可能使用不同的数据结构
    if (result["data"] == null) {
      return LiveSearchRoomResult(hasMore: false, items: items);
    }
    
    // 不输出控制台日志
    
    // 通用搜索API返回格式可能不同，需要适配
    List dataList = [];
    if (result["data"] is List) {
      dataList = result["data"];
    } else if (result["data"] is Map) {
      // 尝试从Map中提取数据列表
      if (result["data"]["data"] != null) {
        dataList = result["data"]["data"];
      } else if (result["data"]["list"] != null) {
        dataList = result["data"]["list"];
      } else if (result["data"]["aweme_list"] != null) {
        dataList = result["data"]["aweme_list"];
      } else if (result["data"]["live_list"] != null) {
        dataList = result["data"]["live_list"];
      }
    }
    
    if (dataList.isEmpty) {
      return LiveSearchRoomResult(hasMore: false, items: items);
    }
    
    for (var item in dataList) {
      try {
        // 检查item类型
        if (item is! Map) continue;
        
        // 处理type=1的直播搜索结果（新格式）
        if (item["type"] == 1 && item["lives"] != null) {
          var lives = item["lives"];
          
          // 解析rawdata字段
          Map<String, dynamic>? liveData;
          if (lives["rawdata"] != null) {
            var rawdata = lives["rawdata"];
            try {
              liveData = rawdata is String ? json.decode(rawdata) : rawdata;
            } catch (e) {
              if (e is FormatException) {
                CoreLog.error("解析rawdata失败: ${e.message}");
                continue;
              }
              rethrow;
            }
          }
          
          if (liveData != null) {
            // 从rawdata中提取信息
            String? roomId = liveData["id_str"]?.toString() ?? liveData["id"]?.toString();
            if (roomId == null || roomId.isEmpty || roomId == "0") continue;
            
            String? title = liveData["title"]?.toString() ?? "";
            String? cover;
            String? userName;
            int online = 0;
            
            // 获取封面
            if (liveData["cover"] != null && liveData["cover"]["url_list"] != null) {
              var urlList = liveData["cover"]["url_list"];
              if (urlList is List && urlList.isNotEmpty) {
                cover = urlList[0].toString();
              }
            }
            
            // 获取主播信息
            if (liveData["owner"] != null) {
              userName = liveData["owner"]["nickname"]?.toString();
              // 如果owner有web_rid，优先使用
              var webRid = liveData["owner"]["web_rid"]?.toString();
              if (webRid != null && webRid.isNotEmpty) {
                roomId = webRid;
              }
            }
            
            // 从author字段补充信息
            if (lives["author"] != null) {
              userName ??= lives["author"]["nickname"]?.toString();
              // 如果还没有封面，从author获取头像作为封面
              if (cover == null || cover.isEmpty) {
                var avatar = lives["author"]["avatar_larger"];
                if (avatar != null && avatar["url_list"] != null) {
                  var urlList = avatar["url_list"];
                  if (urlList is List && urlList.isNotEmpty) {
                    cover = urlList[0].toString();
                  }
                }
              }
            }
            
            // 获取在线人数
            if (liveData["stats"] != null) {
              online = int.tryParse(liveData["stats"]["total_user"]?.toString() ?? "0") ?? 0;
            } else if (liveData["user_count"] != null) {
              online = int.tryParse(liveData["user_count"].toString()) ?? 0;
            }
            
            var roomItem = LiveRoomItem(
              roomId: roomId,
              title: title.isEmpty ? (userName ?? "") : title,
              cover: cover ?? "",
              userName: userName ?? "",
              online: online,
            );
            items.add(roomItem);
            continue;
          }
        }
        
        // 处理其他格式的直播间数据
        var liveRoom = item["live_room"];
        var liveUser = item["live_user"];
        var liveInfo = item["live"];
        
        // 尝试从多个字段获取数据
        String? roomId;
        String? title;
        String? cover;
        String? userName;
        int? online = 0;
        
        // 获取房间ID
        if (liveRoom != null && liveRoom["web_rid"] != null) {
          roomId = liveRoom["web_rid"].toString();
        } else if (liveUser != null && liveUser["room_id"] != null) {
          roomId = liveUser["room_id"].toString();
        } else if (item["room_id"] != null) {
          roomId = item["room_id"].toString();
        }
        
        if (roomId == null || roomId.isEmpty || roomId == "0") {
          // 尝试旧格式: type=4表示用户/主播结果
          if (item["type"] == 4 && item["user_list"] != null) {
              var userList = item["user_list"] as List;
              for (var user in userList) {
                try {
                  var userInfo = user["user_info"];
                  if (userInfo == null) continue;
                  
                  // 获取房间ID
                  roomId = userInfo["room_id"]?.toString();
                  if (roomId == null || roomId.isEmpty || roomId == "0") {
                    continue; // 跳过没有直播的用户
                  }
                  
                  var roomItem = LiveRoomItem(
                    roomId: roomId,
                    title: userInfo["nickname"]?.toString() ?? "",
                    cover: userInfo["avatar_larger"]?["url_list"]?[0]?.toString() ?? "",
                    userName: userInfo["nickname"]?.toString() ?? "",
                    online: 0,
                  );
                  items.add(roomItem);
                } catch (e) {
                  continue;
                }
              }
            }
            continue;
          }
          
        // 获取标题
        if (liveRoom != null && liveRoom["title"] != null) {
          title = liveRoom["title"].toString();
        } else if (liveInfo != null && liveInfo["title"] != null) {
          title = liveInfo["title"].toString();
        }
        
        // 获取封面
        if (liveRoom != null && liveRoom["cover"] != null) {
          var coverData = liveRoom["cover"];
          if (coverData is Map && coverData["url_list"] != null) {
            var urlList = coverData["url_list"];
            if (urlList is List && urlList.isNotEmpty) {
              cover = urlList[0].toString();
            }
          } else if (coverData is String) {
            cover = coverData;
          }
        }
        
        // 获取用户名
        if (liveUser != null && liveUser["nickname"] != null) {
          userName = liveUser["nickname"].toString();
        } else if (liveRoom != null && liveRoom["owner"] != null && liveRoom["owner"]["nickname"] != null) {
          userName = liveRoom["owner"]["nickname"].toString();
        }
        
        // 获取在线人数
        if (liveRoom != null && liveRoom["user_count"] != null) {
          online = int.tryParse(liveRoom["user_count"].toString()) ?? 0;
        }
        
        var roomItem = LiveRoomItem(
          roomId: roomId,
          title: title ?? userName ?? "",
          cover: cover ?? "",
          userName: userName ?? "",
          online: online,
        );
        items.add(roomItem);
      } catch (e) {
        // 解析搜索结果项失败，跳过
        continue;
      }
    }
    
    // 如果没有找到任何直播间，抛出包含响应数据的异常以便调试
    if (items.isEmpty && dataList.isNotEmpty) {
      // 构建调试信息
      var debugInfo = "抖音搜索未找到直播间，响应数据：\n";
      debugInfo += "关键词: $keyword, 页码: $page\n";
      debugInfo += "dataList长度: ${dataList.length}\n";
      if (dataList.isNotEmpty) {
        var firstItem = dataList[0];
        debugInfo += "第一条数据类型: ${firstItem["type"]}\n";
        debugInfo += "数据样例(前500字符): ${json.encode(firstItem).substring(0, min(500, json.encode(firstItem).length))}";
      }
      throw Exception(debugInfo);
    }
    
    // 直播搜索API每页返回15条，判断是否还有更多数据
    return LiveSearchRoomResult(hasMore: items.length >= 15, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword,
      {int page = 1}) async {
    // 使用与searchRooms相同的搜索接口
    String serverUrl = "https://www.douyin.com/aweme/v1/web/general/search/single/";
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "device_platform": "webapp",
      "aid": "6383",
      "channel": "channel_pc_web",
      "search_channel": "aweme_general",
      "keyword": keyword,
      "search_source": "tab_search",
      "query_correct_type": "1",
      "is_filter_search": "0",
      "from_group_id": "",
      "offset": ((page - 1) * 15).toString(),
      "count": "15",
      "need_filter_settings": "0",
      "list_type": "single",
      "update_version_code": "170400",
      "pc_client_type": "1",
      "version_code": "170400",
      "version_name": "17.4.0",
      "cookie_enabled": "true",
      "screen_width": "1536",
      "screen_height": "864",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "143.0.0.0",
      "browser_online": "true",
      "engine_name": "Blink",
      "engine_version": "143.0.0.0",
      "os_name": "Windows",
      "os_version": "10",
      "device_memory": "8",
      "platform": "PC",
      "downlink": "10",
      "effective_type": "4g",
      "round_trip_time": "50",
      "tab_name": "live",
    });
    var requlestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);
    
    // 使用 getRequestHeaders 获取 Cookie（包含默认 ttwid 或用户设置的 Cookie）
    var requestHeaders = await getRequestHeaders();
    var dyCookie = requestHeaders["cookie"] ?? "";

    var result = await HttpClient.instance.getJson(
      requlestUrl,
      queryParameters: {},
      header: {
        "Authority": 'www.douyin.com',
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'cookie': dyCookie,
        'priority': 'u=1, i',
        'referer':
            'https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?type=live',
        'sec-ch-ua':
            '"Microsoft Edge";v="143", "Chromium";v="143", "Not.A/Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': kDefaultUserAgent,
      },
    );
    if (result == "" || result == 'blocked') {
      throw Exception("抖音直播搜索被限制，请稍后再试");
    }
    var items = <LiveAnchorItem>[];
    
    // 使用与searchRooms相同的数据解析逻辑
    if (result["data"] == null) {
      return LiveSearchAnchorResult(hasMore: false, items: items);
    }
    
    // 不输出控制台日志
    
    // 通用搜索API返回格式可能不同，需要适配
    List dataList = [];
    if (result["data"] is List) {
      dataList = result["data"];
    } else if (result["data"] is Map) {
      // 尝试从Map中提取数据列表
      if (result["data"]["data"] != null) {
        dataList = result["data"]["data"];
      } else if (result["data"]["list"] != null) {
        dataList = result["data"]["list"];
      } else if (result["data"]["aweme_list"] != null) {
        dataList = result["data"]["aweme_list"];
      } else if (result["data"]["live_list"] != null) {
        dataList = result["data"]["live_list"];
      }
    }
    
    if (dataList.isEmpty) {
      return LiveSearchAnchorResult(hasMore: false, items: items);
    }
    
    for (var item in dataList) {
      try {
        // 检查item类型
        if (item is! Map) continue;
        
        // 处理type=1的直播搜索结果（新格式）
        if (item["type"] == 1 && item["lives"] != null) {
          var lives = item["lives"];
          
          // 解析rawdata字段
          Map<String, dynamic>? liveData;
          if (lives["rawdata"] != null) {
            var rawdata = lives["rawdata"];
            try {
              liveData = rawdata is String ? json.decode(rawdata) : rawdata;
            } catch (e) {
              if (e is FormatException) {
                CoreLog.error("解析rawdata失败: ${e.message}");
                continue;
              }
              rethrow;
            }
          }
          
          if (liveData != null) {
            // 从rawdata中提取信息
            String? roomId = liveData["id_str"]?.toString() ?? liveData["id"]?.toString();
            if (roomId == null || roomId.isEmpty || roomId == "0") continue;
            
            String? userName;
            String? avatar;
            bool liveStatus = liveData["status"] == 2; // status=2表示正在直播
            
            // 获取主播信息
            if (liveData["owner"] != null) {
              userName = liveData["owner"]["nickname"]?.toString();
              // 如果owner有web_rid，优先使用
              var webRid = liveData["owner"]["web_rid"]?.toString();
              if (webRid != null && webRid.isNotEmpty) {
                roomId = webRid;
              }
              // 获取头像
              if (liveData["owner"]["avatar_thumb"] != null) {
                var avatarThumb = liveData["owner"]["avatar_thumb"];
                if (avatarThumb["url_list"] != null && (avatarThumb["url_list"] as List).isNotEmpty) {
                  avatar = avatarThumb["url_list"][0].toString();
                }
              }
            }
            
            // 从author字段补充信息
            if (lives["author"] != null) {
              userName ??= lives["author"]["nickname"]?.toString();
              // 如果还没有头像，从author获取
              if (avatar == null || avatar.isEmpty) {
                var avatarData = lives["author"]["avatar_larger"] ?? lives["author"]["avatar_thumb"];
                if (avatarData != null && avatarData["url_list"] != null) {
                  var urlList = avatarData["url_list"];
                  if (urlList is List && urlList.isNotEmpty) {
                    avatar = urlList[0].toString();
                  }
                }
              }
            }
            
            var anchorItem = LiveAnchorItem(
              roomId: roomId,
              avatar: avatar ?? "",
              userName: userName ?? "",
              liveStatus: liveStatus,
            );
            items.add(anchorItem);
            continue;
          }
        }
        
        // 处理其他格式的主播数据
        var liveRoom = item["live_room"];
        var liveUser = item["live_user"];
        
        String? roomId;
        String? userName;
        String? avatar;
        bool liveStatus = false;
        
        // 获取房间ID和用户信息
        if (liveRoom != null && liveRoom["web_rid"] != null) {
          roomId = liveRoom["web_rid"].toString();
          liveStatus = true; // 有直播间信息说明正在直播
          // 从liveRoom获取用户信息
          if (liveRoom["owner"] != null) {
            userName = liveRoom["owner"]["nickname"]?.toString();
          }
        } else if (liveUser != null) {
          // 从liveUser获取信息
          roomId = liveUser["room_id"]?.toString();
          userName = liveUser["nickname"]?.toString();
          liveStatus = liveUser["is_living"] == true;
          // 获取头像
          if (liveUser["avatar_thumb"] != null) {
            var avatarData = liveUser["avatar_thumb"];
            if (avatarData is Map && avatarData["url_list"] != null) {
              var urlList = avatarData["url_list"];
              if (urlList is List && urlList.isNotEmpty) {
                avatar = urlList[0].toString();
              }
            }
          }
        } else if (item["room_id"] != null) {
          roomId = item["room_id"].toString();
        }
        
        if (roomId != null && roomId.isNotEmpty && roomId != "0") {
          var anchorItem = LiveAnchorItem(
            roomId: roomId,
            avatar: avatar ?? "",
            userName: userName ?? "",
            liveStatus: liveStatus,
          );
          items.add(anchorItem);
          continue;
        }
        
        // 尝试旧格式: type=4表示用户/主播结果
        if (item["type"] == 4 && item["user_list"] != null) {
          var userList = item["user_list"] as List;
          for (var user in userList) {
            try {
              var userInfo = user["user_info"];
              if (userInfo == null) continue;
              
              var roomId = userInfo["room_id"]?.toString();
              if (roomId == null || roomId.isEmpty || roomId == "0") {
                continue;
              }
              
              var anchorItem = LiveAnchorItem(
                roomId: roomId,
                avatar: userInfo["avatar_larger"]?["url_list"]?[0]?.toString() ?? "",
                userName: userInfo["nickname"]?.toString() ?? "",
                liveStatus: true, // 有room_id就表示在直播
              );
              items.add(anchorItem);
            } catch (e) {
              // 解析用户项失败，跳过
              continue;
            }
          }
        }
      } catch (e) {
        // 解析主播搜索结果项失败，跳过
        continue;
      }
    }
    
    // 如果没有找到任何主播，抛出包含响应数据的异常以便调试
    if (items.isEmpty && dataList.isNotEmpty) {
      // 构建调试信息
      var debugInfo = "抖音主播搜索未找到结果，响应数据：\n";
      debugInfo += "关键词: $keyword, 页码: $page\n";
      debugInfo += "dataList长度: ${dataList.length}\n";
      if (dataList.isNotEmpty) {
        var firstItem = dataList[0];
        debugInfo += "第一条数据类型: ${firstItem["type"]}\n";
        debugInfo += "数据样例(前500字符): ${json.encode(firstItem).substring(0, min(500, json.encode(firstItem).length))}";
      }
      throw Exception(debugInfo);
    }
    
    // 直播搜索API每页返回15条，判断是否还有更多数据
    return LiveSearchAnchorResult(hasMore: items.length >= 15, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    try {
      // 使用轻量级方法检查直播状态，避免获取完整房间详情
      return await _getLiveStatusLight(roomId);
    } catch (e) {
      // 如果轻量级方法失败，尝试完整方法作为后备
      try {
        var result = await getRoomDetail(roomId: roomId);
        return result.status;
      } catch (e2) {
        String errorStr = e2.toString();
        
        // 如果是404/444错误或直播间不存在，返回false（表示未直播）
        if (errorStr.contains("444") || 
            errorStr.contains("404") || 
            errorStr.contains("不存在") || 
            errorStr.contains("已关闭") ||
            errorStr.contains("已下播")) {
          return false;
        }
        
        // 如果是请求频繁错误，抛出异常让上层处理
        if (errorStr.contains("频繁") || errorStr.contains("limit")) {
          throw Exception("抖音请求过于频繁，请稍后再试");
        }
        
        // 其他错误，记录日志并返回false
        CoreLog.error("获取抖音直播状态失败 [roomId: $roomId]: $e2");
        return false;
      }
    }
  }

  /// 轻量级直播状态检查方法
  /// 只获取必要的状态信息，避免获取完整房间详情
  Future<bool> _getLiveStatusLight(String roomId) async {
    // 判断是webRid还是roomId
    if (roomId.length <= 16) {
      // webRid - 使用API快速检查
      return await _getLiveStatusByApi(roomId);
    } else {
      // roomId - 使用reflow接口检查
      return await _getLiveStatusByRoomId(roomId);
    }
  }

  /// 通过API检查直播状态（适用于webRid）
  Future<bool> _getLiveStatusByApi(String webRid) async {
    String serverUrl = "https://live.douyin.com/webcast/room/web/enter/";
    var requestHeader = await getRequestHeaders();
    requestHeader["Referer"] = "https://live.douyin.com/$webRid";
    
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "browser_language": "zh-CN",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
      "web_rid": webRid,
      "msToken": "",
    });
    
    var requestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);
    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: requestHeader,
    );

    if (result is! Map || !result.containsKey("data")) {
      throw Exception("API返回格式错误");
    }

    var data = result["data"];
    if (data == null || data["data"] == null || data["data"].isEmpty) {
      // 数据为空时抛出异常，让上层fallback到完整方法
      throw Exception("API返回数据为空");
    }

    var roomData = data["data"][0];
    var status = roomData["status"];
    
    // 成功时重置失败计数
    resetCookieFailCount();
    
    return status == 2; // status=2 表示直播中
  }

  /// 通过roomId检查直播状态（适用于长roomId）
  Future<bool> _getLiveStatusByRoomId(String roomId) async {
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: await getRequestHeaders(),
    );
    
    if (result == null || result["data"] == null || result["data"]["room"] == null) {
      // 数据为空时抛出异常，让上层fallback到完整方法
      throw Exception("reflow接口返回数据为空");
    }

    var room = result["data"]["room"];
    var status = room["status"];
    
    // status=4 表示已下播，需要通过webRid再次检查
    if (status == 4) {
      var webRid = room["owner"]?["web_rid"]?.toString();
      if (webRid != null && webRid.isNotEmpty) {
        return await _getLiveStatusByApi(webRid);
      }
      return false;
    }
    
    return status == 2; // status=2 表示直播中
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) {
    return Future.value(<LiveSuperChatMessage>[]);
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  // 生成随机的数字
  int generateRandomNumber(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(10));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item);
    }
    return int.tryParse(stringBuffer.toString()) ??
        Random().nextInt(1000000000);
  }
}
