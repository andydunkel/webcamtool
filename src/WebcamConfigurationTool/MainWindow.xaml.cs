using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
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
                WebCam.Start();
                
            }
        }
    }
}