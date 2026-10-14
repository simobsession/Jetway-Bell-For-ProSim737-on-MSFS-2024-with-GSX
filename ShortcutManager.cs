using System;using System.IO;using System.Collections.Generic;using System.Runtime.InteropServices;
public static class ShortcutManager {
 [DllImport("shell32.dll")]static extern int SHGetKnownFolderPath([MarshalAs(UnmanagedType.LPStruct)]Guid id,uint flags,IntPtr token,out IntPtr path);
 static string Known(Guid id,Environment.SpecialFolder fallback){IntPtr p=IntPtr.Zero;try{if(SHGetKnownFolderPath(id,0,IntPtr.Zero,out p)==0)return Marshal.PtrToStringUni(p);}catch{}finally{if(p!=IntPtr.Zero)Marshal.FreeCoTaskMem(p);}return Environment.GetFolderPath(fallback);}
 public static string Configure(string home,string exe,bool remove,string[] testFolders=null,Action<string,string,string> testCreate=null){
  var warnings=new List<string>();var folders=testFolders??new[]{Known(new Guid("B4BFCC3A-DB2C-424C-B029-7FE99A87C641"),Environment.SpecialFolder.DesktopDirectory),Known(new Guid("A77F5D77-2E2B-44C3-A6A2-ABA601054A51"),Environment.SpecialFolder.Programs),home};
  foreach(string folder in folders){try{if(String.IsNullOrWhiteSpace(folder))throw new IOException("Windows did not provide a shortcut folder.");string path=Path.Combine(folder,"Jetway Bell for ProSim GSX.lnk");if(remove){if(File.Exists(path))File.Delete(path);continue;}Directory.CreateDirectory(folder);if(testCreate==null)RemoveLegacy(folder,home);if(testCreate!=null)testCreate(path,exe,home);else Save(path,exe,home);}catch(Exception e){warnings.Add("Shortcut warning ("+folder+"): "+e.Message);}}
  return warnings.Count==0?"":"\r\n"+String.Join("\r\n",warnings)+"\r\nThe bell installation is complete. Open Sound Settings using a working shortcut or the installed settings executable.";
 }
 static void RemoveLegacy(string folder,string home){
  string old=Path.Combine(folder,"Jetway Bell Sound Settings.lnk");if(!File.Exists(old))return;
  object shell=null,link=null;try{shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));dynamic dynamicShell=shell;link=dynamicShell.CreateShortcut(old);dynamic shortcut=link;string target=(string)shortcut.TargetPath;
   if(String.Equals(Path.GetDirectoryName(target),Path.GetFullPath(home),StringComparison.OrdinalIgnoreCase))File.Delete(old);
  }catch{}finally{if(link!=null)Marshal.FinalReleaseComObject(link);if(shell!=null)Marshal.FinalReleaseComObject(shell);}
 }
 static void Save(string path,string exe,string home){object shell=null,link=null;try{shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));dynamic dynamicShell=shell;link=dynamicShell.CreateShortcut(path);dynamic shortcut=link;shortcut.TargetPath=exe;shortcut.Arguments="/settings";shortcut.WorkingDirectory=home;shortcut.IconLocation=exe+",0";shortcut.Description="Jetway bell sound settings for MSFS 2024, GSX and ProSim737";shortcut.Save();}finally{if(link!=null)Marshal.FinalReleaseComObject(link);if(shell!=null)Marshal.FinalReleaseComObject(shell);}}
}
