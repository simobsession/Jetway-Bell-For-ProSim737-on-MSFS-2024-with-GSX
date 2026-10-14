using System;
using System.IO;
using System.Linq;
using System.Xml.Linq;
using System.Windows.Forms;
using System.Media;
class SoundSettingsForm:Form {
 string home;XDocument doc;ListBox airports=new ListBox();TextBox icao=new TextBox();Label defaultLabel=new Label();string defaultFile="";SoundPlayer player;Button preview=new Button(),remove=new Button();bool previewing;int previewGeneration;System.Threading.CancellationTokenSource previewCancel;
 public bool Saved=false;
 public Func<System.Threading.Tasks.Task<bool>> ApplySettings;
 public Func<System.Threading.Tasks.Task<bool>> UninstallApplication;
 string Data {get{return Path.Combine(home,"UserData");}}
 string SettingsPath {get{return Path.Combine(Data,"settings.xml");}}
 public SoundSettingsForm(string root){home=root;Directory.CreateDirectory(Path.Combine(Data,"Sounds"));doc=File.Exists(SettingsPath)?XDocument.Load(SettingsPath):new XDocument(new XElement("SoundSettings"));
  Text="Jetway Bell for ProSim GSX v"+AppVersion.Text+" — Sound Settings";Width=690;Height=470;StartPosition=FormStartPosition.CenterParent;Icon=System.Drawing.Icon.ExtractAssociatedIcon(System.Reflection.Assembly.GetExecutingAssembly().Location);
  defaultFile=(string)doc.Root.Element("Default")==null?"":(string)doc.Root.Element("Default").Attribute("file")??"";
  defaultLabel.SetBounds(18,20,630,32);var choose=new Button{Text="Choose default WAV",Left=18,Top=55,Width=160};var reset=new Button{Text="Use bundled default",Left=190,Top=55,Width=160};
  airports.SetBounds(18,110,630,180);airports.DrawMode=DrawMode.OwnerDrawFixed;
  airports.DrawItem+=(s,e)=>{if(e.Index<0)return;e.DrawBackground();var entry=(SoundEntry)airports.Items[e.Index];bool selected=(e.State&DrawItemState.Selected)!=0;var color=selected?System.Drawing.SystemColors.HighlightText:entry.Bundled?System.Drawing.SystemColors.GrayText:e.ForeColor;TextRenderer.DrawText(e.Graphics,entry.ToString(),e.Font,e.Bounds,color,TextFormatFlags.Left|TextFormatFlags.VerticalCenter);e.DrawFocusRectangle();};
  airports.SelectedIndexChanged+=(s,e)=>{StopPreview();var entry=airports.SelectedItem as SoundEntry;remove.Enabled=entry!=null&&!String.IsNullOrEmpty(entry.Code);};icao.SetBounds(18,305,90,25);icao.MaxLength=4;icao.CharacterCasing=CharacterCasing.Upper;
  var add=new Button{Text="Assign airport WAV",Left=120,Top=302,Width=170};remove.Text="Remove override";remove.SetBounds(300,302,150,23);preview.Text="Preview selected";preview.SetBounds(465,302,180,23);
  var note=new Label{Text="Enter a 4-character airport ICAO. Airports without an override use the default.\nWAV: 16-bit PCM, mono/stereo, 0.1–60 seconds. Close MSFS before saving.",Left=18,Top=345,Width=630,Height=42};
  var save=new Button{Text="Save and apply",Left=355,Top=395,Width=145};var cancel=new Button{Text="Exit",Left=515,Top=395,Width=130};
  var uninstall=new Button{Text="Uninstall...",Left=18,Top=395,Width=130};
  uninstall.Click+=async(s,e)=>{if(UninstallApplication==null)return;StopPreview();try{Enabled=false;UseWaitCursor=true;if(await UninstallApplication())Close();}catch(Exception ex){MessageBox.Show(ex.Message,"Uninstall");}finally{Enabled=true;UseWaitCursor=false;}};
  Controls.Add(uninstall);
  Controls.AddRange(new Control[]{defaultLabel,choose,reset,airports,icao,add,remove,preview,note,save,cancel});
  choose.Click+=(s,e)=>{var file=Pick();if(file!=null){defaultFile=file;RefreshList();}};reset.Click+=(s,e)=>{defaultFile="";RefreshList();};
  add.Click+=(s,e)=>{string code=icao.Text.Trim().ToUpperInvariant();if(!System.Text.RegularExpressions.Regex.IsMatch(code,"^[A-Z0-9]{4}$")){MessageBox.Show("Enter a four-character ICAO such as KDAL or EGLL.");return;}var file=Pick();if(file==null)return;var old=doc.Root.Elements("Airport").FirstOrDefault(x=>(string)x.Attribute("icao")==code);if(old!=null)old.Remove();doc.Root.Add(new XElement("Airport",new XAttribute("icao",code),new XAttribute("file",file)));RefreshList();};
  remove.Click+=(s,e)=>{var entry=airports.SelectedItem as SoundEntry;if(entry==null||String.IsNullOrEmpty(entry.Code))return;doc.Root.Elements("Airport").First(x=>(string)x.Attribute("icao")==entry.Code).Remove();RefreshList();};
  preview.Click+=async(s,e)=>{if(previewing){StopPreview();return;}await PreviewSelected();};
  save.Click+=async(s,e)=>{StopPreview();if(System.Diagnostics.Process.GetProcessesByName("FlightSimulator2024").Length>0||System.Diagnostics.Process.GetProcessesByName("FlightSimulator").Length>0){MessageBox.Show("Close MSFS completely first.");return;}doc.Root.Elements("Default").Remove();doc.Root.AddFirst(new XElement("Default",new XAttribute("file",defaultFile)));string previous=File.Exists(SettingsPath)?File.ReadAllText(SettingsPath):null;
   try{doc.Save(SettingsPath);if(ApplySettings!=null){Enabled=false;UseWaitCursor=true;if(!await ApplySettings()){if(previous==null)File.Delete(SettingsPath);else File.WriteAllText(SettingsPath,previous);return;}}Saved=true;Close();}
   catch(Exception ex){if(previous==null){if(File.Exists(SettingsPath))File.Delete(SettingsPath);}else File.WriteAllText(SettingsPath,previous);MessageBox.Show(ex.Message,"Sound Settings");}
   finally{Enabled=true;UseWaitCursor=false;}};cancel.Click+=(s,e)=>Close();FormClosed+=(s,e)=>StopPreview();RefreshList();
 }
 sealed class SoundEntry {
  public string Code,File;public bool Bundled;
  public override string ToString(){return Bundled?"Default bell (bundled)":String.IsNullOrEmpty(Code)?"Default bell (custom recording)":Code+" — custom recording";}
 }
 void RefreshList(){
  StopPreview();var selected=airports.SelectedItem as SoundEntry;string selectedKey=selected==null?null:selected.Bundled?"bundled":selected.Code??"custom-default";
  defaultLabel.Text=String.IsNullOrEmpty(defaultFile)?"Default: bundled jetway bell":"Default: custom recording";
  airports.Items.Clear();airports.Items.Add(new SoundEntry{Bundled=true});
  if(!String.IsNullOrEmpty(defaultFile))airports.Items.Add(new SoundEntry{File=defaultFile});
  foreach(var a in doc.Root.Elements("Airport").OrderBy(x=>(string)x.Attribute("icao")))airports.Items.Add(new SoundEntry{Code=(string)a.Attribute("icao"),File=(string)a.Attribute("file")});
  int index=String.IsNullOrEmpty(defaultFile)?0:1;
  for(int i=0;i<airports.Items.Count;i++){var entry=(SoundEntry)airports.Items[i];if((entry.Bundled?"bundled":entry.Code??"custom-default")==selectedKey){index=i;break;}}
  airports.SelectedIndex=index;
 }
 void StopPreview(){
  previewGeneration++;if(previewCancel!=null){previewCancel.Cancel();previewCancel.Dispose();previewCancel=null;}previewing=false;preview.Text="Preview selected";
  if(player!=null){player.Stop();player.Dispose();player=null;}
 }
 async System.Threading.Tasks.Task PreviewSelected(){
  var entry=airports.SelectedItem as SoundEntry;if(entry==null)return;
  string path=entry.Bundled?Path.Combine(home,@"gsx-jetway-bell\SimObjects\Airplanes\prosim-b738-2026\sound\GSX_Jetway_Bell.wav"):Path.Combine(Data,entry.File);
  int generation=++previewGeneration;
  try{
   if(!File.Exists(path))throw new FileNotFoundException("The selected recording was not found. Install the application first to preview the bundled default.");
   int rate;double duration=BellAudio.Read(path,out rate).Length/(double)rate;
   var current=new SoundPlayer(path);player=current;current.Load();previewCancel=new System.Threading.CancellationTokenSource();var cancellation=previewCancel.Token;
   current.Play();previewing=true;preview.Text="Stop";
   await System.Threading.Tasks.Task.Delay((int)Math.Ceiling(duration*1000),cancellation);
  }catch(Exception ex){if(generation==previewGeneration&&!IsDisposed)MessageBox.Show(ex.Message,"Sound preview");}
  finally{if(generation==previewGeneration&&!IsDisposed)StopPreview();}
 }
 string Pick(){using(var picker=new OpenFileDialog{Filter="PCM WAV files (*.wav)|*.wav",Title="Choose a bell recording"}){if(picker.ShowDialog()!=DialogResult.OK)return null;try{BellAudio.Validate(picker.FileName);string file="Sounds/"+Guid.NewGuid().ToString("N")+".wav";File.Copy(picker.FileName,Path.Combine(Data,file));return file;}catch(Exception e){MessageBox.Show(e.Message);return null;}}}
}
