import ctypes as c
import json, time, sys
D=c.WinDLL(r'C:\FlightSimServer\SimConnect.dll')
H=c.c_void_p; U=c.c_uint32
D.SimConnect_Open.argtypes=[c.POINTER(H),c.c_char_p,H,U,H,U]
D.SimConnect_Open.restype=c.c_long
D.SimConnect_Close.argtypes=[H]
D.SimConnect_AddToDataDefinition.argtypes=[H,U,c.c_char_p,c.c_char_p,U,c.c_float,U]
D.SimConnect_RequestDataOnSimObject.argtypes=[H,U,U,U,U,U,U,U,U]
D.SimConnect_GetNextDispatch.argtypes=[H,c.POINTER(c.c_void_p),c.POINTER(U)]
D.SimConnect_SetDataOnSimObject.argtypes=[H,U,U,U,U,U,c.c_void_p]
def check(hr):
    if hr<0: raise RuntimeError(f'SimConnect error {hr:#x}')
h=H();check(D.SimConnect_Open(c.byref(h),b'Jetway Bell Diagnostic',None,0,None,0))
variables=[('L:B738_door_0','number',4),('INTERACTIVE POINT OPEN:0','percent',4),('L:GSX_BELL_DOOR_OPEN_RATIO','number',4),('L:GSX_BELL_CLOSED_VOLUME','number',4),('L:GSX_BELL_OPEN_VOLUME','number',4),('TITLE',None,9),('L:GSX_JETWAY_BELL_ACTIVE','number',4),('L:FSDT_GSX_REMOTE_PORT','number',4),('L:GSX_BELL_GAUGE_LOADED','number',4),('L:GSX_BELL_CONNECTED','number',4),('L:GSX_BELL_DISTANCE_MODULE_LOADED','number',4),('L:GSX_BELL_DISTANCE_VALID','number',4),('L:GSX_BELL_DISTANCE_METERS','number',4),('L:GSX_BELL_VOLUME','number',4)]
for i,(name,unit,kind) in enumerate(variables,1):
 check(D.SimConnect_AddToDataDefinition(h,i,name.encode(),unit.encode() if unit else None,kind,0,0xffffffff))
 check(D.SimConnect_RequestDataOnSimObject(h,i,i,0,1,0,0,0,0))
received={};deadline=time.monotonic()+5
try:
 while time.monotonic()<deadline and len(received)<len(variables):
  p=c.c_void_p();size=U()
  hr=D.SimConnect_GetNextDispatch(h,c.byref(p),c.byref(size))
  if hr>=0 and p.value:
   data=c.string_at(p,size.value)
   ident=int.from_bytes(data[8:12],'little')
   if ident==3: print('Exception:',json.dumps([int.from_bytes(data[j:j+4],'little') for j in (12,16,20)]))
   if ident==8:
    request=int.from_bytes(data[12:16],'little')
    if 1<=request<=len(variables):
     name,unit,kind=variables[request-1]
     received[name]=data[40:].split(b'\0')[0].decode(errors='replace') if kind==9 else c.c_double.from_buffer_copy(data[40:48]).value
  time.sleep(.01)
 print(json.dumps(received,indent=2))
 if '--sound-test' in sys.argv:
  # This changes only our custom bell variable and always resets it afterwards.
  value=c.c_double(1)
  check(D.SimConnect_SetDataOnSimObject(h,2,0,0,0,8,c.byref(value)))
  print('Custom bell test ON for four seconds',flush=True)
  time.sleep(4)
  value=c.c_double(0)
  check(D.SimConnect_SetDataOnSimObject(h,2,0,0,0,8,c.byref(value)))
  print('Custom bell test OFF',flush=True)
finally:
 if '--sound-test' in sys.argv:
  value=c.c_double(0);D.SimConnect_SetDataOnSimObject(h,2,0,0,0,8,c.byref(value))
 D.SimConnect_Close(h)