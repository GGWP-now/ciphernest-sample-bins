namespace MatchingGame;

using System.Data;

public sealed partial class MainForm : Form
{
    private static readonly string[] SymbolPairs =
        ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼"];

    private readonly Button[,] _buttons = new Button[4, 4];
    private readonly string[,] _board = new string[4, 4];

    private int _firstRow = -1, _firstCol = -1;
    private int _secondRow = -1, _secondCol = -1;

    private bool _isProcessing;
    private int _moveCount;
    private int _elapsed;

    private readonly System.Windows.Forms.Timer _gameTimer;
    private readonly Label _timerLabel;
    private readonly Label _movesLabel;
    private readonly DataTable _historyTable;
    private readonly Button _newGameButton;

    public MainForm()
    {
        Text = "Matching Game";
        Size = new Size(520, 720);
        MinimumSize = Size;
        MaximumSize = Size;
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        BackColor = Color.FromArgb(240, 240, 245);

        _gameTimer = new System.Windows.Forms.Timer { Interval = 1000 };
        _gameTimer.Tick += GameTimer_Tick;

        SuspendLayout();

        // ── Title ──
        var titleLabel = new Label
        {
            Text = "Matching Game",
            Font = new Font("Segoe UI", 20, FontStyle.Bold),
            ForeColor = Color.FromArgb(40, 40, 60),
            TextAlign = ContentAlignment.MiddleCenter,
            Dock = DockStyle.Top,
            Height = 55,
        };

        // ── Status bar (timer + moves) ──
        var statusPanel = new TableLayoutPanel
        {
            ColumnCount = 2,
            RowCount = 1,
            Dock = DockStyle.Top,
            Height = 32,
            BackColor = Color.Transparent,
        };
        statusPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        statusPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));

        _timerLabel = new Label
        {
            Text = "Time: 0s",
            Font = new Font("Segoe UI", 11, FontStyle.Regular),
            TextAlign = ContentAlignment.MiddleCenter,
            Dock = DockStyle.Fill,
        };
        _movesLabel = new Label
        {
            Text = "Moves: 0",
            Font = new Font("Segoe UI", 11, FontStyle.Regular),
            TextAlign = ContentAlignment.MiddleCenter,
            Dock = DockStyle.Fill,
        };
        statusPanel.Controls.Add(_timerLabel, 0, 0);
        statusPanel.Controls.Add(_movesLabel, 1, 0);

        // ── 4×4 Button grid ──
        var gridPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 408,
            Padding = new Padding(8),
            BackColor = Color.Transparent,
        };
        for (int i = 0; i < 4; i++)
        {
            gridPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25));
            gridPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 25));
        }

        // ── New Game button ──
        _newGameButton = new Button
        {
            Text = "New Game",
            Font = new Font("Segoe UI", 11, FontStyle.Bold),
            Dock = DockStyle.Top,
            Height = 38,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(60, 60, 90),
            ForeColor = Color.White,
            FlatAppearance = { BorderSize = 0 },
            Cursor = Cursors.Hand,
        };
        _newGameButton.Click += NewGame_Click;

        // ── History grid ──
        _historyTable = new DataTable();
        _historyTable.Columns.Add("Move", typeof(int));
        _historyTable.Columns.Add("Card 1", typeof(string));
        _historyTable.Columns.Add("Card 2", typeof(string));
        _historyTable.Columns.Add("Result", typeof(string));

        var historyGrid = new DataGridView
        {
            DataSource = _historyTable,
            Dock = DockStyle.Fill,
            AllowUserToAddRows = false,
            AllowUserToDeleteRows = false,
            ReadOnly = true,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
            Font = new Font("Segoe UI", 9),
            SelectionMode = DataGridViewSelectionMode.FullRowSelect,
            MultiSelect = false,
            RowHeadersVisible = false,
            BackgroundColor = Color.White,
            BorderStyle = BorderStyle.Fixed3D,
        };

        var bottomPanel = new Panel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(10, 0, 10, 10),
            BackColor = Color.Transparent,
        };
        var historyLabel = new Label
        {
            Text = "Game History",
            Font = new Font("Segoe UI", 10, FontStyle.Bold),
            Dock = DockStyle.Top,
            Height = 24,
            ForeColor = Color.FromArgb(40, 40, 60),
        };
        bottomPanel.Controls.Add(historyGrid);
        bottomPanel.Controls.Add(historyLabel);

        // ── Assemble ──
        Controls.Add(bottomPanel);
        Controls.Add(_newGameButton);
        Controls.Add(gridPanel);
        Controls.Add(statusPanel);
        Controls.Add(titleLabel);

        // ── Create card buttons ──
        for (int r = 0; r < 4; r++)
        {
            for (int c = 0; c < 4; c++)
            {
                var btn = new Button
                {
                    Dock = DockStyle.Fill,
                    Font = new Font("Segoe UI", 20, FontStyle.Bold),
                    FlatStyle = FlatStyle.Flat,
                    FlatAppearance =
                    {
                        BorderColor = Color.FromArgb(180, 180, 195),
                        BorderSize = 1,
                    },
                    BackColor = Color.FromArgb(70, 70, 100),
                    ForeColor = Color.White,
                    Margin = new Padding(4),
                    Cursor = Cursors.Hand,
                    Enabled = false,
                };
                btn.Click += Card_Click;
                _buttons[r, c] = btn;
                gridPanel.Controls.Add(btn, c, r);
            }
        }

        ResumeLayout(true);

        NewGame();
    }

    // ──────────────────────────────────────────────
    //  Game logic
    // ──────────────────────────────────────────────

    private void NewGame()
    {
        _gameTimer.Stop();
        _elapsed = 0;
        _moveCount = 0;
        _firstRow = _firstCol = -1;
        _secondRow = _secondCol = -1;
        _isProcessing = false;

        _historyTable.Clear();
        _timerLabel.Text = "Time: 0s";
        _movesLabel.Text = "Moves: 0";

        // Shuffle symbol pairs
        var list = new List<string>(16);
        foreach (var s in SymbolPairs)
        {
            list.Add(s);
            list.Add(s);
        }

        var rng = Random.Shared;
        for (int i = list.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (list[i], list[j]) = (list[j], list[i]);
        }

        int idx = 0;
        for (int r = 0; r < 4; r++)
        {
            for (int c = 0; c < 4; c++)
            {
                _board[r, c] = list[idx++];
                _buttons[r, c].Text = "?";
                _buttons[r, c].BackColor = Color.FromArgb(70, 70, 100);
                _buttons[r, c].ForeColor = Color.White;
                _buttons[r, c].Enabled = true;
            }
        }

        _gameTimer.Start();
    }

    private void NewGame_Click(object? sender, EventArgs e)
    {
        NewGame();
    }

    private async void Card_Click(object? sender, EventArgs e)
    {
        if (_isProcessing || sender is not Button btn)
            return;

        var tag = btn.Tag;
        // Tag might already be set from a previous run; set it lazily
        if (tag is null)
        {
            for (int r = 0; r < 4; r++)
            {
                for (int c = 0; c < 4; c++)
                {
                    if (_buttons[r, c] == btn)
                    {
                        btn.Tag = (r, c);
                        tag = (r, c);
                        goto found;
                    }
                }
            }
            return; // should not happen
        }
        found:

        var (cr, cc) = ((int, int))tag!;

        // Ignore clicks on already-matched cards
        if (_buttons[cr, cc].Text != "?")
            return;

        // Reveal
        btn.Text = _board[cr, cc];
        btn.BackColor = Color.WhiteSmoke;
        btn.ForeColor = Color.Black;

        if (_firstRow == -1)
        {
            (_firstRow, _firstCol) = (cr, cc);
            return;
        }

        // Second card
        (_secondRow, _secondCol) = (cr, cc);
        _moveCount++;
        _movesLabel.Text = $"Moves: {_moveCount}";
        _isProcessing = true;

        bool match = _board[_firstRow, _firstCol] == _board[_secondRow, _secondCol];

        if (match)
        {
            // Keep revealed
            _buttons[_firstRow, _firstCol].BackColor = Color.FromArgb(180, 230, 180);
            _buttons[_secondRow, _secondCol].BackColor = Color.FromArgb(180, 230, 180);
            _buttons[_firstRow, _firstCol].Enabled = false;
            _buttons[_secondRow, _secondCol].Enabled = false;

            _historyTable.Rows.Add(
                _moveCount,
                _board[_firstRow, _firstCol],
                _board[_secondRow, _secondCol],
                "Match");

            _firstRow = _firstCol = -1;
            _secondRow = _secondCol = -1;
            _isProcessing = false;

            CheckGameOver();
            return;
        }

        // Mismatch
        _historyTable.Rows.Add(
            _moveCount,
            _board[_firstRow, _firstCol],
            _board[_secondRow, _secondCol],
            "Mismatch");

        await Task.Delay(800);

        // Flip back (guard against double-settle during the 800ms window)
        if (!_isProcessing)
            return;

        _buttons[_firstRow, _firstCol].Text = "?";
        _buttons[_firstRow, _firstCol].BackColor = Color.FromArgb(70, 70, 100);
        _buttons[_firstRow, _firstCol].ForeColor = Color.White;

        _buttons[_secondRow, _secondCol].Text = "?";
        _buttons[_secondRow, _secondCol].BackColor = Color.FromArgb(70, 70, 100);
        _buttons[_secondRow, _secondCol].ForeColor = Color.White;

        _firstRow = _firstCol = -1;
        _secondRow = _secondCol = -1;
        _isProcessing = false;
    }

    private void CheckGameOver()
    {
        for (int r = 0; r < 4; r++)
        {
            for (int c = 0; c < 4; c++)
            {
                if (_buttons[r, c].Enabled)
                    return;
            }
        }

        _gameTimer.Stop();
        _timerLabel.Text = $"Time: {_elapsed}s - Complete!";

        MessageBox.Show(
            $"You won in {_moveCount} moves and {_elapsed} seconds!",
            "Game Over",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }

    private void GameTimer_Tick(object? sender, EventArgs e)
    {
        _elapsed++;
        _timerLabel.Text = _buttons[0, 0].Enabled
            ? $"Time: {_elapsed}s"
            : $"Time: {_elapsed}s - Complete!";
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _gameTimer?.Dispose();
        }
        base.Dispose(disposing);
    }
}
