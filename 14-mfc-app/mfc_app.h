#pragma once
#include <afxwin.h>
#include <afxcmn.h>
#include "resource.h"

class CLicenseApp : public CWinApp
{
public:
    virtual BOOL InitInstance();
    DECLARE_MESSAGE_MAP()
};

class CLicenseDlg : public CDialog
{
public:
    CLicenseDlg(CWnd* pParent = nullptr);
    enum { IDD = IDD_MAIN_DLG };

protected:
    virtual void DoDataExchange(CDataExchange* pDX);
    virtual BOOL OnInitDialog();
    afx_msg void OnValidate();
    DECLARE_MESSAGE_MAP()

private:
    CEdit   m_editKey;
    CStatic m_staticResult;
    static bool ValidateKey(const CString& key);
};
