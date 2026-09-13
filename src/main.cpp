#include <windows.h>
#include <windowsx.h>
#include <wrl.h>
#include <string>
#include <thread>
#include <mutex>
#include <vector>
#include <algorithm>
#include <shlwapi.h>
#include <shellapi.h>
#include "WebView2.h"

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")

using namespace Microsoft::WRL;

static HWND g_hWnd = nullptr;
static ComPtr<ICoreWebView2Controller> g_controller;
static ComPtr<ICoreWebView2> g_webview;
static bool g_autoClean = false;
static bool g_shuttingDown = false;

static std::mutex g_logMutex;
static std::vector<std::wstring> g_logQueue;

// Tracking laufender PowerShell-Prozesse damit wir sie beim Close killen koennen
static std::mutex g_procMutex;
static std::vector<HANDLE> g_activeProcesses;

void RegisterProc(HANDLE h) {
    std::lock_guard<std::mutex> lock(g_procMutex);
    g_activeProcesses.push_back(h);
}
void UnregisterProc(HANDLE h) {
    std::lock_guard<std::mutex> lock(g_procMutex);
    g_activeProcesses.erase(
        std::remove(g_activeProcesses.begin(), g_activeProcesses.end(), h),
        g_activeProcesses.end());
}
void KillAllProcs() {
    std::vector<HANDLE> handles;
    {
        std::lock_guard<std::mutex> lock(g_procMutex);
        handles = g_activeProcesses;
        g_activeProcesses.clear();
    }
    if (handles.empty()) return;

    // Erst warten damit PowerShell finally-Bloecke / trap-Handler
    // (die Services wieder starten, Hives unmounten) durchlaufen koennen
    DWORD waitResult = WaitForMultipleObjects(
        (DWORD)handles.size(), handles.data(), TRUE, 5000);

    // Wer noch laeuft: hart killen
    for (HANDLE h : handles) {
        DWORD ec = 0;
        if (GetExitCodeProcess(h, &ec) && ec == STILL_ACTIVE) {
            TerminateProcess(h, 1);
        }
    }
}

std::wstring EscapeJson(const std::wstring& s) {
    std::wstring out;
    out.reserve(s.size() + 8);
    for (wchar_t c : s) {
        switch (c) {
            case L'\\': out += L"\\\\"; break;
            case L'"':  out += L"\\\""; break;
            case L'\n': out += L"\\n"; break;
            case L'\r': out += L"\\r"; break;
            case L'\t': out += L"\\t"; break;
            default:
                if (c < 0x20) {
                    wchar_t buf[8];
                    swprintf_s(buf, L"\\u%04x", (unsigned)c);
                    out += buf;
                } else {
                    out += c;
                }
        }
    }
    return out;
}

std::wstring Utf8ToWide(const std::string& s) {
    if (s.empty()) return L"";
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    if (n <= 0) return L"";
    std::wstring out(n, 0);
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), &out[0], n);
    return out;
}

void QueueLogLine(const std::wstring& level, const std::wstring& text) {
    std::wstring msg = L"{\"type\":\"log\",\"level\":\"" + level + L"\",\"text\":\"" + EscapeJson(text) + L"\"}";
    {
        std::lock_guard<std::mutex> lock(g_logMutex);
        g_logQueue.push_back(msg);
    }
    PostMessage(g_hWnd, WM_APP + 3, 0, 0);
}

std::wstring DetectLevel(const std::wstring& line) {
    if (line.find(L"[OK]") != std::wstring::npos) return L"ok";
    if (line.find(L"[WARN]") != std::wstring::npos) return L"warn";
    if (line.find(L"[ERR]") != std::wstring::npos) return L"err";
    if (line.find(L"[INFO]") != std::wstring::npos) return L"info";
    if (line.find(L"[DEL]") != std::wstring::npos) return L"del";
    return L"raw";
}

std::wstring GetExeDir() {
    wchar_t buf[MAX_PATH];
    GetModuleFileNameW(nullptr, buf, MAX_PATH);
    PathRemoveFileSpecW(buf);
    return std::wstring(buf) + L"\\";
}

std::wstring PathToFileUri(const std::wstring& path) {
    std::wstring uri = L"file:///";
    for (auto c : path) {
        uri += (c == L'\\') ? L'/' : c;
    }
    return uri;
}

void SendToWebView(const std::wstring& json) {
    if (g_webview) {
        g_webview->PostWebMessageAsString(json.c_str());
    }
}


void RunPowerShellPiped(std::wstring cmd, const std::wstring& exeDir) {
    SECURITY_ATTRIBUTES sa = {};
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;
    HANDLE hRead = nullptr, hWrite = nullptr;
    if (!CreatePipe(&hRead, &hWrite, &sa, 0)) {
        QueueLogLine(L"err", L"Pipe konnte nicht erstellt werden");
        PostMessage(g_hWnd, WM_APP + 2, 0, 0);
        return;
    }
    SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
    si.wShowWindow = SW_HIDE;
    si.hStdOutput = hWrite;
    si.hStdError = hWrite;
    si.hStdInput = nullptr;
    PROCESS_INFORMATION pi = {};

    BOOL ok = CreateProcessW(
        nullptr, &cmd[0], nullptr, nullptr, TRUE,
        CREATE_NO_WINDOW, nullptr, exeDir.c_str(), &si, &pi);

    CloseHandle(hWrite);

    if (!ok) {
        CloseHandle(hRead);
        QueueLogLine(L"err", L"PowerShell konnte nicht gestartet werden");
        PostMessage(g_hWnd, WM_APP + 2, 0, 0);
        return;
    }

    RegisterProc(pi.hProcess);

    std::thread([pi, hRead]() {
        char buf[4096];
        DWORD bytesRead = 0;
        std::string lineBuf;
        while (ReadFile(hRead, buf, sizeof(buf), &bytesRead, nullptr) && bytesRead > 0) {
            lineBuf.append(buf, bytesRead);
            size_t nl;
            while ((nl = lineBuf.find('\n')) != std::string::npos) {
                std::string line = lineBuf.substr(0, nl);
                if (!line.empty() && line.back() == '\r') line.pop_back();
                lineBuf.erase(0, nl + 1);
                if (!line.empty()) {
                    std::wstring wline = Utf8ToWide(line);
                    QueueLogLine(DetectLevel(wline), wline);
                }
            }
        }
        if (!lineBuf.empty()) {
            std::wstring wline = Utf8ToWide(lineBuf);
            QueueLogLine(DetectLevel(wline), wline);
        }
        CloseHandle(hRead);
        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD exitCode = 0;
        GetExitCodeProcess(pi.hProcess, &exitCode);
        UnregisterProc(pi.hProcess);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        if (!g_shuttingDown) {
            PostMessage(g_hWnd, exitCode == 0 ? (WM_APP + 1) : (WM_APP + 2), 0, 0);
        }
    }).detach();
}

void RunPowerShellScript(const std::wstring& script, const std::wstring& args) {
    std::wstring exeDir = GetExeDir();
    std::wstring fullScript = exeDir + script;

    QueueLogLine(L"info", L"=== " + script + L" " + args + L" ===");

    std::wstring cmd = L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \""
                       L"try { & '" + fullScript + L"' " + args + L" *>&1 } "
                       L"catch { [Console]::WriteLine('[ERR] ' + $_.Exception.Message) }; exit 0\"";

    RunPowerShellPiped(cmd, exeDir);
}

void RunStealthCleanSync() {
    std::wstring exeDir = GetExeDir();
    std::wstring fullScript = exeDir + L"scripts\\clean-self.ps1";

    std::wstring cmd = L"powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command \""
                       L"try { & '" + fullScript + L"' -Silent } catch {}; exit 0\"";

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi = {};

    if (CreateProcessW(nullptr, &cmd[0], nullptr, nullptr, FALSE,
            CREATE_NO_WINDOW, nullptr, exeDir.c_str(), &si, &pi)) {
        WaitForSingleObject(pi.hProcess, 30000);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }
}

bool IsRunAsAdmin() {
    BOOL isAdmin = FALSE;
    PSID adminGroup = nullptr;
    SID_IDENTIFIER_AUTHORITY ntAuth = SECURITY_NT_AUTHORITY;
    if (AllocateAndInitializeSid(&ntAuth, 2, SECURITY_BUILTIN_DOMAIN_RID,
            DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup)) {
        CheckTokenMembership(nullptr, adminGroup, &isAdmin);
        FreeSid(adminGroup);
    }
    return isAdmin != FALSE;
}

void RelaunchAsAdmin() {
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    ShellExecuteW(nullptr, L"runas", exePath, nullptr, nullptr, SW_SHOWNORMAL);
    PostQuitMessage(0);
}

void OnWebMessage(const wchar_t* json) {
    std::wstring msg(json);

    auto findValue = [&](const std::wstring& key) -> std::wstring {
        std::wstring search = L"\"" + key + L"\":\"";
        auto pos = msg.find(search);
        if (pos == std::wstring::npos) return L"";
        pos += search.length();
        auto end = msg.find(L"\"", pos);
        if (end == std::wstring::npos) return L"";
        return msg.substr(pos, end - pos);
    };

    // Boolean-Wert aus JSON
    auto findBool = [&](const std::wstring& key) -> bool {
        std::wstring search = L"\"" + key + L"\":";
        auto pos = msg.find(search);
        if (pos == std::wstring::npos) return false;
        pos += search.length();
        return msg.substr(pos, 4) == L"true";
    };

    std::wstring type = findValue(L"type");

    if (type == L"powershell") {
        std::wstring script = findValue(L"script");
        std::wstring args = findValue(L"args");
        std::wstring cleanScript;
        for (size_t i = 0; i < script.size(); i++) {
            if (script[i] == L'\\' && i + 1 < script.size() && script[i+1] == L'\\') {
                cleanScript += L'\\';
                i++;
            } else {
                cleanScript += script[i];
            }
        }
        RunPowerShellScript(cleanScript, args);
    }
    else if (type == L"ps-direct") {
        std::wstring psCmd = findValue(L"cmd");
        QueueLogLine(L"info", L"=== ps-direct ===");
        std::wstring cmd = L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \""
                           L"try { " + psCmd + L" *>&1 } "
                           L"catch { [Console]::WriteLine('[ERR] ' + $_.Exception.Message) }; exit 0\"";
        RunPowerShellPiped(cmd, GetExeDir());
    }
    else if (type == L"setting") {
        std::wstring id = findValue(L"id");
        bool value = findBool(L"value");

        if (id == L"auto-clean") {
            g_autoClean = value;
        }
        else if (id == L"admin-mode" && value) {
            if (!IsRunAsAdmin()) {
                RelaunchAsAdmin();
            } else {
                SendToWebView(L"{\"type\":\"already-admin\"}");
            }
        }
    }
    else if (type == L"window") {
        std::wstring action = findValue(L"action");
        if (action == L"close") {
            PostMessage(g_hWnd, WM_CLOSE, 0, 0);
        }
        else if (action == L"minimize") {
            PostMessage(g_hWnd, WM_APP + 10, 0, 0);
        }
        else if (action == L"maximize") {
            PostMessage(g_hWnd, WM_APP + 11, 0, 0);
        }
        else if (action == L"drag") {
            PostMessage(g_hWnd, WM_APP + 12, 0, 0);
        }
    }
}

void InitWebView(HWND hWnd) {
    // WebView2 mit Windows-Standard-UserDataFolder (%LOCALAPPDATA%)
    // Portable-Mode (wv2data neben EXE) verursachte Locking-Probleme bei Admin-Elevation + Restart
    CreateCoreWebView2EnvironmentWithOptions(
        nullptr, nullptr, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [hWnd](HRESULT hr, ICoreWebView2Environment* env) -> HRESULT {
                if (FAILED(hr) || !env) return hr;
                env->CreateCoreWebView2Controller(hWnd,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [hWnd](HRESULT hr, ICoreWebView2Controller* ctrl) -> HRESULT {
                            if (FAILED(hr) || !ctrl) return hr;
                            g_controller = ctrl;
                            g_controller->get_CoreWebView2(&g_webview);

                            ComPtr<ICoreWebView2Settings> settings;
                            g_webview->get_Settings(&settings);
                            settings->put_AreDefaultContextMenusEnabled(FALSE);
                            settings->put_IsStatusBarEnabled(FALSE);

                            g_webview->add_WebMessageReceived(
                                Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                                    [](ICoreWebView2* wv, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                                        LPWSTR msg;
                                        if (SUCCEEDED(args->TryGetWebMessageAsString(&msg))) {
                                            OnWebMessage(msg);
                                            CoTaskMemFree(msg);
                                        }
                                        return S_OK;
                                    }).Get(), nullptr);

                            RECT bounds;
                            GetClientRect(hWnd, &bounds);
                            const int edge = 4;
                            bounds.left += edge;
                            bounds.top += edge;
                            bounds.right -= edge;
                            bounds.bottom -= edge;
                            g_controller->put_Bounds(bounds);

                            std::wstring uri = PathToFileUri(GetExeDir() + L"atlas-gui.html");
                            g_webview->Navigate(uri.c_str());

                            g_webview->add_NavigationCompleted(
                                Callback<ICoreWebView2NavigationCompletedEventHandler>(
                                    [](ICoreWebView2* wv, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                                        BOOL success;
                                        args->get_IsSuccess(&success);
                                        if (success) {
                                            bool admin = IsRunAsAdmin();
                                            std::wstring msg = L"{\"type\":\"admin-status\",\"admin\":";
                                            msg += admin ? L"true" : L"false";
                                            msg += L"}";
                                            SendToWebView(msg);
                                        }
                                        return S_OK;
                                    }).Get(), nullptr);

                            return S_OK;
                        }).Get());
                return S_OK;
            }).Get());
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_SIZE:
        if (g_controller) {
            RECT bounds;
            GetClientRect(hWnd, &bounds);
            const int edge = 4;
            bounds.left += edge;
            bounds.top += edge;
            bounds.right -= edge;
            bounds.bottom -= edge;
            g_controller->put_Bounds(bounds);
        }
        return 0;
    case WM_GETMINMAXINFO: {
        auto mmi = reinterpret_cast<MINMAXINFO*>(lParam);
        mmi->ptMinTrackSize.x = 500;
        mmi->ptMinTrackSize.y = 400;
        return 0;
    }
    case WM_NCCALCSIZE:
        if (wParam == TRUE) {
            return 0;
        }
        return 0;
    case WM_NCHITTEST: {
        POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
        RECT rc;
        GetWindowRect(hWnd, &rc);
        const int border = 5;
        bool l = pt.x - rc.left < border;
        bool r = rc.right - pt.x < border;
        bool t = pt.y - rc.top < border;
        bool b = rc.bottom - pt.y < border;
        if (t && l) return HTTOPLEFT;
        if (t && r) return HTTOPRIGHT;
        if (b && l) return HTBOTTOMLEFT;
        if (b && r) return HTBOTTOMRIGHT;
        if (l) return HTLEFT;
        if (r) return HTRIGHT;
        if (t) return HTTOP;
        if (b) return HTBOTTOM;
        return HTCLIENT;
    }
    case WM_APP + 1:
        SendToWebView(L"{\"type\":\"ps-done\"}");
        return 0;
    case WM_APP + 2:
        SendToWebView(L"{\"type\":\"ps-error\",\"message\":\"Script Fehler\"}");
        return 0;
    case WM_APP + 3: {
        std::vector<std::wstring> toSend;
        {
            std::lock_guard<std::mutex> lock(g_logMutex);
            toSend.swap(g_logQueue);
        }
        for (const auto& m : toSend) {
            SendToWebView(m);
        }
        return 0;
    }
    case WM_APP + 10:
        ShowWindow(hWnd, SW_MINIMIZE);
        return 0;
    case WM_APP + 11:
        ShowWindow(hWnd, IsZoomed(hWnd) ? SW_RESTORE : SW_MAXIMIZE);
        return 0;
    case WM_APP + 12:
        ReleaseCapture();
        SendMessage(hWnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
        return 0;
    case WM_CLOSE:
        g_shuttingDown = true;
        KillAllProcs();
        if (g_autoClean) {
            RunStealthCleanSync();
        }
        // WebView2 sauber schliessen damit msedgewebview2.exe nicht haengen bleibt
        if (g_controller) {
            g_controller->Close();
            g_controller = nullptr;
            g_webview = nullptr;
        }
        DestroyWindow(hWnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int nCmdShow) {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"DisplayHelper";
    wc.hIcon = LoadIconW(hInstance, L"IDI_ICON1");
    wc.hIconSm = LoadIconW(hInstance, L"IDI_ICON1");
    wc.hCursor = LoadCursorW(nullptr, MAKEINTRESOURCEW(32512));
    wc.hbrBackground = CreateSolidBrush(RGB(10, 10, 26));
    RegisterClassExW(&wc);

    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);
    int winW = 760, winH = 780;
    int posX = (screenW - winW) / 2;
    int posY = (screenH - winH) / 2;

    g_hWnd = CreateWindowExW(
        0, L"DisplayHelper", L"Desktop Widget Host",
        WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX,
        posX, posY, winW, winH,
        nullptr, nullptr, hInstance, nullptr);

    ShowWindow(g_hWnd, nCmdShow);
    UpdateWindow(g_hWnd);

    InitWebView(g_hWnd);

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    CoUninitialize();
    return 0;
}
