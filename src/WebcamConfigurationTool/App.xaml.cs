using System.Globalization;
using System.Threading;

namespace WebcamConfigurationTool
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App
    {
        public App()
        {
           InitializeComponent();
               
           var myCultureInfo = new CultureInfo("en");
           CultureInfo.DefaultThreadCurrentCulture = myCultureInfo;
           CultureInfo.DefaultThreadCurrentUICulture = myCultureInfo;

           Thread.CurrentThread.CurrentCulture = myCultureInfo;
           Thread.CurrentThread.CurrentUICulture = myCultureInfo;
        }
    }
}
