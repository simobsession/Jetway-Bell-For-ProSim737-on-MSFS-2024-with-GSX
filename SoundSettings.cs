using System;
using System.IO;
using System.Linq;
using System.Xml.Linq;
using System.Windows.Forms;
using System.Media;
class SoundSettingsForm:Form {
 string home;XDocument doc;ListBox airports=new ListBox();TextBox icao=new TextBox();Label defaultLabel=new Label();string defaultFile="";SoundPlayer player;
 public bool Saved=false;
 public Func<System.Threading.Tasks.Task<bool>> ApplySettings;
 public Func<System.Threading.Tasks.Task<bool>> UninstallApplication;
 string Data {get{return Path.Combine(home,"UserData");}}
 string SettingsPath {get{return Path.Combine(Data,"settings.xml");}}
 public SoundSettingsForm(string root){home=root;Directory.CreateDirectory(Path.Combine(Data,"Sounds"));doc=File.Exists(SettingsPath)?XDocument.Load(SettingsPath):new XDocument(new XElement("SoundSettings"));
  Text="Jetway Bell for ProSim GSX v"+AppVersion.Text+" — Sound Settings";Width=690;Height=470;StartPosition=FormStartPosition.CenterParent;Icon=System.Drawing.Icon.ExtractAssociatedIcon(System.Reflection.Assembly.GetExecutingAssembly().Location);
  defaultFile=(string)doc.Root.Element("Default")==null?"":(string)doc.Root.Element("Default").Attribute("file")??"";
  defaultLabel.SetBounds(18,20,630,32);var choose=new Button{Text="Choose default WAV",Left=18,Top=55,Width=160};var reset=new Button{Text="Use bundled default",Left=190,Top=55,Width=160};
  airports.SetBounds(18,110,630,180);icao.SetBounds(18,305,90,25);icao.MaxLength=4;icao.CharacterCasing=CharacterCasing.Upper;
  var add=new Button{Text="Assign airport WAV",Left=120,Top=302,Width=170};var remove=new Button{Text="Remove override",Left=300,Top=302,Width=150};var preview=new Button{Text="Preview selected",Left=465,Top=302,Width=180};
  var note=new Label{Text="Enter a 4-character airport ICAO. Airports without an override use the default.\nWAV: 16-bit PCM, mono/stereo, 0.1–60 seconds. Close MSFS before saving.",Left=18,Top=345,Width=630,Height=42};
  var save=new Button{Text="Save and apply",Left=355,Top=395,Width=145};var cancel=new Button{Text="Cancel",Left=515,Top=395,Width=130};
  var uninstall=new Button{Text="Uninstall...",Left=18,Top=395,Width=130};
  uninstall.Click+=async(s,e)=>{if(UninstallApplication==null)return;if(player!=null)player.Stop();try{Enabled=false;UseWaitCursor=true;if(await UninstallApplication())Close();}catch(Exception ex){MessageBox.Show(ex.Message,"Uninstall");}finally{Enabled=true;UseWaitCursor=false;}};
  Controls.Add(uninstall);
  Controls.AddRange(new Control[]{defaultLabel,choose,reset,airports,icao,add,remove,preview,note,save,cancel});
  choose.Click+=(s,e)=>{var file=Pick();if(file!=null){defaultFile=file;RefreshList();}};reset.Click+=(s,e)=>{defaultFile="";RefreshList();};
  add.Click+=(s,e)=>{string code=icao.Text.Trim().ToUpperInvariant();if(!System.Text.RegularExpressions.Regex.IsMatch(code,"^[A-Z0-9]{4}$")){MessageBox.Show("Enter a four-character ICAO such as KDAL or EGLL.");return;}var file=Pick();if(file==null)return;var old=doc.Root.Elements("Airport").FirstOrDefault(x=>(string)x.Attribute("icao")==code);if(old!=null)old.Remove();doc.Root.Add(new XElement("Airport",new XAttribute("icao",code),new XAttribute("file",file)));RefreshList();};
  remove.Click+=(s,e)=>{if(airports.SelectedItem==null)return;string code=airports.SelectedItem.ToString().Substring(0,4);doc.Root.Elements("Airport").First(x=>(string)x.Attribute("icao")==code).Remove();RefreshList();};
  preview.Click+=(s,e)=>{try{string file=defaultFile;if(airports.SelectedItem!=null){string code=airports.SelectedItem.ToString().Substring(0,4);file=(string)doc.Root.Elements("Airport").First(x=>(string)x.Attribute("icao")==code).Attribute("file");}string path=String.IsNullOrEmpty(file)?Path.Combine(home,@"gsx-jetway-bell\SimObjects\Airplanes\prosim-b738-2026\sound\GSX_Jetway_Bell.wav"):Path.Combine(Data,file);if(!File.Exists(path)){MessageBox.Show("Install first to preview the bundled default.");return;}if(player!=null)player.Stop();player=new SoundPlayer(path);player.Play();}catch(Exception ex){MessageBox.Show(ex.Message);}};
  save.Click+=async(s,e)=>{if(System.Diagnostics.Process.GetProcessesByName("FlightSimulator2024").Length>0||System.Diagnostics.Process.GetProcessesByName("FlightSimulator").Length>0){MessageBox.Show("Close MSFS completely first.");return;}doc.Root.Elements("Default").Remove();doc.Root.AddFirst(new XElement("Default",new XAttribute("file",defaultFile)));string previous=File.Exists(SettingsPath)?File.ReadAllText(SettingsPath):null;
   try{doc.Save(SettingsPath);if(ApplySettings!=null){Enabled=false;UseWaitCursor=true;if(!await ApplySettings()){if(previous==null)File.Delete(SettingsPath);else File.WriteAllText(SettingsPath,previous);return;}}Saved=true;Close();}
   catch(Exception ex){if(previous==null){if(File.Exists(SettingsPath))File.Delete(SettingsPath);}else File.WriteAllText(SettingsPath,previous);MessageBox.Show(ex.Message,"Sound Settings");}
   finally{Enabled=true;UseWaitCursor=false;}};cancel.Click+=(s,e)=>Close();FormClosed+=(s,e)=>{if(player!=null){player.Stop();player.Dispose();}};RefreshList();
 }
 void RefreshList(){defaultLabel.Text=String.IsNullOrEmpty(defaultFile)?"Default: bundled jetway bell":"Default: custom recording";airports.Items.Clear();foreach(var a in doc.Root.Elements("Airport").OrderBy(x=>(string)x.Attribute("icao")))airports.Items.Add((string)a.Attribute("icao")+" — custom recording");}
 string Pick(){using(var picker=new OpenFileDialog{Filter="PCM WAV files (*.wav)|*.wav",Title="Choose a bell recording"}){if(picker.ShowDialog()!=DialogResult.OK)return null;try{BellAudio.Validate(picker.FileName);string file="Sounds/"+Guid.NewGuid().ToString("N")+".wav";File.Copy(picker.FileName,Path.Combine(Data,file));return file;}catch(Exception e){MessageBox.Show(e.Message);return null;}}}
}
