#include "flutter_window.h"

#include <optional>

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

namespace {

FlutterWindow* g_caption_window = nullptr;

constexpr DWORD kRoundedCorners = 2;  // DWMWCP_ROUND

}  // namespace

LRESULT CALLBACK CaptionChildProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
  if (message == WM_NCHITTEST && g_caption_window != nullptr) {
    // Let the top-level window own resize borders and caption buttons so
    // Windows 11 snap layouts still see HTMAXBUTTON.
    if (g_caption_window->CaptionHitTest(lparam) != HTCLIENT) {
      return HTTRANSPARENT;
    }
  }
  if (g_caption_window != nullptr &&
      g_caption_window->original_child_proc_ != nullptr) {
    return CallWindowProc(g_caption_window->original_child_proc_, hwnd, message,
                          wparam, lparam);
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "native_tavern/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleWindowMethod(call, std::move(result)); });

  HWND hwnd = GetHandle();
  // A 1px frame extension keeps the DWM shadow after the caption is removed.
  const MARGINS margins = {0, 0, 0, 1};
  DwmExtendFrameIntoClientArea(hwnd, &margins);
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &kRoundedCorners,
                        sizeof(kRoundedCorners));
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);
  EnsureChildHook();

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
  if (child_hwnd_ != nullptr && original_child_proc_ != nullptr) {
    SetWindowLongPtr(child_hwnd_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(original_child_proc_));
    child_hwnd_ = nullptr;
    original_child_proc_ = nullptr;
  }
  if (g_caption_window == this) {
    g_caption_window = nullptr;
  }
  flutter_controller_ = nullptr;
  Win32Window::OnDestroy();
}

void FlutterWindow::EnsureChildHook() {
  if (!flutter_controller_ || !flutter_controller_->view()) {
    return;
  }
  HWND child = flutter_controller_->view()->GetNativeWindow();
  if (child == nullptr) {
    return;
  }
  g_caption_window = this;
  if (child != child_hwnd_) {
    if (child_hwnd_ != nullptr && original_child_proc_ != nullptr) {
      SetWindowLongPtr(child_hwnd_, GWLP_WNDPROC,
                       reinterpret_cast<LONG_PTR>(original_child_proc_));
    }
    child_hwnd_ = child;
    original_child_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
        child, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(CaptionChildProc)));
    return;
  }
  auto* current = reinterpret_cast<WNDPROC>(GetWindowLongPtr(child, GWLP_WNDPROC));
  if (current != CaptionChildProc) {
    original_child_proc_ = current;
    SetWindowLongPtr(child, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(CaptionChildProc));
  }
}

int FlutterWindow::FrameBorder() {
  HWND hwnd = GetHandle();
  const UINT dpi = hwnd == nullptr ? 96 : GetDpiForWindow(hwnd);
  int border = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
               GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
  if (border < 8) {
    border = 8;
  }
  return border;
}

LRESULT FlutterWindow::CaptionHitTest(LPARAM lparam) {
  HWND root = GetHandle();
  if (root == nullptr) {
    return HTCLIENT;
  }
  POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  RECT window_rect{};
  if (!GetWindowRect(root, &window_rect)) {
    return HTCLIENT;
  }
  if (!IsZoomed(root)) {
    const int border = FrameBorder();
    const bool left = pt.x < window_rect.left + border;
    const bool right = pt.x >= window_rect.right - border;
    const bool top = pt.y < window_rect.top + border;
    const bool bottom = pt.y >= window_rect.bottom - border;
    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
  }
  // Caption buttons (min/max/close) are Flutter widgets. Returning
  // HT*BUTTON here makes Windows draw native button chrome over them.
  return HTCLIENT;
}

void FlutterWindow::ApplyMaximizedClientArea(HWND window, LPARAM lparam) const {
  if (!IsZoomed(window)) {
    return;
  }
  WINDOWINFO window_info{};
  window_info.cbSize = sizeof(window_info);
  if (!GetWindowInfo(window, &window_info)) {
    return;
  }
  auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
  params->rgrc[0].left += window_info.cxWindowBorders;
  params->rgrc[0].right -= window_info.cxWindowBorders;
  params->rgrc[0].top += window_info.cyWindowBorders;
  params->rgrc[0].bottom -= window_info.cyWindowBorders;
}

void FlutterWindow::NotifyZoomed() noexcept {
  try {
    if (!channel_) {
      return;
    }
    const bool zoomed = IsZoomed(GetHandle()) == TRUE;
    if (zoomed_reported_ && zoomed == zoomed_) {
      return;
    }
    zoomed_ = zoomed;
    zoomed_reported_ = true;
    channel_->InvokeMethod("windowState",
                           std::make_unique<flutter::EncodableValue>(zoomed));
  } catch (...) {
  }
}

void FlutterWindow::StartDragging() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  ReleaseCapture();
  SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

void FlutterWindow::HandleWindowMethod(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "immersiveTitleBar") {
    result->Success(flutter::EncodableValue(true));
    return;
  }
  if (method == "startDragging") {
    StartDragging();
    result->Success();
    return;
  }
  if (method == "toggleMaximize") {
    HWND hwnd = GetHandle();
    if (hwnd != nullptr) {
      ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
    }
    result->Success();
    return;
  }
  if (method == "minimize") {
    HWND hwnd = GetHandle();
    if (hwnd != nullptr) {
      ShowWindow(hwnd, SW_MINIMIZE);
    }
    result->Success();
    return;
  }
  if (method == "close") {
    HWND hwnd = GetHandle();
    if (hwnd != nullptr) {
      PostMessage(hwnd, WM_CLOSE, 0, 0);
    }
    result->Success();
    return;
  }
  result->NotImplemented();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCALCSIZE && wparam == TRUE) {
    ApplyMaximizedClientArea(hwnd, lparam);
    return 0;
  }
  if (message == WM_NCHITTEST) {
    const LRESULT hit = CaptionHitTest(lparam);
    if (hit != HTCLIENT) {
      return hit;
    }
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
    case WM_SIZE:
      EnsureChildHook();
      NotifyZoomed();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
