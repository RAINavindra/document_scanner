#include "include/document_scanner/document_scanner_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "document_scanner_plugin.h"

void DocumentScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  document_scanner::DocumentScannerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
