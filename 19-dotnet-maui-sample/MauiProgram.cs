using Microsoft.Extensions.Logging;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Input;

namespace MauiNoteApp;

// ── Model ──────────────────────────────────────────────────────────
public class Note : INotifyPropertyChanged
{
    private string _title = "";
    private string _content = "";
    private DateTime _created = DateTime.Now;

    public string Title { get => _title; set { _title = value; OnChanged(); } }
    public string Content { get => _content; set { _content = value; OnChanged(); } }
    public DateTime CreatedDate { get => _created; set { _created = value; OnChanged(); } }

    public event PropertyChangedEventHandler? PropertyChanged;
    void OnChanged([CallerMemberName] string n = "") =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
}

// ── ViewModel ───────────────────────────────────────────────────────
public class MainViewModel : INotifyPropertyChanged
{
    string _title = "", _text = "";
    public string NoteTitle { get => _title; set { _title = value; OnChanged(); } }
    public string NoteContent { get => _text; set { _text = value; OnChanged(); } }
    public ObservableCollection<Note> Notes { get; } = new();

    public ICommand AddCommand { get; }
    public ICommand DeleteCommand { get; }

    public MainViewModel()
    {
        AddCommand = new Command(() => {
            if (!string.IsNullOrWhiteSpace(NoteTitle))
            {
                Notes.Add(new Note { Title = NoteTitle, Content = NoteContent });
                NoteTitle = NoteContent = "";
            }
        });
        DeleteCommand = new Command<Note>(n => Notes.Remove(n));
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    void OnChanged([CallerMemberName] string n = "") =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
}

// ── MAUI Application (cross-platform app definition) ─────────────────
public class MauiNoteApp : Application
{
    protected override Window CreateWindow(IActivationState? activationState)
    {
        return new Window(new NavigationPage(new MainPage())) { Title = "MAUI Note App" };
    }
}


// ── MainPage (C#-only UI) ───────────────────────────────────────────
public class MainPage : ContentPage
{
    readonly MainViewModel _vm = new();

    public MainPage()
    {
        Title = "Notes";
        BindingContext = _vm;

        var titleEntry = new Entry { Placeholder = "Note title" };
        titleEntry.SetBinding(Entry.TextProperty, nameof(_vm.NoteTitle));

        var contentEditor = new Editor { Placeholder = "Note content", HeightRequest = 100, AutoSize = EditorAutoSizeOption.TextChanges };
        contentEditor.SetBinding(Editor.TextProperty, nameof(_vm.NoteContent));

        var addBtn = new Button { Text = "Add Note" };
        addBtn.SetBinding(Button.CommandProperty, nameof(_vm.AddCommand));

        var list = new CollectionView { SelectionMode = SelectionMode.Single };
        list.SetBinding(CollectionView.ItemsSourceProperty, nameof(_vm.Notes));
        list.ItemTemplate = new DataTemplate(() =>
        {
            var titleLabel = new Label { FontSize = 18, FontAttributes = FontAttributes.Bold };
            titleLabel.SetBinding(Label.TextProperty, nameof(Note.Title));

            var dateLabel = new Label { FontSize = 12, TextColor = Colors.Gray };
            dateLabel.SetBinding(Label.TextProperty, new Binding("CreatedDate", stringFormat: "{0:g}"));

            var stack = new VerticalStackLayout { Spacing = 4, Children = { titleLabel, dateLabel } };

            var swipe = new SwipeView();
            var delItem = new SwipeItem { Text = "Delete", BackgroundColor = Colors.Red };
            delItem.SetBinding(SwipeItem.CommandProperty, new Binding(
                source: _vm, path: nameof(_vm.DeleteCommand)));
            delItem.SetBinding(SwipeItem.CommandParameterProperty, new Binding("."));
            swipe.RightItems = new SwipeItems { delItem };
            swipe.Content = stack;

            var tap = new TapGestureRecognizer();
            tap.Tapped += (s, e) =>
            {
                if (swipe.BindingContext is Note note)
                    Shell.Current?.Navigation.PushAsync(new NoteDetailPage(note));
            };
            swipe.GestureRecognizers.Add(tap);

            return swipe;
        });

        var grid = new Grid
        {
            RowDefinitions =
            {
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Star)
            },
            Padding = 16,
            RowSpacing = 8
        };
        Grid.SetRow(titleEntry, 0);
        Grid.SetRow(contentEditor, 1);
        Grid.SetRow(addBtn, 2);
        Grid.SetRow(list, 3);
        grid.Children.Add(titleEntry);
        grid.Children.Add(contentEditor);
        grid.Children.Add(addBtn);
        grid.Children.Add(list);

        Content = grid;
    }
}

// ── NoteDetailPage (C#-only UI) ─────────────────────────────────────
public class NoteDetailPage : ContentPage
{
    public NoteDetailPage(Note note)
    {
        BindingContext = note;
        Title = note.Title;

        var titleLabel = new Label { FontSize = 24, FontAttributes = FontAttributes.Bold };
        titleLabel.SetBinding(Label.TextProperty, nameof(Note.Title));

        var dateLabel = new Label { FontSize = 14, TextColor = Colors.Gray };
        dateLabel.SetBinding(Label.TextProperty, new Binding("CreatedDate", stringFormat: "{0:MMMM dd, yyyy h:mm tt}"));

        var sep = new BoxView { HeightRequest = 1, Color = Colors.LightGray, HorizontalOptions = LayoutOptions.Fill };

        var contentLabel = new Label { FontSize = 16 };
        contentLabel.SetBinding(Label.TextProperty, nameof(Note.Content));

        Content = new ScrollView
        {
            Padding = 16,
            Content = new VerticalStackLayout { Spacing = 12, Children = { titleLabel, dateLabel, sep, contentLabel } }
        };
    }
}
// Entry point is auto-generated by the WinAppSDK XAML compiler from
// Platforms/Windows/App.xaml (the App.g.cs emits Main + Application.Start wiring).

public partial class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder.UseMauiApp<MauiNoteApp>();
#if DEBUG
        builder.Logging.AddDebug();
#endif
        return builder.Build();
    }
}