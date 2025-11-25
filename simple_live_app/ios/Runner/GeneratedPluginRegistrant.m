//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<auto_orientation_v2/AutoOrientationPlugin.h>)
#import <auto_orientation_v2/AutoOrientationPlugin.h>
#else
@import auto_orientation_v2;
#endif

#if __has_include(<connectivity_plus/ConnectivityPlusPlugin.h>)
#import <connectivity_plus/ConnectivityPlusPlugin.h>
#else
@import connectivity_plus;
#endif

#if __has_include(<device_info_plus/FPPDeviceInfoPlusPlugin.h>)
#import <device_info_plus/FPPDeviceInfoPlusPlugin.h>
#else
@import device_info_plus;
#endif

#if __has_include(<file_picker/FilePickerPlugin.h>)
#import <file_picker/FilePickerPlugin.h>
#else
@import file_picker;
#endif

#if __has_include(<flutter_inappwebview/InAppWebViewFlutterPlugin.h>)
#import <flutter_inappwebview/InAppWebViewFlutterPlugin.h>
#else
@import flutter_inappwebview;
#endif

#if __has_include(<flutter_js/FlutterJsPlugin.h>)
#import <flutter_js/FlutterJsPlugin.h>
#else
@import flutter_js;
#endif

#if __has_include(<image_gallery_saver/ImageGallerySaverPlugin.h>)
#import <image_gallery_saver/ImageGallerySaverPlugin.h>
#else
@import image_gallery_saver;
#endif

#if __has_include(<media_kit_libs_ios_video/MediaKitLibsIosVideoPlugin.h>)
#import <media_kit_libs_ios_video/MediaKitLibsIosVideoPlugin.h>
#else
@import media_kit_libs_ios_video;
#endif

#if __has_include(<media_kit_video/MediaKitVideoPlugin.h>)
#import <media_kit_video/MediaKitVideoPlugin.h>
#else
@import media_kit_video;
#endif

#if __has_include(<network_info_plus/FPPNetworkInfoPlusPlugin.h>)
#import <network_info_plus/FPPNetworkInfoPlusPlugin.h>
#else
@import network_info_plus;
#endif

#if __has_include(<package_info_plus/FPPPackageInfoPlusPlugin.h>)
#import <package_info_plus/FPPPackageInfoPlusPlugin.h>
#else
@import package_info_plus;
#endif

#if __has_include(<path_provider_foundation/PathProviderPlugin.h>)
#import <path_provider_foundation/PathProviderPlugin.h>
#else
@import path_provider_foundation;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<qr_code_scanner/FlutterQrPlugin.h>)
#import <qr_code_scanner/FlutterQrPlugin.h>
#else
@import qr_code_scanner;
#endif

#if __has_include(<screen_brightness_ios/ScreenBrightnessIosPlugin.h>)
#import <screen_brightness_ios/ScreenBrightnessIosPlugin.h>
#else
@import screen_brightness_ios;
#endif

#if __has_include(<share_plus/FPPSharePlusPlugin.h>)
#import <share_plus/FPPSharePlusPlugin.h>
#else
@import share_plus;
#endif

#if __has_include(<url_launcher_ios/URLLauncherPlugin.h>)
#import <url_launcher_ios/URLLauncherPlugin.h>
#else
@import url_launcher_ios;
#endif

#if __has_include(<volume_controller/VolumeControllerPlugin.h>)
#import <volume_controller/VolumeControllerPlugin.h>
#else
@import volume_controller;
#endif

#if __has_include(<wakelock_plus/WakelockPlusPlugin.h>)
#import <wakelock_plus/WakelockPlusPlugin.h>
#else
@import wakelock_plus;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AutoOrientationPlugin registerWithRegistrar:[registry registrarForPlugin:@"AutoOrientationPlugin"]];
  [ConnectivityPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"ConnectivityPlusPlugin"]];
  [FPPDeviceInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPDeviceInfoPlusPlugin"]];
  [FilePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FilePickerPlugin"]];
  [InAppWebViewFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"InAppWebViewFlutterPlugin"]];
  [FlutterJsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterJsPlugin"]];
  [ImageGallerySaverPlugin registerWithRegistrar:[registry registrarForPlugin:@"ImageGallerySaverPlugin"]];
  [MediaKitLibsIosVideoPlugin registerWithRegistrar:[registry registrarForPlugin:@"MediaKitLibsIosVideoPlugin"]];
  [MediaKitVideoPlugin registerWithRegistrar:[registry registrarForPlugin:@"MediaKitVideoPlugin"]];
  [FPPNetworkInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPNetworkInfoPlusPlugin"]];
  [FPPPackageInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPPackageInfoPlusPlugin"]];
  [PathProviderPlugin registerWithRegistrar:[registry registrarForPlugin:@"PathProviderPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
  [FlutterQrPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterQrPlugin"]];
  [ScreenBrightnessIosPlugin registerWithRegistrar:[registry registrarForPlugin:@"ScreenBrightnessIosPlugin"]];
  [FPPSharePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPSharePlusPlugin"]];
  [URLLauncherPlugin registerWithRegistrar:[registry registrarForPlugin:@"URLLauncherPlugin"]];
  [VolumeControllerPlugin registerWithRegistrar:[registry registrarForPlugin:@"VolumeControllerPlugin"]];
  [WakelockPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"WakelockPlusPlugin"]];
}

@end
