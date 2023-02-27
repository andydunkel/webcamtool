using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Forms;
using System.Windows.Navigation;
using System.Windows.Shapes;
using Telerik.Windows.Controls;
using Path = System.IO.Path;

namespace WebcamConfigurationTool
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow
    {
        public MainWindow()
        {
            StyleManager.ApplicationTheme = new VisualStudio2019Theme();
            InitializeComponent();

            TextVersion.Text = Consts.Version;

            var webcams = RadWebCam.GetVideoCaptureDevices();

            var path = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
            TextExportPath.Text = Path.Combine(path, "video.mp4");
            WebCam.RecordingFilePath = TextExportPath.Text;

            foreach (var mediaFoundationDeviceInfo in webcams)
            {
                ComboWebcams.Items.Add(mediaFoundationDeviceInfo.FriendlyName);
            }
        }

        private void ComboWebcams_OnSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            var index = ComboWebcams.SelectedIndex;
            if (index != -1)
            {
                WebCam.Stop();
                var videoDevices = RadWebCam.GetVideoCaptureDevices();
                var videoFormats = RadWebCam.GetVideoFormats(videoDevices[index]);

                foreach (var videoFormat in videoFormats)
                {
                    var s = videoFormat.FrameSizeWidth.ToString() + "x" + videoFormat.FrameSizeHeight.ToString();
                    s += " " + videoFormat.FrameRate.ToString() + "fps - " + videoFormat.SubTypeDisplayName;
                    ComboRes.Items.Add(s);
                }

                WebCam.Initialize(videoDevices[index], videoFormats[0]);
                ComboRes.SelectedIndex = 0;
                if (CheckBoxShowWebcam.IsChecked == true)
                {
                    WebCam.Start();
                }
            }
        }

        private void ComboRes_SelectionChanged(object sender, EventArgs e)
        {
            var index = ComboRes.SelectedIndex;
            if (index != -1)
            {
                WebCam.Stop();
                var videoDevices = RadWebCam.GetVideoCaptureDevices();
                var videoFormats = RadWebCam.GetVideoFormats(videoDevices[ComboWebcams.SelectedIndex]);
                WebCam.Initialize(videoDevices[ComboWebcams.SelectedIndex], videoFormats[index]);
                if (CheckBoxShowWebcam.IsChecked == true)
                {
                    WebCam.Start();
                }
            }
        }

        private void Hyperlink_OnRequestNavigate(object sender, RequestNavigateEventArgs e)
        {
            Process.Start("https://ekiwi-blog.de");
        }

        private void CheckBoxShowWebcam_OnChecked(object sender, RoutedEventArgs e)
        {
            var index = ComboWebcams.SelectedIndex;
            if (index == -1) return;

            if (CheckBoxShowWebcam.IsChecked == true)
            {
                WebCam.Start();
            }
            else
            {
                WebCam.Stop();
            }
        }

        private void ButtonFolder_OnClick(object sender, RoutedEventArgs e)
        {
            var dlg = new FolderBrowserDialog();
            if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                TextExportPath.Text = Path.Combine(dlg.SelectedPath, "video.mp4");
                WebCam.RecordingFilePath = TextExportPath.Text;
            }   
        }
    }
}