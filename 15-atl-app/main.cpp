// ATL Window Application
// Demonstrates COM initialization, ATL window classes, and message maps.
//
// Build: cmake -B build && cmake --build build
// Requires: Visual Studio with ATL headers

#define UNICODE
#define _UNICODE
#include <atlbase.h>
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

#include <atlwin.h>
#include <atltypes.h>
#include <commctrl.h>
#include <windowsx.h>

#include <cwchar>
#include <cctype>
#include <cstring>

// ---------------------------------------------------------------------------
// ATL module - single-instance application module
// ---------------------------------------------------------------------------
class CAtlAppModule : public CAtlExeModuleT<CAtlAppModule>
{
};
CAtlAppModule _AtlModule;

// ---------------------------------------------------------------------------
// Control ID constants
// ---------------------------------------------------------------------------
enum
{
    IDC_SERIAL_EDIT = 1001,
    IDC_VALIDATE_BTN,
    IDC_RESULT_TEXT,
};

// ---------------------------------------------------------------------------
// CMainWindow - the application's main frame
// ---------------------------------------------------------------------------
class CMainWindow : public CWindowImpl<CMainWindow, CWindow, CWinTraits<WS_OVERLAPPEDWINDOW | WS_VISIBLE, WS_EX_APPWINDOW>>
{
public:
    DECLARE_WND_CLASS(L"ATLSampleWindow")

    BEGIN_MSG_MAP(CMainWindow)
        MESSAGE_HANDLER(WM_CREATE,   OnCreate)
        MESSAGE_HANDLER(WM_DESTROY,  OnDestroy)
        MESSAGE_HANDLER(WM_COMMAND,  OnCommand)
        MESSAGE_HANDLER(WM_PAINT,    OnPaint)
    END_MSG_MAP()

    // -----------------------------------------------------------------------
    // WM_CREATE - instantiate child controls
    // -----------------------------------------------------------------------
    LRESULT OnCreate(UINT /*uMsg*/, WPARAM /*wParam*/, LPARAM /*lParam*/,
                     BOOL& bHandled)
    {
        HFONT hFont = static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));

        HWND hwnd;
        hwnd = CreateWindowW(WC_STATIC, L"Enter 8-digit hex serial:",
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            20, 20, 280, 20, m_hWnd, nullptr, nullptr, nullptr);
        m_labelPrompt.Attach(hwnd);
        m_labelPrompt.SetFont(hFont);

        hwnd = CreateWindowW(WC_EDIT, L"",
            WS_CHILD | WS_VISIBLE | WS_BORDER | ES_UPPERCASE | ES_AUTOHSCROLL,
            20, 45, 280, 20, m_hWnd, (HMENU)(INT_PTR)IDC_SERIAL_EDIT, nullptr, nullptr);
        m_editSerial.Attach(hwnd);
        m_editSerial.SetFont(hFont);
        m_editSerial.SendMessage(EM_SETLIMITTEXT, 8, 0);

        hwnd = CreateWindowW(WC_BUTTON, L"Validate",
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            120, 80, 80, 24, m_hWnd, (HMENU)(INT_PTR)IDC_VALIDATE_BTN, nullptr, nullptr);
        m_btnValidate.Attach(hwnd);
        m_btnValidate.SetFont(hFont);

        hwnd = CreateWindowW(WC_STATIC, L"",
            WS_CHILD | WS_VISIBLE | SS_CENTER,
            20, 120, 280, 60, m_hWnd, (HMENU)(INT_PTR)IDC_RESULT_TEXT, nullptr, nullptr);
        m_staticResult.Attach(hwnd);
        m_staticResult.SetFont(hFont);

        return 0;
    }

    // -----------------------------------------------------------------------
    // WM_DESTROY - quit the application
    // -----------------------------------------------------------------------
    LRESULT OnDestroy(UINT /*uMsg*/, WPARAM /*wParam*/, LPARAM /*lParam*/,
                      BOOL& bHandled)
    {
        PostQuitMessage(0);
        return 0;
    }

    // -----------------------------------------------------------------------
    // WM_COMMAND - handle button click
    // -----------------------------------------------------------------------
    LRESULT OnCommand(UINT /*uMsg*/, WPARAM wParam, LPARAM /*lParam*/,
                      BOOL& bHandled)
    {
        if (HIWORD(wParam) == BN_CLICKED &&
            LOWORD(wParam) == IDC_VALIDATE_BTN)
        {
            wchar_t buf[16] = {};
            m_editSerial.GetWindowText(buf, 16);

            if (IsValidHexSerial(buf))
            {
                m_staticResult.SetWindowText(L"PASS - Valid serial");
            }
            else
            {
                m_staticResult.SetWindowText(L"FAIL - Invalid serial");
            }
        }
        return 0;
    }

    // -----------------------------------------------------------------------
    // WM_PAINT - draw a subtle vertical gradient background
    // -----------------------------------------------------------------------
    LRESULT OnPaint(UINT /*uMsg*/, WPARAM /*wParam*/, LPARAM /*lParam*/,
                    BOOL& bHandled)
    {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(&ps);

        RECT rc;
        GetClientRect(&rc);

        // Vertical gradient from dark teal to a lighter shade
        const COLORREF topColor      = RGB(0x00, 0x5F, 0x6B);
        const COLORREF bottomColor   = RGB(0x00, 0x96, 0xA0);
        const int      height        = rc.bottom - rc.top;
        const int      r0            = GetRValue(topColor);
        const int      g0            = GetGValue(topColor);
        const int      b0            = GetBValue(topColor);
        const int      r1            = GetRValue(bottomColor);
        const int      g1            = GetGValue(bottomColor);
        const int      b1            = GetBValue(bottomColor);

        for (int y = 0; y < height; ++y)
        {
            const int r = r0 + (r1 - r0) * y / height;
            const int g = g0 + (g1 - g0) * y / height;
            const int b = b0 + (b1 - b0) * y / height;

            HPEN   hPen   = CreatePen(PS_SOLID, 1, RGB(r, g, b));
            HGDIOBJ hOldPen = SelectObject(hdc, hPen);

            MoveToEx(hdc, rc.left, rc.top + y, nullptr);
            LineTo(hdc, rc.right, rc.top + y);

            SelectObject(hdc, hOldPen);
            DeleteObject(hPen);
        }

        EndPaint(&ps);
        return 0;
    }

private:
    // -----------------------------------------------------------------------
    // Validate that the input is exactly 8 uppercase hex characters
    // -----------------------------------------------------------------------
    static bool IsValidHexSerial(const wchar_t* str)
    {
        if (!str || std::wcslen(str) != 8)
            return false;

        for (int i = 0; i < 8; ++i)
        {
            if (!std::isxdigit(static_cast<unsigned char>(str[i])))
                return false;
        }
        return true;
    }

    // -----------------------------------------------------------------------
    // Position child controls inside the client area
    // -----------------------------------------------------------------------
    void LayoutControls()
    {
        RECT rc;
        GetClientRect(&rc);
        const int margin  = 20;
        const int cx      = rc.right  - rc.left - 2 * margin;
        const int rowH    = 24;
        const int gap     = 10;

        // Prompt label
        m_labelPrompt.SetWindowPos(nullptr,
            margin, margin, cx, rowH, SWP_NOZORDER);

        // Edit box
        m_editSerial.SetWindowPos(nullptr,
            margin, margin + rowH + gap, cx, rowH, SWP_NOZORDER);

        // Validate button (centred, narrower)
        const int btnCx = 100;
        const int btnX  = margin + (cx - btnCx) / 2;
        m_btnValidate.SetWindowPos(nullptr,
            btnX, margin + 2 * (rowH + gap), btnCx, rowH, SWP_NOZORDER);

        // Result text
        m_staticResult.SetWindowPos(nullptr,
            margin, margin + 3 * (rowH + gap), cx, rowH, SWP_NOZORDER);
    }

    // Control children
    CWindow m_labelPrompt;
    CWindow m_editSerial;
    CWindow m_btnValidate;
    CWindow m_staticResult;
};

// ---------------------------------------------------------------------------
// WinMain - entry point
// ---------------------------------------------------------------------------
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE /*hPrev*/, LPSTR /*lpCmd*/,
                   int nCmdShow)
{
    // Initialize COM
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr))
    {
        MessageBoxA(nullptr, "COM initialization failed.",
                    "ATL Sample", MB_ICONERROR);
        return 1;
    }

    // Ensure COM is uninitialized on exit
    struct ComGuard
    {
        ~ComGuard() { CoUninitialize(); }
    } comGuard;

    // ATL module setup (simplified — no COM server registration needed)

    // Create the main window
    CMainWindow wnd;
    if (!wnd.Create(nullptr, CWindow::rcDefault, L"ATL Serial Validator"))
    {
        MessageBoxA(nullptr, "Window creation failed.",
                    "ATL Sample", MB_ICONERROR);
        _AtlModule.Term();
        return 1;
    }

    wnd.ShowWindow(nCmdShow);
    wnd.UpdateWindow();

    // Message loop
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // Cleanup ATL module
    _AtlModule.Term();

    return static_cast<int>(msg.wParam);
}
