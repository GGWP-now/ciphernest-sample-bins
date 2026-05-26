#define UNICODE
#define _UNICODE
#include <windows.h>
#include <commctrl.h>
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

#include <cwctype>
#include "resource.h"

// ---------------------------------------------------------------------------
// License key validation: must be 19 characters in XXXX-XXXX-XXXX-XXXX format
// (16 alphanumeric characters + 3 dashes).
// ---------------------------------------------------------------------------
static bool ValidateLicenseKey(const wchar_t* key)
{
    size_t len = wcslen(key);
    if (len != 19)
        return false;

    for (int i = 0; i < 19; i++)
    {
        if (i == 4 || i == 9 || i == 14)
        {
            if (key[i] != L'-')
                return false;
        }
        else
        {
            if (!iswalnum(key[i]))
                return false;
        }
    }
    return true;
}

// ---------------------------------------------------------------------------
// Main window procedure
// ---------------------------------------------------------------------------
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_CREATE:
        // License key input (masked)
        CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_PASSWORD | ES_AUTOHSCROLL,
            30, 30, 300, 22,
            hWnd, (HMENU)IDC_KEY_INPUT, nullptr, nullptr);

        // Result text (empty initially)
        CreateWindowW(L"STATIC", L"",
            WS_CHILD | WS_VISIBLE,
            30, 65, 300, 22,
            hWnd, (HMENU)IDC_RESULT_TEXT, nullptr, nullptr);

        // Validate button
        CreateWindowW(L"BUTTON", L"&Validate",
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            130, 100, 80, 28,
            hWnd, (HMENU)IDC_CHECK_BTN, nullptr, nullptr);
        break;

    case WM_COMMAND:
        if (LOWORD(wParam) == IDC_CHECK_BTN)
        {
            wchar_t buffer[32] = {};
            GetDlgItemTextW(hWnd, IDC_KEY_INPUT, buffer, 32);

            if (ValidateLicenseKey(buffer))
                SetDlgItemTextW(hWnd, IDC_RESULT_TEXT, L"Valid license!");
            else
                SetDlgItemTextW(hWnd, IDC_RESULT_TEXT, L"Invalid license");
        }
        break;

    case WM_DESTROY:
        PostQuitMessage(0);
        break;

    default:
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int nCmdShow)
{
    // Enable Visual Styles via Common Controls v6 (manifest also declared in RC)
    INITCOMMONCONTROLSEX icex = { sizeof(INITCOMMONCONTROLSEX), ICC_STANDARD_CLASSES };
    InitCommonControlsEx(&icex);

    // Register window class
    WNDCLASSEXW wc = {};
    wc.cbSize        = sizeof(WNDCLASSEXW);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = WndProc;
    wc.hInstance     = hInstance;
    wc.hIcon         = LoadIconW(nullptr, IDI_APPLICATION);
    wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = L"LicenseWindowClass";

    if (!RegisterClassExW(&wc))
        return 1;

    // Create main window
    HWND hWnd = CreateWindowExW(0,
        L"LicenseWindowClass",
        L"License Key Validation",
        WS_OVERLAPPEDWINDOW & ~WS_MAXIMIZEBOX & ~WS_THICKFRAME,
        CW_USEDEFAULT, CW_USEDEFAULT,
        390, 190,
        nullptr, nullptr, hInstance, nullptr);

    if (!hWnd)
        return 1;

    ShowWindow(hWnd, nCmdShow);
    UpdateWindow(hWnd);

    // Message loop
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return (int)msg.wParam;
}
