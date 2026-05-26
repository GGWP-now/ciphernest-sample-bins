Imports System
Imports System.Security.Cryptography
Imports System.Text
Imports System.Windows.Forms

Module Program
    <STAThread>
    Sub Main()
        Application.EnableVisualStyles()
        Application.SetCompatibleTextRenderingDefault(False)

        Dim form As New Form With {
            .Text = "VB.NET WinForms Victim",
            .ClientSize = New Drawing.Size(430, 170),
            .StartPosition = FormStartPosition.CenterScreen
        }
        Dim input As New TextBox With {.Text = "matrix-safe", .Left = 18, .Top = 18, .Width = 390}
        Dim output As New TextBox With {.Left = 18, .Top = 56, .Width = 390, .ReadOnly = True}
        Dim button As New Button With {.Text = "Hash", .Left = 333, .Top = 100, .Width = 75}

        AddHandler button.Click, Sub()
                                     output.Text = input.Text & " -> " & Digest(input.Text)
                                 End Sub

        form.Controls.AddRange({input, output, button})
        button.PerformClick()
        Application.Run(form)
    End Sub

    Private Function Digest(value As String) As String
        Dim bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value))
        Return Convert.ToHexString(bytes).Substring(0, 24).ToLowerInvariant()
    End Function
End Module
