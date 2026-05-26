#pragma once

#include "MainWindow.g.h"

namespace winrt::WinUIApp::implementation
{
    struct MainWindow : MainWindowT<MainWindow>
    {
        MainWindow();

        void OnAddClick(Windows::Foundation::IInspectable const& sender,
                        Microsoft::UI::Xaml::RoutedEventArgs const& args);
        void OnClearClick(Windows::Foundation::IInspectable const& sender,
                          Microsoft::UI::Xaml::RoutedEventArgs const& args);
        winrt::fire_and_forget OnAsyncClick(Windows::Foundation::IInspectable const& sender,
                                            Microsoft::UI::Xaml::RoutedEventArgs const& args);

    private:
        int _seq{ 0 };
        void SetStatus(winrt::Microsoft::UI::Xaml::Controls::InfoBarSeverity severity,
                       hstring const& title, hstring const& message);
    };
}

namespace winrt::WinUIApp::factory_implementation
{
    struct MainWindow : MainWindowT<MainWindow, implementation::MainWindow>
    {
    };
}
