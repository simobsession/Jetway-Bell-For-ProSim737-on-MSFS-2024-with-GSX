using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;
class SetupForm : Form {
 TextBox folder=new TextBox(),log=new TextBox(); Button install=new Button(),uninstall=new Button(),browse=new Button(),settings=new Button();
 string home=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"GSXJetwayBellProSim");
 public SetupForm(bool removing,bool soundSettings){
  Text="Jetway Bell for ProSim737 — Setup";Width=760;Height=490;StartPosition=FormStartPosition.CenterScreen;
  var title=new Label{Text="Jetway Bell For ProSim737 on MSFS 2024 with GSX",Left=18,Top=18,Width=700,Height=25};
  var help=new Label{Text="Close MSFS first. Choose the Community folder containing prosim-b738.",Left=18,Top=50,Width=700};
  folder.SetBounds(18,82,610,25);browse.Text="Browse...";browse.SetBounds(636,80,95,28);
  install.Text="Install / Update";install.SetBounds(18,120,150,32);uninstall.Text="Uninstall";uninstall.SetBounds(180,120,120,32);
  log.Multiline=true;log.ReadOnly=true;log.ScrollBars=ScrollBars.Vertical;log.SetBounds(18,168,713,270);
  settings.Text="Sound Settings";settings.SetBounds(320,120,150,32);
  Controls.AddRange(new Control[]{title,help,folder,browse,install,uninstall,settings,log});
  folder.Text=FindCommunity();browse.Click+=(s,e)=>{using(var d=new FolderBrowserDialog()){d.Description="Select MSFS 2024 Community folder";d.SelectedPath=folder.Text;if(d.ShowDialog()==DialogResult.OK)folder.Text=d.SelectedPath;}};
  install.Click+=async(s,e)=>await Run(false);uninstall.Click+=async(s,e)=>await Run(true);
  settings.Click+=async(s,e)=>await EditSounds();
  if(soundSettings)Shown+=async(s,e)=>await EditSounds();
  if(removing)Shown+=async(s,e)=>await Run(true);
 }
 async Task EditSounds(){
  string config=Path.Combine(home,@"UserData\settings.xml");string old=File.Exists(config)?File.ReadAllText(config):null;
  try{using(var dialog=new SoundSettingsForm(home)){if(dialog.ShowDialog(this)==DialogResult.OK){}if(dialog.Saved){bool applied=await Run(false);if(!applied){if(old==null)File.Delete(config);else File.WriteAllText(config,old);}}}}catch(Exception e){MessageBox.Show(e.Message,"Sound Settings");}
 }
 string FindCommunity(){
  using(var k=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\GSXJetwayBellProSim")){if(k!=null){var saved=k.GetValue("CommunityRoot") as string;if(!String.IsNullOrEmpty(saved))return saved;}}
  string app=Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),local=Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
  foreach(string cfg in new[]{Path.Combine(app,@"Microsoft Flight Simulator 2024\UserCfg.opt"),Path.Combine(local,@"Packages\Microsoft.Limitless_8wekyb3d8bbwe\LocalCache\UserCfg.opt")})if(File.Exists(cfg)){
   var match=Regex.Match(File.ReadAllText(cfg),"(?m)^InstalledPackagesPath\\s+\"([^\"]+)\"");if(match.Success){string p=Path.Combine(match.Groups[1].Value,"Community");if(Directory.Exists(Path.Combine(p,"prosim-b738")))return p;}}
  return Path.Combine(app,@"Microsoft Flight Simulator 2024\Packages\Community");
 }
 async Task<bool> Run(bool remove){
  if(Process.GetProcessesByName("FlightSimulator2024").Length>0 || Process.GetProcessesByName("FlightSimulator").Length>0){MessageBox.Show("Close MSFS completely first.");return false;}
  string selected=folder.Text.Trim().Trim('"');if(!Directory.Exists(selected)){MessageBox.Show("Choose an existing Community folder.");return false;}
  if(remove && MessageBox.Show("Remove the jetway bell and its aircraft integration? Other aircraft sounds are preserved.","Uninstall",MessageBoxButtons.YesNo)!=DialogResult.Yes)return false;
  settings.Enabled=install.Enabled=uninstall.Enabled=browse.Enabled=folder.Enabled=false;log.Text="Working...\r\n";
  try{
   string output=await Task.Run(()=>{
    Directory.CreateDirectory(home);
    using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))using(var zip=new ZipArchive(stream,ZipArchiveMode.Read))foreach(var entry in zip.Entries){
     string target=Path.GetFullPath(Path.Combine(home,entry.FullName));if(!target.StartsWith(home+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception("Invalid package path.");
     if(String.IsNullOrEmpty(entry.Name)){Directory.CreateDirectory(target);continue;}Directory.CreateDirectory(Path.GetDirectoryName(target));using(var input=entry.Open())using(var file=File.Create(target))input.CopyTo(file);
    }
    string targetExe=SetupPersistence.Store(Assembly.GetExecutingAssembly().Location,home);
    string result=NativeInstaller.Run(home,selected,remove,true,targetExe);
    File.WriteAllText(Path.Combine(home,"setup-last.log"),result);return result;
   });log.Text=output;MessageBox.Show(remove?"Uninstall completed. Backups and setup files are retained for recovery.":"Installation completed. Start MSFS to test the bell.","Jetway Bell");return true;
  }catch(Exception e){log.Text=e.Message;MessageBox.Show("Setup could not complete. Details are shown in the window.","Jetway Bell");return false;}
  finally{settings.Enabled=install.Enabled=uninstall.Enabled=browse.Enabled=folder.Enabled=true;}
 }
 [STAThread]static void Main(string[] args){Application.EnableVisualStyles();Application.Run(new SetupForm(Array.Exists(args,a=>a.Equals("/uninstall",StringComparison.OrdinalIgnoreCase)),Array.Exists(args,a=>a.Equals("/settings",StringComparison.OrdinalIgnoreCase))));}
}
