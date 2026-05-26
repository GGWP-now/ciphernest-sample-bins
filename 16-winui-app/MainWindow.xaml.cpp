#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.g.cpp")
#include "MainWindow.g.cpp"
#endif

#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Dispatching.h>

#include <string>

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Controls;
using namespace Microsoft::UI::Dispatching;

namespace winrt::WinUIApp::implementation
{
    MainWindow::MainWindow()
    {
        InitializeComponent();
    }

    void MainWindow::OnAddClick(IInspectable const&, RoutedEventArgs const&)
    {
        auto text = InputBox().Text();
        if (text.empty())
        {
            SetStatus(InfoBarSeverity::Warning, L"Empty", L"Type something before clicking Add.");
            return;
        }
        ++_seq;
        std::wstring line = L"#" + std::to_wstring(_seq) + L": " + std::wstring(text.c_str());
        ItemList().Items().Append(box_value(hstring{ line }));
        InputBox().Text(L"");
        SetStatus(InfoBarSeverity::Success, L"Added",
                  hstring{ L"Added item #" + std::to_wstring(_seq) + L"." });
    }

    void MainWindow::OnClearClick(IInspectable const&, RoutedEventArgs const&)
    {
        ItemList().Items().Clear();
        _seq = 0;
        SetStatus(InfoBarSeverity::Informational, L"Cleared", L"All items removed.");
    }

    fire_and_forget MainWindow::OnAsyncClick(IInspectable const&, RoutedEventArgs const&)
    {
        auto lifetime = get_strong();
        WorkButton().IsEnabled(false);
        SetStatus(InfoBarSeverity::Informational, L"Working", L"Running background work...");

        co_await resume_background();

        long long sum = 0;
        for (int i = 1; i <= 1'000'000; ++i) sum += i;

        DispatcherQueue::GetForCurrentThread().TryEnqueue([lifetime, sum]()
        {
            std::wstring line = L"async sum 1..1_000_000 = " + std::to_wstring(sum);
            lifetime->ItemList().Items().Append(box_value(hstring{ line }));
            lifetime->SetStatus(InfoBarSeverity::Success, L"Done",
                                L"Computed on background, marshalled back to UI thread.");
            lifetime->WorkButton().IsEnabled(true);
        });
    }

    void MainWindow::SetStatus(InfoBarSeverity severity, hstring const& title, hstring const& message)
    {
        Status().Severity(severity);
        Status().Title(title);
        Status().Message(message);
        Status().IsOpen(true);
    }
}
