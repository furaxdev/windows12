using System.Windows;
using System.Windows.Media;
using System.Windows.Shapes;

namespace FuraxTaskbar;

/// <summary>
/// Icônes simplifiées construites avec des formes géométriques de base (cercles,
/// rectangles, lignes) plutôt que des chemins vectoriels copiés d'une police d'icônes ou
/// transcrits à la main depuis un SVG — impossible à vérifier visuellement dans cet
/// environnement de dev (pas de boot Windows), donc on reste volontairement sur des formes
/// simples et géométriquement prévisibles plutôt que de deviner des tracés compliqués.
/// Honnêteté : ce sont des placeholders schématiques, pas une reproduction pixel-perfect
/// des icônes Windows 11 natives.
/// </summary>
internal static class Icons
{
    private static readonly Brush DefaultStroke = new SolidColorBrush(Color.FromRgb(0xF2, 0xEE, 0xE8));

    internal static UIElement Search(double size = 18, Brush? stroke = null)
    {
        stroke ??= DefaultStroke;
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        var circle = new Ellipse
        {
            Width = size * 0.65,
            Height = size * 0.65,
            Stroke = stroke,
            StrokeThickness = 1.8,
        };
        System.Windows.Controls.Canvas.SetLeft(circle, 0);
        System.Windows.Controls.Canvas.SetTop(circle, 0);
        var handle = new Line
        {
            X1 = size * 0.62, Y1 = size * 0.62,
            X2 = size, Y2 = size,
            Stroke = stroke,
            StrokeThickness = 2,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
        };
        canvas.Children.Add(circle);
        canvas.Children.Add(handle);
        return canvas;
    }

    internal static UIElement StartLogo(double size = 20)
    {
        var grid = new System.Windows.Controls.Grid { Width = size, Height = size };
        grid.RowDefinitions.Add(new System.Windows.Controls.RowDefinition());
        grid.RowDefinitions.Add(new System.Windows.Controls.RowDefinition());
        grid.ColumnDefinitions.Add(new System.Windows.Controls.ColumnDefinition());
        grid.ColumnDefinitions.Add(new System.Windows.Controls.ColumnDefinition());

        var brush = new SolidColorBrush(Color.FromRgb(0x38, 0xBD, 0xF8));
        for (int r = 0; r < 2; r++)
        {
            for (int c = 0; c < 2; c++)
            {
                var rect = new Rectangle
                {
                    Fill = brush,
                    Margin = new Thickness(1.5),
                    RadiusX = 1, RadiusY = 1,
                };
                System.Windows.Controls.Grid.SetRow(rect, r);
                System.Windows.Controls.Grid.SetColumn(rect, c);
                grid.Children.Add(rect);
            }
        }
        return grid;
    }

    internal static UIElement TaskView(double size = 18, Brush? stroke = null)
    {
        stroke ??= new SolidColorBrush(Color.FromRgb(0xE5, 0xE7, 0xEB));
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        var back = new Rectangle
        {
            Width = size * 0.72, Height = size * 0.72,
            Stroke = stroke, StrokeThickness = 1.6, RadiusX = 2, RadiusY = 2,
        };
        System.Windows.Controls.Canvas.SetLeft(back, 0);
        System.Windows.Controls.Canvas.SetTop(back, 0);
        var front = new Rectangle
        {
            Width = size * 0.72, Height = size * 0.72,
            Stroke = stroke, StrokeThickness = 1.6, RadiusX = 2, RadiusY = 2,
            Fill = new SolidColorBrush(Color.FromRgb(0x0E, 0x0C, 0x14)),
        };
        System.Windows.Controls.Canvas.SetLeft(front, size * 0.28);
        System.Windows.Controls.Canvas.SetTop(front, size * 0.28);
        canvas.Children.Add(back);
        canvas.Children.Add(front);
        return canvas;
    }

    internal static UIElement Widgets(double size = 18)
    {
        var grid = new System.Windows.Controls.Grid { Width = size, Height = size };
        var brush = new SolidColorBrush(Color.FromRgb(0x93, 0xC5, 0xFD));
        var tall = new Rectangle { Fill = Brushes.Transparent, Stroke = brush, StrokeThickness = 1.6, RadiusX = 2, RadiusY = 2, Width = size * 0.4, Height = size, HorizontalAlignment = HorizontalAlignment.Left };
        var topRight = new Rectangle { Fill = Brushes.Transparent, Stroke = brush, StrokeThickness = 1.6, RadiusX = 2, RadiusY = 2, Width = size * 0.4, Height = size * 0.42, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top };
        var bottomRight = new Rectangle { Fill = Brushes.Transparent, Stroke = brush, StrokeThickness = 1.6, RadiusX = 2, RadiusY = 2, Width = size * 0.4, Height = size * 0.42, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Bottom };
        grid.Children.Add(tall);
        grid.Children.Add(topRight);
        grid.Children.Add(bottomRight);
        return grid;
    }

    internal static UIElement Folder(double size = 18)
    {
        var stroke = new SolidColorBrush(Color.FromRgb(0xFA, 0xCC, 0x15));
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        var figure = new PathFigure { StartPoint = new Point(0, size * 0.22) };
        figure.Segments.Add(new LineSegment(new Point(size * 0.38, size * 0.22), true));
        figure.Segments.Add(new LineSegment(new Point(size * 0.5, size * 0.38), true));
        figure.Segments.Add(new LineSegment(new Point(size, size * 0.38), true));
        figure.Segments.Add(new LineSegment(new Point(size, size * 0.85), true));
        figure.Segments.Add(new LineSegment(new Point(0, size * 0.85), true));
        figure.Segments.Add(new LineSegment(new Point(0, size * 0.22), true));
        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);
        var path = new System.Windows.Shapes.Path
        {
            Data = geometry,
            Stroke = stroke,
            StrokeThickness = 1.6,
            StrokeLineJoin = PenLineJoin.Round,
        };
        canvas.Children.Add(path);
        return canvas;
    }

    internal static UIElement Browser(double size = 18)
    {
        var stroke = new SolidColorBrush(Color.FromRgb(0x93, 0xC5, 0xFD));
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        var circle = new Ellipse { Width = size, Height = size, Stroke = stroke, StrokeThickness = 1.6 };
        var hLine = new Line { X1 = 0, Y1 = size / 2, X2 = size, Y2 = size / 2, Stroke = stroke, StrokeThickness = 1.2 };
        var vLine = new Line { X1 = size / 2, Y1 = 0, X2 = size / 2, Y2 = size, Stroke = stroke, StrokeThickness = 1.2 };
        canvas.Children.Add(circle);
        canvas.Children.Add(hLine);
        canvas.Children.Add(vLine);
        return canvas;
    }

    internal static UIElement Store(double size = 17)
    {
        var stroke = new SolidColorBrush(Color.FromRgb(0x38, 0xBD, 0xF8));
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        var body = new Rectangle
        {
            Width = size, Height = size * 0.62,
            Stroke = stroke, StrokeThickness = 1.6, RadiusX = 1.5, RadiusY = 1.5,
        };
        System.Windows.Controls.Canvas.SetTop(body, size * 0.38);
        var handle = new Ellipse
        {
            Width = size * 0.55, Height = size * 0.5,
            Stroke = stroke, StrokeThickness = 1.6,
        };
        System.Windows.Controls.Canvas.SetLeft(handle, size * 0.22);
        System.Windows.Controls.Canvas.SetTop(handle, 0);
        canvas.Children.Add(body);
        canvas.Children.Add(handle);
        return canvas;
    }

    internal static UIElement Sun(double size = 26)
    {
        return new Ellipse
        {
            Width = size * 0.5,
            Height = size * 0.5,
            Fill = new SolidColorBrush(Color.FromRgb(0xFB, 0xBF, 0x24)),
        };
    }

    internal static UIElement Keyboard(double size = 15)
    {
        var stroke = new SolidColorBrush(Color.FromRgb(0xF2, 0xEE, 0xE8));
        var grid = new System.Windows.Controls.Grid { Width = size, Height = size * 0.7 };
        var outline = new Rectangle { Stroke = stroke, StrokeThickness = 1.4, RadiusX = 2, RadiusY = 2 };
        grid.Children.Add(outline);
        var dots = new System.Windows.Controls.Primitives.UniformGrid { Rows = 1, Columns = 4, Margin = new Thickness(size * 0.15) };
        for (int i = 0; i < 4; i++)
        {
            dots.Children.Add(new Ellipse { Width = 1.6, Height = 1.6, Fill = stroke, Margin = new Thickness(1) });
        }
        grid.Children.Add(dots);
        return grid;
    }

    internal static UIElement Volume(double size = 15)
    {
        var stroke = new SolidColorBrush(Color.FromRgb(0xF2, 0xEE, 0xE8));
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        var figure = new PathFigure { StartPoint = new Point(0, size * 0.35) };
        figure.Segments.Add(new LineSegment(new Point(size * 0.3, size * 0.35), true));
        figure.Segments.Add(new LineSegment(new Point(size * 0.6, size * 0.1), true));
        figure.Segments.Add(new LineSegment(new Point(size * 0.6, size * 0.9), true));
        figure.Segments.Add(new LineSegment(new Point(size * 0.3, size * 0.65), true));
        figure.Segments.Add(new LineSegment(new Point(0, size * 0.65), true));
        figure.Segments.Add(new LineSegment(new Point(0, size * 0.35), true));
        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);
        var path = new System.Windows.Shapes.Path { Data = geometry, Stroke = stroke, StrokeThickness = 1.4, StrokeLineJoin = PenLineJoin.Round };
        canvas.Children.Add(path);
        var arc = new System.Windows.Shapes.Path
        {
            Stroke = stroke,
            StrokeThickness = 1.4,
            Data = new EllipseGeometry(new Point(size * 0.75, size * 0.5), size * 0.18, size * 0.3),
        };
        canvas.Children.Add(arc);
        return canvas;
    }

    internal static UIElement Wifi(double size = 15)
    {
        var stroke = new SolidColorBrush(Color.FromRgb(0xF2, 0xEE, 0xE8));
        var canvas = new System.Windows.Controls.Canvas { Width = size, Height = size };
        for (int i = 0; i < 3; i++)
        {
            double r = size * 0.5 * (1 - i * 0.28);
            var arc = new Ellipse
            {
                Width = r * 2,
                Height = r * 2,
                Stroke = stroke,
                StrokeThickness = 1.3,
            };
            System.Windows.Controls.Canvas.SetLeft(arc, size / 2 - r);
            System.Windows.Controls.Canvas.SetTop(arc, size - r * 1.1);
            var clip = new RectangleGeometry(new Rect(0, 0, size, size * 0.62));
            arc.Clip = clip;
            canvas.Children.Add(arc);
        }
        var dot = new Ellipse { Width = 2.4, Height = 2.4, Fill = stroke };
        System.Windows.Controls.Canvas.SetLeft(dot, size / 2 - 1.2);
        System.Windows.Controls.Canvas.SetTop(dot, size - 3);
        canvas.Children.Add(dot);
        return canvas;
    }
}
