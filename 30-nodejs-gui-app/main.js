const { execFile } = require("node:child_process");
const crypto = require("node:crypto");

const value = process.argv.slice(2).join(" ") || "matrix-safe";
const digest = crypto.createHash("sha256").update(value).digest("hex").slice(0, 24);

const script = `
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Node.js GUI Victim'
$form.ClientSize = New-Object System.Drawing.Size(420, 160)
$form.StartPosition = 'CenterScreen'
$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(18, 18)
$label.Text = 'Node.js packaged executable'
$result = New-Object System.Windows.Forms.TextBox
$result.ReadOnly = $true
$result.Location = New-Object System.Drawing.Point(18, 52)
$result.Size = New-Object System.Drawing.Size(380, 24)
$result.Text = '${value.replace(/'/g, "''")} -> ${digest}'
$button = New-Object System.Windows.Forms.Button
$button.Text = 'Close'
$button.Location = New-Object System.Drawing.Point(323, 100)
$button.Add_Click({ $form.Close() })
$form.Controls.AddRange(@($label, $result, $button))
[void]$form.ShowDialog()
`;

execFile("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script], (error) => {
  if (error) {
    console.error(error.message);
    process.exitCode = error.code || 1;
  }
});
