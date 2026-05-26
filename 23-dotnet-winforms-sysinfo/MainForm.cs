using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;

namespace SysInfoViewer;

public sealed partial class MainForm : Form
{
    private readonly TabControl _tabs = new() { Dock = DockStyle.Fill };
    private readonly ListView _envList = CreateListView(["Variable", "Value"]);
    private readonly ListView _drivesList = CreateListView(["Drive", "Type", "Total Size", "Free Space", "Label"]);
    private readonly ListView _memoryList = CreateListView(["Property", "Value"]);
    private readonly TextBox _summaryBox = new()
    {
        Dock = DockStyle.Fill,
        Font = new Font("Consolas", 10),
        Multiline = true,
        ReadOnly = true,
        ScrollBars = ScrollBars.Both,
    };

    public MainForm()
    {
        Text = "WinForms System Info Viewer";
        Size = new Size(900, 600);
        StartPosition = FormStartPosition.CenterScreen;
        Icon = SystemIcons.Application;

        InitializeTabs();
        LoadData();
    }

    private void InitializeTabs()
    {
        TabPage AddTab(string title, Control ctl)
        {
            var page = new TabPage(title);
            page.Controls.Add(ctl);
            _tabs.TabPages.Add(page);
            return page;
        }
        AddTab("Summary", _summaryBox);
        AddTab("Environment", _envList);
        AddTab("Drives", _drivesList);
        AddTab("Memory", _memoryList);

        var refreshBtn = new Button
        {
            Text = "Refresh",
            Location = new Point(12, 12),
            AutoSize = true,
        };
        refreshBtn.Click += (_, _) => LoadData();

        var copyBtn = new Button
        {
            Text = "Copy All",
            Location = new Point(refreshBtn.Right + 8, 12),
            AutoSize = true,
        };
        copyBtn.Click += CopyAll_Click;

        var panel = new Panel { Dock = DockStyle.Top, Height = 48 };
        panel.Controls.AddRange([refreshBtn, copyBtn]);

        Controls.Add(_tabs);
        Controls.Add(panel);
    }

    private void LoadData()
    {
        LoadSummary();
        LoadEnvironment();
        LoadDrives();
        LoadMemory();
    }

    private void LoadSummary()
    {
        var sb = new StringBuilder();
        sb.AppendLine($"OS:          {RuntimeInformation.OSDescription}");
        sb.AppendLine($"Framework:   {RuntimeInformation.FrameworkDescription}");
        sb.AppendLine($"Process Arch:{RuntimeInformation.ProcessArchitecture}");
        sb.AppendLine($"OS Arch:     {RuntimeInformation.OSArchitecture}");
        sb.AppendLine();

        try
        {
            var os = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem");
            foreach (var o in os.Get())
            {
                sb.AppendLine($"Machine:     {o["CSName"]}");
                sb.AppendLine($"Registered:  {o["RegisteredUser"]}");
                sb.AppendLine($"Last Boot:   {o["LastBootUpTime"]}");
                sb.AppendLine();
            }
        }
        catch { sb.AppendLine("(WMI unavailable)"); }

        try
        {
            var cpus = new ManagementObjectSearcher("SELECT * FROM Win32_Processor");
            int i = 0;
            foreach (var cpu in cpus.Get())
            {
                sb.AppendLine($"CPU {i++}:      {cpu["Name"]}");
                sb.AppendLine($"  Cores:    {cpu["NumberOfCores"]}");
                sb.AppendLine($"  Threads:  {cpu["NumberOfLogicalProcessors"]}");
            }
        }
        catch { sb.AppendLine("(CPU info unavailable)"); }

        _summaryBox.Text = sb.ToString();
    }

    private void LoadEnvironment()
    {
        _envList.BeginUpdate();
        _envList.Items.Clear();
        foreach (var key in Environment.GetEnvironmentVariables().Keys
                     .Cast<string>().OrderBy(k => k))
        {
            _envList.Items.Add(new ListViewItem([
                key, Environment.GetEnvironmentVariable(key) ?? ""
            ]));
        }
        _envList.EndUpdate();
    }

    private void LoadDrives()
    {
        _drivesList.BeginUpdate();
        _drivesList.Items.Clear();
        foreach (var drive in DriveInfo.GetDrives())
        {
            _drivesList.Items.Add(new ListViewItem([
                drive.Name,
                drive.DriveType.ToString(),
                drive.IsReady ? drive.TotalSize.ToString("N0") : "N/A",
                drive.IsReady ? drive.AvailableFreeSpace.ToString("N0") : "N/A",
                drive.IsReady ? drive.VolumeLabel : "N/A",
            ]));
        }
        _drivesList.EndUpdate();
    }

    private void LoadMemory()
    {
        _memoryList.BeginUpdate();
        _memoryList.Items.Clear();

        var mem = new Microsoft.VisualBasic.Devices.ComputerInfo();
        _memoryList.Items.Add(new ListViewItem(["Total Physical",   $"{mem.TotalPhysicalMemory:N0} bytes"]));
        _memoryList.Items.Add(new ListViewItem(["Available Physical", $"{mem.AvailablePhysicalMemory:N0} bytes"]));
        _memoryList.Items.Add(new ListViewItem(["Total Virtual",    $"{mem.TotalVirtualMemory:N0} bytes"]));
        _memoryList.Items.Add(new ListViewItem(["Available Virtual", $"{mem.AvailableVirtualMemory:N0} bytes"]));

        using var proc = Process.GetCurrentProcess();
        _memoryList.Items.Add(new ListViewItem(["Process Working Set", $"{proc.WorkingSet64:N0} bytes"]));
        _memoryList.Items.Add(new ListViewItem(["Process Private",     $"{proc.PrivateMemorySize64:N0} bytes"]));
        _memoryList.Items.Add(new ListViewItem(["Peak Working Set",    $"{proc.PeakWorkingSet64:N0} bytes"]));

        _memoryList.EndUpdate();
    }

    private void CopyAll_Click(object? sender, EventArgs e)
    {
        var sb = new StringBuilder();
        sb.AppendLine(_summaryBox.Text);
        Clipboard.SetText(sb.ToString());
    }

    private static ListView CreateListView(string[] columns)
    {
        var lv = new ListView
        {
            Dock = DockStyle.Fill,
            View = View.Details,
            FullRowSelect = true,
            GridLines = true,
        };
        foreach (var c in columns)
            lv.Columns.Add(c, -2);
        return lv;
    }
}
