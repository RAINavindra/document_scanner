#ifndef FLUTTER_PLUGIN_DOCUMENT_SCANNER_PLUGIN_H_
#define FLUTTER_PLUGIN_DOCUMENT_SCANNER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace document_scanner {

class DocumentScannerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  DocumentScannerPlugin();

  virtual ~DocumentScannerPlugin();

  // Disallow copy and assign.
  DocumentScannerPlugin(const DocumentScannerPlugin&) = delete;
  DocumentScannerPlugin& operator=(const DocumentScannerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace document_scanner

#endif  // FLUTTER_PLUGIN_DOCUMENT_SCANNER_PLUGIN_H_
