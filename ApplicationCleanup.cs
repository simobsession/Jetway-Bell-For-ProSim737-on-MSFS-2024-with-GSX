using System;
using System.IO;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

// The short-lived copy allows Windows to release the installed executable before deletion.
// It runs only after an explicitly confirmed full uninstall; no shell or script is launched.
public static class ApplicationCleanup {
 static string Home {get{return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"GSXJetwayBellProSim");}}
 public static void Start(string home){
  ValidateRoot(home,Home);
  string token=Guid.NewGuid().ToString("N"),helper=Path.Combine(Path.GetTempPath(),"JetwayBell-Uninstall-"+token+".exe");
  string marker=Path.Combine(home,"cleanup-approved.txt");
  File.Copy(Assembly.GetExecutingAssembly().Location,helper,false);
  File.WriteAllText(marker,token);
  using(var current=Process.GetCurrentProcess()){
   try{var info=new ProcessStartInfo(helper,"/cleanup "+current.Id+" "+current.StartTime.ToUniversalTime().Ticks+" "+token){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,WorkingDirectory=Path.GetTempPath()};using(var child=Process.Start(info)){if(child==null)throw new IOException("The cleanup process could not start.");}}
   catch{File.Delete(marker);File.Delete(helper);throw;}
  }
 }
 public static bool TryRun(string[] args){
  if(args.Length==0||!args[0].Equals("/cleanup",StringComparison.OrdinalIgnoreCase))return false;
  try{
   int pid;long ticks;if(args.Length!=4||!Int32.TryParse(args[1],out pid)||!Int64.TryParse(args[2],out ticks)||!System.Text.RegularExpressions.Regex.IsMatch(args[3],"^[a-f0-9]{32}$"))throw new IOException("Invalid cleanup request.");
   string marker=Path.Combine(Home,"cleanup-approved.txt");ValidateRoot(Home,Home);
   if(!File.Exists(marker)||File.ReadAllText(marker)!=args[3])throw new IOException("No approved full-uninstall request was found.");
   try{using(var parent=Process.GetProcessById(pid)){if(parent.StartTime.ToUniversalTime().Ticks!=ticks)throw new IOException("Cleanup process identity changed.");if(!parent.WaitForExit(60000))throw new IOException("Close Jetway Bell before removing its files.");}}catch(ArgumentException){}
   Exception failure=null;for(int attempt=0;attempt<10;attempt++){try{RemoveTree(Home,Home);failure=null;break;}catch(Exception ex){failure=ex;Thread.Sleep(500);}}
   if(failure!=null)throw failure;
   // This executing temporary EXE remains in Windows Temp; it is not an installed app.
  }catch(Exception ex){string log=Path.Combine(Path.GetTempPath(),"JetwayBell-uninstall-error.log");File.WriteAllText(log,ex.ToString());MessageBox.Show("The bell integration was uninstalled, but some application files could not be removed.\n"+ex.Message+"\nDetails: "+log,"Jetway Bell — cleanup incomplete");}
  return true;
 }
 static void ValidateRoot(string root,string expected){
  string actual=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar),allowed=Path.GetFullPath(expected).TrimEnd(Path.DirectorySeparatorChar);
  if(!String.Equals(actual,allowed,StringComparison.OrdinalIgnoreCase)||String.Equals(actual,Path.GetPathRoot(actual).TrimEnd(Path.DirectorySeparatorChar),StringComparison.OrdinalIgnoreCase))throw new IOException("Refusing cleanup outside the application folder.");
  if(Directory.Exists(actual)&&(File.GetAttributes(actual)&FileAttributes.ReparsePoint)!=0)throw new IOException("The application folder is a link; automatic full removal was stopped.");
 }
 public static void RemoveTree(string root,string expected){ValidateRoot(root,expected);if(Directory.Exists(root))DeleteContents(root);}
 static void DeleteContents(string directory){
  foreach(string file in Directory.GetFiles(directory))File.Delete(file);
  foreach(string child in Directory.GetDirectories(directory)){if((File.GetAttributes(child)&FileAttributes.ReparsePoint)!=0)Directory.Delete(child,false);else DeleteContents(child);}
  Directory.Delete(directory,false);
 }
}
