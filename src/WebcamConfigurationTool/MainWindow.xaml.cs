using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Navigation;
using Telerik.Windows.Controls;
using Telerik.Windows.MediaFoundation;

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
                WebCam.Initialize(videoDevices[index], videoFormats[0]);
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
    }
}