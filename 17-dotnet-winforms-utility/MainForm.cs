using System.Diagnostics;
using System.Numerics;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

namespace MetadataInspector;

public partial class MainForm : Form
{
    private readonly TabControl _tabControl;
    private DataGridView _metadataGrid = null!;
    private Label _systemInfoLabel = null!;
    private RichTextBox _jitResults = null!;
    private Label _unsafeResult = null!;

    public MainForm()
    {
        Text = "Metadata Inspector & JIT Stress Tool";
        Size = new Size(1000, 700);
        StartPosition = FormStartPosition.CenterScreen;

        _tabControl = new TabControl { Dock = DockStyle.Fill };
        _tabControl.TabPages.AddRange(new[] {
            BuildMetadataTab(),
            BuildPInvokeTab(),
            BuildJitTab(),
        });

        Controls.Add(_tabControl);
    }

    // ── Metadata Tab ──────────────────────────────────────────

    private TabPage BuildMetadataTab()
    {
        var tab = new TabPage("Metadata");

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
        };

        var topPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
        };

        var scanBtn = new Button
        {
            Text = "Scan Core Assembly",
            AutoSize = true,
            Margin = new Padding(10),
        };
        scanBtn.Click += MetadataScanButton_Click;
        topPanel.Controls.Add(scanBtn);

        _metadataGrid = new DataGridView
        {
            Dock = DockStyle.Fill,
            AllowUserToAddRows = false,
            ReadOnly = true,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
        };

        // Set up columns after creation so they persist
        _metadataGrid.Columns.Add("TypeColumn", "Type");
        _metadataGrid.Columns.Add("MethodsColumn", "Method Count");

        layout.Controls.Add(topPanel, 0, 0);
        layout.Controls.Add(_metadataGrid, 0, 1);

        tab.Controls.Add(layout);
        return tab;
    }

    private void MetadataScanButton_Click(object? sender, EventArgs e)
    {
        _metadataGrid.Rows.Clear();

        try
        {
            // Scan the core BCL assembly (System.Private.CoreLib)
            var asm = typeof(object).Assembly;
            var types = asm.GetExportedTypes();

            int count = 0;
            foreach (var type in types)
            {
                if (count++ >= 100)
                    break;

                try
                {
                    var methods = type.GetMethods(
                        BindingFlags.Public |
                        BindingFlags.Instance |
                        BindingFlags.Static |
                        BindingFlags.DeclaredOnly);
                    _metadataGrid.Rows.Add((type.FullName ?? type.Name), methods.Length);
                }
                catch
                {
                    // Skip types that can't be reflected (generic params, etc.)
                }
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to scan assembly: {ex.Message}", "Error",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    // ── P/Invoke Tab ───────────────────────────────────────────

    private TabPage BuildPInvokeTab()
    {
        var tab = new TabPage("P/Invoke");

        var layout = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            Padding = new Padding(10),
        };

        var btn = new Button
        {
            Text = "Call kernel32!GetSystemInfo",
            AutoSize = true,
        };
        btn.Click += PInvokeButton_Click;
        layout.Controls.Add(btn);

        _systemInfoLabel = new Label
        {
            AutoSize = true,
            Text = "Press button to query system information...",
        };
        layout.Controls.Add(_systemInfoLabel);

        tab.Controls.Add(layout);
        return tab;
    }

    [DllImport("kernel32.dll")]
    private static extern void GetSystemInfo(out SYSTEM_INFO lpSystemInfo);

    [StructLayout(LayoutKind.Sequential)]
    private struct SYSTEM_INFO
    {
        public ushort wProcessorArchitecture;
        public ushort wReserved;
        public uint dwPageSize;
        public IntPtr lpMinimumApplicationAddress;
        public IntPtr lpMaximumApplicationAddress;
        public IntPtr dwActiveProcessorMask;
        public uint dwNumberOfProcessors;
        public uint dwProcessorType;
        public uint dwAllocationGranularity;
        public ushort wProcessorLevel;
        public ushort wProcessorRevision;
    }

    private void PInvokeButton_Click(object? sender, EventArgs e)
    {
        GetSystemInfo(out var info);

        _systemInfoLabel.Text =
            $"Architecture:          {info.wProcessorArchitecture}\n" +
            $"Page Size:             {info.dwPageSize} bytes\n" +
            $"Min App Address:       0x{info.lpMinimumApplicationAddress:X16}\n" +
            $"Max App Address:       0x{info.lpMaximumApplicationAddress:X16}\n" +
            $"Active Processor Mask: 0x{info.dwActiveProcessorMask:X16}\n" +
            $"Number of Processors:  {info.dwNumberOfProcessors}\n" +
            $"Processor Type:        {info.dwProcessorType}\n" +
            $"Allocation Granularity: {info.dwAllocationGranularity}\n" +
            $"Processor Level:       {info.wProcessorLevel}\n" +
            $"Processor Revision:    0x{info.wProcessorRevision:X4}";
    }

    // ── JIT Stress Tab ─────────────────────────────────────────

    private TabPage BuildJitTab()
    {
        var tab = new TabPage("JIT Stress");

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
        };

        var btnPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
        };

        var runBtn = new Button
        {
            Text = "Run JIT Stress Tests",
            AutoSize = true,
            Margin = new Padding(10),
        };
        runBtn.Click += JitButton_Click;
        btnPanel.Controls.Add(runBtn);

        var unsafeBtn = new Button
        {
            Text = "Run Unsafe Pointer Test",
            AutoSize = true,
            Margin = new Padding(10),
        };
        unsafeBtn.Click += UnsafeButton_Click;
        btnPanel.Controls.Add(unsafeBtn);

        _jitResults = new RichTextBox
        {
            Dock = DockStyle.Fill,
            Font = new Font("Consolas", 9, FontStyle.Regular),
            ReadOnly = true,
        };

        _unsafeResult = new Label
        {
            Dock = DockStyle.Bottom,
            AutoSize = true,
            TextAlign = ContentAlignment.MiddleLeft,
        };

        layout.Controls.Add(btnPanel, 0, 0);
        layout.Controls.Add(_jitResults, 0, 1);

        tab.Controls.Add(layout);
        tab.Controls.Add(_unsafeResult);

        return tab;
    }

    private void JitButton_Click(object? sender, EventArgs e)
    {
        _jitResults.Clear();
        var sb = new StringBuilder();

        const int iterations = 100_000_000;
        var sw = new Stopwatch();

        // 1. int loop
        sw.Restart();
        int sum = 0;
        for (int i = 0; i < iterations; i++)
            sum += i;
        sw.Stop();
        sb.AppendLine($"int loop ({iterations:N0} iterations): {sw.ElapsedMilliseconds} ms  (sum={sum})");

        // 2. double loop
        sw.Restart();
        double dsum = 0.0;
        for (int i = 0; i < iterations; i++)
            dsum += i * 1.5;
        sw.Stop();
        sb.AppendLine($"double loop ({iterations:N0} iterations): {sw.ElapsedMilliseconds} ms  (sum={dsum:F2})");

        // 3. generics (using IAdditionOperators<T,T,T>)
        sw.Restart();
        long gsum = 0;
        for (int i = 0; i < iterations; i++)
            gsum += GenericAdd(i, i);
        sw.Stop();
        sb.AppendLine($"generics<int> ({iterations:N0} iterations): {sw.ElapsedMilliseconds} ms  (sum={gsum})");

        // 4. value-type struct math
        sw.Restart();
        var acc = new Vec2(1, 1);
        for (int i = 0; i < iterations; i++)
            acc = acc.Add(new Vec2(i, i));
        sw.Stop();
        sb.AppendLine($"value-type struct ({iterations:N0} iterations): {sw.ElapsedMilliseconds} ms  ({acc})");

        _jitResults.Text = sb.ToString();
    }

    private static T GenericAdd<T>(T a, T b)
        where T : struct, IAdditionOperators<T, T, T>
    {
        return a + b;
    }

    private readonly record struct Vec2(int X, int Y)
    {
        public Vec2 Add(Vec2 other) => new(X + other.X, Y + other.Y);

        public override string ToString() => $"({X}, {Y})";
    }

    private unsafe void UnsafeButton_Click(object? sender, EventArgs e)
    {
        // Demonstrate pointer arithmetic on a stackalloc array
        int* ptr = stackalloc int[10];
        for (int i = 0; i < 10; i++)
            ptr[i] = i * i;

        // Traverse via pointer arithmetic (incrementing pointer)
        int sum = 0;
        int* current = ptr;
        for (int i = 0; i < 10; i++)
        {
            sum += *current;
            current++;
        }

        // Traverse using pointer comparison
        int product = 1;
        for (int* p = ptr; p < ptr + 10; p++)
        {
            if (*p != 0)
                product *= *p;
        }

        _unsafeResult.Text =
            $"Stackalloc pointer arithmetic: sum of squares 0..9 = {sum}, " +
            $"product (excluding zero) = {product}";
    }
}
