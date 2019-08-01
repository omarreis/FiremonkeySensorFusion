unit Androidapi.JNI.Interfaces.JGeomagneticField;
interface
uses
  Androidapi.JNIBridge,
  Androidapi.JNI.JavaTypes;

type
// ===== Forward declarations =====
  JGeomagneticField = interface;//android.hardware.GeomagneticField
// ===== Interface declarations =====
  JGeomagneticFieldClass = interface(JObjectClass)
    ['{77F2155B-1F9A-40E0-89FA-FE3422336577}']
    {class} function init(gdLatitudeDeg: Single; gdLongitudeDeg: Single; altitudeMeters: Single; timeMillis: Int64): JGeomagneticField; cdecl;
    {class} function getHorizontalStrength: Single; cdecl;//Deprecated
    {class} function getInclination: Single; cdecl;//Deprecated
    {class} function getX: Single; cdecl;//Deprecated
  end;

  [JavaSignature('android/hardware/GeomagneticField')]
  JGeomagneticField = interface(JObject)
    ['{47CF41EC-AAAB-4EE2-867A-884A3EF00407}']
    function getDeclination: Single; cdecl;//Deprecated
    function getFieldStrength: Single; cdecl;//Deprecated
    function getY: Single; cdecl;
    function getZ: Single; cdecl;
  end;
  TJGeomagneticField = class(TJavaGenericImport<JGeomagneticFieldClass, JGeomagneticField>) end;

implementation

initialization
end.

