#include <MSFS/MSFS.h>
#include <MSFS/MSFS_WindowsTypes.h>
#include <MSFS/MSFS_Vars.h>
#include <SimConnect.h>
#include <cmath>
#include <cstring>
#include <cstdio>
#include <cstddef>

// Handle stack-protector failure locally; MSFS does not need a host import for it.
extern "C" void __stack_chk_fail() { __builtin_trap(); }

// Read-only telemetry: no jetway/aircraft control events are transmitted.
static HANDLE connection = 0;
static FsUnitId numberUnit;
static FsLVarId code1, code2, activeVar, volumeVar, distanceVar, validVar, loadedVar, movingVar, statusVar;
static char airport[9] = {};
static double now=0, lastRequest=-10, lastGeometry=-10, targetVolume=12.5, volume=12.5;
static DWORD selectedJetway=0, userId=0;
struct Aircraft { double lat, lon, alt, heading, doorX, doorY, doorZ; };
static Aircraft aircraft={};
static bool haveAircraft=false;
static const double radians=0.017453292519943295, earthRadius=6371000;
static double read(FsLVarId id) { double v=0;fsVarsLVarGet(id,numberUnit,&v);return v; }
static void write(FsLVarId id,double v) {fsVarsLVarSet(id,numberUnit,v);}
// Adjustable endpoints, relative to the previous distance curve.
static const double NEAR_DISTANCE_METERS=3.0, FAR_DISTANCE_METERS=10.0;
static const double NEAR_VOLUME_MULTIPLIER=1.0, FAR_VOLUME_MULTIPLIER=0.125;
static const double INITIAL_VOLUME=12.5;
static double gain(double distance) {
 const double previous=std::fmax(5.0,100.0/(1.0+(distance/10.0)*(distance/10.0)));
 const double progress=std::fmax(0.0,std::fmin(1.0,(distance-NEAR_DISTANCE_METERS)/(FAR_DISTANCE_METERS-NEAR_DISTANCE_METERS)));
 return previous*(NEAR_VOLUME_MULTIPLIER+(FAR_VOLUME_MULTIPLIER-NEAR_VOLUME_MULTIPLIER)*progress);
}
static void invalidate() {write(validVar,0);write(distanceVar,-1);targetVolume=INITIAL_VOLUME;selectedJetway=0;write(movingVar,0);write(statusVar,-1);}
static void CALLBACK dispatch(SIMCONNECT_RECV* data,DWORD bytes,void*) {
 if(data->dwID==SIMCONNECT_RECV_ID_SIMOBJECT_DATA) {
  auto* p=reinterpret_cast<SIMCONNECT_RECV_SIMOBJECT_DATA*>(data);
  if(p->dwRequestID==1 && bytes>=offsetof(SIMCONNECT_RECV_SIMOBJECT_DATA,dwData)+sizeof(Aircraft)) {
   std::memcpy(&aircraft,&p->dwData,sizeof(Aircraft));userId=p->dwObjectID;haveAircraft=true;
  }
 } else if(data->dwID==SIMCONNECT_RECV_ID_JETWAY_DATA && haveAircraft) {
  auto* p=reinterpret_cast<SIMCONNECT_RECV_JETWAY_DATA*>(data);
  const size_t offset=offsetof(SIMCONNECT_RECV_JETWAY_DATA,rgData);
  if(bytes<offset)return;
  size_t count=(bytes-offset)/sizeof(SIMCONNECT_JETWAY_DATA);
  if(count>p->dwArraySize)count=p->dwArraySize;
  double best=1e30,chosenDistance=0;DWORD chosen=0;int chosenStatus=-1;
  const double cs=std::cos(aircraft.heading),sn=std::sin(aircraft.heading);
  const double doorEast=aircraft.doorX*cs+aircraft.doorZ*sn;
  const double doorNorth=aircraft.doorZ*cs-aircraft.doorX*sn;
  for(size_t i=0;i<count;++i) {
   const auto& j=p->rgData[i];
   if(std::strncmp(j.AirportIcao,airport,8)!=0)continue;
   if(j.AttachedObjectId!=0 && j.AttachedObjectId!=userId)continue;
   const double east=(j.Lla.Longitude-aircraft.lon)*radians*earthRadius*std::cos(aircraft.lat*radians);
   const double north=(j.Lla.Latitude-aircraft.lat)*radians*earthRadius;
   if(east*east+north*north>150*150 || j.Lla.Altitude<0)continue;
   const double angle=j.Pbh.Heading*radians;
   const double x=east+j.MainHandlePos.x*std::cos(angle)+j.MainHandlePos.z*std::sin(angle)-doorEast;
   const double z=north+j.MainHandlePos.z*std::cos(angle)-j.MainHandlePos.x*std::sin(angle)-doorNorth;
   const double y=j.Lla.Altitude+j.MainHandlePos.y-aircraft.alt-aircraft.doorY;
   const double d=std::sqrt(x*x+y*y+z*z);
   if(!std::isfinite(d) || d>100)continue;
   // Lock the selected jetway for the operation; attachment to the actual user wins.
   double score=d;
   if(j.JetwayObjectId==selectedJetway)score-=200;
   if(j.AttachedObjectId==userId && userId!=0)score-=1000;
   if(score<best){best=score;chosen=j.JetwayObjectId;chosenDistance=d;chosenStatus=j.Status;}
  }
  if(chosen) {
   selectedJetway=chosen;lastGeometry=now;
   targetVolume=gain(chosenDistance);
   write(distanceVar,chosenDistance);write(validVar,1);
   write(statusVar,chosenStatus);write(movingVar,chosenStatus>=1 && chosenStatus<=6 ? 1 : 0);
  }
 }
}
extern "C" MSFS_CALLBACK void module_init() {
 numberUnit=fsVarsGetUnitId("number");
 code1=fsVarsRegisterLVar("GSX_BELL_AIRPORT_CODE_1");code2=fsVarsRegisterLVar("GSX_BELL_AIRPORT_CODE_2");
 activeVar=fsVarsRegisterLVar("GSX_JETWAY_BELL_ACTIVE");volumeVar=fsVarsRegisterLVar("GSX_BELL_VOLUME");
 distanceVar=fsVarsRegisterLVar("GSX_BELL_DISTANCE_METERS");validVar=fsVarsRegisterLVar("GSX_BELL_DISTANCE_VALID");loadedVar=fsVarsRegisterLVar("GSX_BELL_DISTANCE_MODULE_LOADED");
 movingVar=fsVarsRegisterLVar("GSX_BELL_JETWAY_MOVING");statusVar=fsVarsRegisterLVar("GSX_BELL_JETWAY_STATUS");
 write(volumeVar,INITIAL_VOLUME);invalidate();write(loadedVar,1);
 if(SimConnect_Open(&connection,"GSX Jetway Bell Distance",nullptr,0,0,0)<0){connection=0;return;}
 const char* names[]={"PLANE LATITUDE","PLANE LONGITUDE","PLANE ALTITUDE","PLANE HEADING DEGREES TRUE","INTERACTIVE POINT POSX:0","INTERACTIVE POINT POSY:0","INTERACTIVE POINT POSZ:0"};
 const char* units[]={"degrees","degrees","meters","radians","meters","meters","meters"};
 for(int i=0;i<7;++i)SimConnect_AddToDataDefinition(connection,1,names[i],units[i]);
 SimConnect_RequestDataOnSimObject(connection,1,1,SIMCONNECT_OBJECT_ID_USER,SIMCONNECT_PERIOD_SIM_FRAME,0,0,5);
 // In standalone WASM, this registers the dispatch callback with the simulator.
 SimConnect_CallDispatch(connection,dispatch,nullptr);
}
extern "C" MSFS_CALLBACK void Update_StandAlone(float dt) {
 if(!std::isfinite(dt)||dt<0)return;
 if(connection)SimConnect_CallDispatch(connection,dispatch,nullptr);
 now+=dt;
 write(loadedVar,1); // Flight loading can reset this diagnostic after module_init.
 char next[9]={};unsigned long a=static_cast<unsigned long>(read(code1)),b=static_cast<unsigned long>(read(code2));
 for(int i=0;i<4;++i){next[i]=static_cast<char>((a>>(8*i))&255);next[4+i]=static_cast<char>((b>>(8*i))&255);}
 if(std::strncmp(next,airport,8)!=0){std::memcpy(airport,next,9);invalidate();lastRequest=-10;}
 // Poll while silent: automatic GSX boarding skips the manual service states.
 if(connection && airport[0] && now-lastRequest>=0.2) {lastRequest=now;SimConnect_RequestJetwayData(connection,airport,0,nullptr);}
 if(now-lastGeometry>2.0)invalidate();
 volume+=(targetVolume-volume)*(1.0-std::exp(-std::fmin(static_cast<double>(dt),0.5)/0.35));
 write(volumeVar,volume);
}
extern "C" MSFS_CALLBACK void module_deinit() {
 if(connection)SimConnect_Close(connection);connection=0;
 write(loadedVar,0);invalidate();write(volumeVar,INITIAL_VOLUME);
}
