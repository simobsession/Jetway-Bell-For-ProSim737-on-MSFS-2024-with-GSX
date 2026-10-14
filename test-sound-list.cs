using System;using System.IO;using System.Linq;using System.Reflection;using System.Windows.Forms;
class SoundListTests{
 static void Check(bool value,string message){if(!value)throw new Exception(message);}
 [STAThread]static void Main(string[] args){var assembly=Assembly.LoadFrom(args[0]);string root=Path.Combine(Path.GetTempPath(),"BellSoundListTests-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(Path.Combine(root,"UserData"));File.WriteAllText(Path.Combine(root,"UserData","settings.xml"),"<SoundSettings><Default file=\"Sounds/default.wav\"/><Airport icao=\"EDDF\" file=\"Sounds/eddf.wav\"/></SoundSettings>");
 using(var form=(Form)Activator.CreateInstance(assembly.GetType("SoundSettingsForm"),new object[]{root})){
  var list=form.Controls.OfType<ListBox>().Single();var buttons=form.Controls.OfType<Button>().ToArray();var preview=buttons.Single(b=>b.Text=="Preview selected");var remove=buttons.Single(b=>b.Text=="Remove override");Check(list.Items.Count==3,"Bundled, custom default and airport must all be listed");Check(list.DrawMode==DrawMode.OwnerDrawFixed,"Default row must support gray rendering");Check(list.Items[0].ToString().Contains("bundled"),"Bundled default missing");list.SelectedIndex=0;Check(!remove.Enabled,"Bundled default must not be removable");list.SelectedIndex=1;Check(!remove.Enabled,"Custom default must not be treated as an airport");list.SelectedIndex=2;Check(remove.Enabled,"Airport override should be removable");Check(buttons.Any(b=>b.Text=="Exit")&&!buttons.Any(b=>b.Text=="Cancel"),"Exit label missing");form.Show();Application.DoEvents();
  form.GetType().GetField("previewing",BindingFlags.NonPublic|BindingFlags.Instance).SetValue(form,true);preview.Text="Stop";preview.PerformClick();Check(preview.Text=="Preview selected","Stop must reset the preview button");
  remove.PerformClick();Check(list.Items.Count==2,"Only airport override should be removed");Check(list.Items[0].ToString().Contains("bundled"),"Bundled default was removed");buttons.Single(b=>b.Text=="Exit").PerformClick();Check(File.ReadAllText(Path.Combine(root,"UserData","settings.xml")).Contains("EDDF"),"Exit must not save pending edits");
 }
 Console.WriteLine("PASS: bundled/custom/airport rows, protected defaults, airport removal, Preview/Stop reset, Exit without saving.");
 }
}
