#define _WIN32_WINNT 0x0601
#define UNICODE
#define _UNICODE
// MFC License Validator -- dialog-based MFC application demonstrating MFC
// framework, DDX, Afx functions, and resource loading.
#include <cwctype>
#include <afxwin.h>
#include <afxcmn.h>
#include <cctype>

#include "mfc_app.h"
#include "resource.h"

// MFC shared-DLL entry: AfxWinMain is __stdcall (AFXAPI) in mfc140u.dll.
// Must match the calling convention or x86 linker fails (LNK2019).
__declspec(dllimport) int WINAPI AfxWinMain(HINSTANCE, HINSTANCE, LPWSTR, int);

extern "C" int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrev,
                                LPWSTR lpCmd, int nShow)
{
    return AfxWinMain(hInstance, hPrev, lpCmd, nShow);
}

// ---------------------------------------------------------------------------
// CLicenseApp
// ---------------------------------------------------------------------------
BEGIN_MESSAGE_MAP(CLicenseApp, CWinApp)
END_MESSAGE_MAP()

CLicenseApp theApp;

BOOL CLicenseApp::InitInstance()
{
    CLicenseDlg dlg;
    m_pMainWnd = &dlg;
    dlg.DoModal();
    return FALSE;
}

// ---------------------------------------------------------------------------
// CLicenseDlg
// ---------------------------------------------------------------------------
CLicenseDlg::CLicenseDlg(CWnd* pParent)
    : CDialog(IDD, pParent)
{
}

void CLicenseDlg::DoDataExchange(CDataExchange* pDX)
{
    CDialog::DoDataExchange(pDX);
    DDX_Control(pDX, IDC_LICENSE_INPUT, m_editKey);
    DDX_Control(pDX, IDC_RESULT_TEXT, m_staticResult);
}

BEGIN_MESSAGE_MAP(CLicenseDlg, CDialog)
    ON_BN_CLICKED(IDC_VALIDATE_BTN, &CLicenseDlg::OnValidate)
END_MESSAGE_MAP()

BOOL CLicenseDlg::OnInitDialog()
{
    CDialog::OnInitDialog();
    m_staticResult.SetWindowText(L"Enter a key and click Validate.");
    return TRUE;
}

void CLicenseDlg::OnValidate()
{
    CString key;
    m_editKey.GetWindowText(key);
    if (ValidateKey(key))
        m_staticResult.SetWindowText(L"VALID — License accepted.");
    else
        m_staticResult.SetWindowText(L"INVALID — Check format: XXXX-XXXX-XXXX-XXXX");
}

bool CLicenseDlg::ValidateKey(const CString& key)
{
    if (key.GetLength() != 19) return false;
    for (int i = 0; i < 19; i++) {
        wchar_t ch = key[i];
        if ((i + 1) % 5 == 0) {
            if (ch != L'-') return false;
        } else {
            if (!std::iswxdigit(ch)) return false;
        }
    }
    return key == L"ABCD-EF01-2345-6789";
}
