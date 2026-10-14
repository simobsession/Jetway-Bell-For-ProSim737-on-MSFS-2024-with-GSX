using System;using System.IO;using System.Security.Cryptography;
public static class SetupPersistence {
 public static string Store(string source,string home){
  Directory.CreateDirectory(home);string hash=Digest(source);
  string target=Path.Combine(home,"Setup-1.2.4-"+hash.Substring(0,16)+".exe");
  if(String.Equals(Path.GetFullPath(source),Path.GetFullPath(target),StringComparison.OrdinalIgnoreCase))return target;
  if(File.Exists(target)){if(Digest(target)==hash)return target;throw new IOException("The stored settings application has unexpected contents: "+target);}
  string temporary=Path.Combine(home,"setup-copy-"+Guid.NewGuid().ToString("N")+".tmp");
  try{File.Copy(source,temporary,false);if(Digest(temporary)!=hash)throw new IOException("Settings application copy verification failed.");File.Move(temporary,target);return target;}
  catch(UnauthorizedAccessException e){throw new IOException("Windows denied permission to save the settings application in "+home+". Check the folder permissions and antivirus protection history on this computer. No security settings were changed.",e);}
  finally{if(File.Exists(temporary))File.Delete(temporary);}
 }
 static string Digest(string path){using(var sha=SHA256.Create())using(var stream=File.OpenRead(path))return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","");}
}
