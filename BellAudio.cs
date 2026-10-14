using System;
using System.IO;
public static class BellAudio {
 public static double[] Read(string path,out int rate){
  using(var r=new BinaryReader(File.OpenRead(path))){
   if(new string(r.ReadChars(4))!="RIFF")throw new Exception("Choose a PCM WAV recording.");r.ReadUInt32();if(new string(r.ReadChars(4))!="WAVE")throw new Exception("Invalid WAV file.");
   int format=0,channels=0,bits=0;rate=0;byte[] data=null;
   while(r.BaseStream.Position+8<=r.BaseStream.Length){string tag=new string(r.ReadChars(4));uint len=r.ReadUInt32();long next=r.BaseStream.Position+len+(len%2);if(next>r.BaseStream.Length)throw new Exception("Truncated WAV.");
    if(tag=="fmt "){if(len<16)throw new Exception("Invalid WAV format.");format=r.ReadUInt16();channels=r.ReadUInt16();rate=r.ReadInt32();r.ReadInt32();r.ReadUInt16();bits=r.ReadUInt16();}
    if(tag=="data"){if(len>24000000)throw new Exception("Recording is too large (maximum 60 seconds).");data=r.ReadBytes((int)len);}r.BaseStream.Position=next;
   }
   if(format!=1||bits!=16||(channels!=1&&channels!=2)||rate<8000||rate>192000||data==null||data.Length%(2*channels)!=0)throw new Exception("Use uncompressed 16-bit PCM WAV, mono or stereo, 8–192 kHz.");
   int count=data.Length/(2*channels);if(count<rate/10||count>rate*60)throw new Exception("Choose a recording between 0.1 and 60 seconds.");
   var samples=new double[count];double peak=0;for(int i=0;i<count;i++){double v=0;for(int c=0;c<channels;c++)v+=BitConverter.ToInt16(data,(i*channels+c)*2);samples[i]=v/channels;peak=Math.Max(peak,Math.Abs(samples[i]));}
   if(peak<1)throw new Exception("The recording is silent.");return samples;
  }
 }
 public static void Validate(string path){int rate;Read(path,out rate);}
 public static void Prepare(string input,string output,bool open){int rate;var samples=Read(input,out rate);int passes=open?2:3;double cutoff=Math.Min(open?2800:1600,rate*.4);double alpha=1-Math.Exp(-2*Math.PI*cutoff/rate);
  for(int p=0;p<passes;p++){double prior=0;for(int i=0;i<samples.Length;i++){prior+=alpha*(samples[i]-prior);samples[i]=prior;}}
  double peak=0;foreach(double x in samples)peak=Math.Max(peak,Math.Abs(x));double scale=(open?7536:5335)/peak;int fade=Math.Max(1,rate/200);
  using(var w=new BinaryWriter(File.Create(output))){w.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));w.Write(36+samples.Length*2);w.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt "));w.Write(16);w.Write((short)1);w.Write((short)1);w.Write(rate);w.Write(rate*2);w.Write((short)2);w.Write((short)16);w.Write(System.Text.Encoding.ASCII.GetBytes("data"));w.Write(samples.Length*2);
   for(int i=0;i<samples.Length;i++){double f=Math.Min(1,Math.Min((double)i/fade,(double)(samples.Length-1-i)/fade));w.Write((short)Math.Round(Math.Max(-32767,Math.Min(32767,samples[i]*scale*f))));}}
 }
}
