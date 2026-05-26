using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Windows.Input;

namespace TaskManager;

public sealed class ProcessInfo
{
    public int Id { get; init; }
    public required string Name { get; init; }
    public long WorkingSet { get; init; }
    public string CpuTime { get; init; } = "";
    public bool Responding { get; init; }
}

public sealed class MainViewModel : INotifyPropertyChanged
{
    private string _filterText = "";
    private ProcessInfo? _selected;
    private readonly ObservableCollection<ProcessInfo> _processes = [];
    private List<ProcessInfo> _allProcesses = [];

    public MainViewModel()
    {
        RefreshCommand = new RelayCommand(Refresh);
        KillCommand = new RelayCommand(KillSelected, () => SelectedProcess is not null);
        Refresh();
    }

    public ICommand RefreshCommand { get; }
    public ICommand KillCommand { get; }

    public ObservableCollection<ProcessInfo> Processes => _processes;

    public ProcessInfo? SelectedProcess
    {
        get => _selected;
        set
        {
            if (_selected != value)
            {
                _selected = value;
                OnPropertyChanged();
                ((RelayCommand)KillCommand).RaiseCanExecuteChanged();
            }
        }
    }

    public string FilterText
    {
        get => _filterText;
        set
        {
            if (_filterText != value)
            {
                _filterText = value;
                OnPropertyChanged();
                ApplyFilter();
            }
        }
    }

    public string StatusText => $"{_allProcesses.Count} processes ({_processes.Count} shown)";

    public void Refresh()
    {
        var list = new List<ProcessInfo>();
        try
        {
            foreach (var p in Process.GetProcesses())
            {
                try
                {
                    list.Add(new ProcessInfo
                    {
                        Id = p.Id,
                        Name = p.ProcessName,
                        WorkingSet = p.WorkingSet64,
                        CpuTime = p.TotalProcessorTime.ToString(@"hh\:mm\:ss"),
                        Responding = p.Responding,
                    });
                }
                catch
                {
                    // Process died between enumeration and read
                }
            }
        }
        catch { }

        _allProcesses = [.. list.OrderByDescending(p => p.WorkingSet)];
        ApplyFilter();
    }

    private void KillSelected()
    {
        if (_selected is null) return;
        try
        {
            using var p = Process.GetProcessById(_selected.Id);
            p.Kill();
        }
        catch { }
        Refresh();
    }

    private void ApplyFilter()
    {
        _processes.Clear();
        var filtered = string.IsNullOrWhiteSpace(_filterText)
            ? _allProcesses
            : _allProcesses.Where(p =>
                p.Name.Contains(_filterText, StringComparison.OrdinalIgnoreCase));

        foreach (var p in filtered)
            _processes.Add(p);

        OnPropertyChanged(nameof(StatusText));
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? n = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
}

public sealed class RelayCommand(Action execute, Func<bool>? canExecute = null) : ICommand
{
    private readonly Action _execute = execute;
    private readonly Func<bool>? _canExecute = canExecute;

    public event EventHandler? CanExecuteChanged;

    public bool CanExecute(object? parameter) => _canExecute?.Invoke() ?? true;
    public void Execute(object? parameter) => _execute();
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
