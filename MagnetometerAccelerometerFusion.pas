unit MagnetometerAccelerometerFusion;  // Android/iOS sensor fusion: Accelerometer+Magnetometer
// Calculates tilt compensated Heading (N based), plus altitude and phone roll (the last two require the phone vertical)
interface

uses
  System.SysUtils,System.Classes, System.Sensors, System.Sensors.Components,
  FMX.Forms,
  DW.Sensor;     // KastriFree Sensors

Type
  TMagnetoAccelerometerFusion=class
  private
    [Weak] fParentForm:TCommonCustomForm;  //changed from TForm that to accept TForm and TForm3D

    fAccelSensor: TSensor;        // DW sensors
    fMagSensor:   TSensor;

    fLocationSensor: TLocationSensor;

    fAccelSensorTime: TDateTime;  // last sensor event
    fMagSensorTime: TDateTime;
    fCompassEventTime: TDateTime;

    fOnAccelerometerChange:TNotifyEvent;    //fusion events
    fOnMagnetometerChange:TNotifyEvent;
    fOnHeadingAltitudeChange:TNotifyEvent;

    procedure MagSensorValuesChangedHandler(Sender: TObject; const AValues: TSensorValues; const ATimestamp: TDateTime);
    procedure AccelSensorValuesChangedHandler(Sender: TObject; const AValues: TSensorValues; const ATimestamp: TDateTime);
    procedure CalcShowTiltCompensatedHeading;
    procedure LocationSensorLocationChanged(Sender: TObject; const OldLocation,NewLocation: TLocationCoord2D);
  public
    fGx,fGy,fGz,                  //accelerometer vec
    fMx,fMy,fMz:Single;           //magnetometer vec

    fTCMagHeading,fTCTrueHeading,fAltitude,fRoll:Single; //results in rectangular coordinates Azimuth/elevation/roll

    fAccelMS,fMagMS:int64;        //time in ms between sensor events
    fCompassMinTime:int64;        //minimun time between compass events

    fMagDeclination:Single;       //mag decl  ( calculated with wwm for Android, from GPS sensor on iOS )

    // fLocationxxx = GPS sensor location
    fLocationTime:TDatetime;   //local time
    fLocationLat :Single;      // GPS loc
    fLocationLon :Single;      // lon uses int'l lon signal convention ( E+ )

    fErrorMessage:String;

    Constructor Create(aForm:TCommonCustomForm);
    Destructor  Destroy; override;
    procedure   StartStopSensors(bStart: boolean);
    property    LocationSensor: TLocationSensor read fLocationSensor;

    property    OnAccelerometerChange:TNotifyEvent   read fOnAccelerometerChange   write fOnAccelerometerChange;
    property    OnMagnetometerChange:TNotifyEvent    read fOnMagnetometerChange    write fOnMagnetometerChange;
    property    OnHeadingAltitudeChange:TNotifyEvent read fOnHeadingAltitudeChange write fOnHeadingAltitudeChange;
  end;

function courseToDirectionStr(aCourse:integer):String;  // p.e. 180 --> 'S'

implementation //-----------------------------------------------------------------

uses
  {$IFDEF ANDROID}
  Androidapi.JNI.Interfaces.JGeomagneticField,  // mag declination  calc using WMM
  {$ENDIF ANDROID}
  System.DateUtils,
  System.Math;

const                            //  0   1    2   3    4   5    6    7   8
  direcoes:array[0..8] of String = ('N','NE','E','SE','S','SW','W','NW','N');
  RangePardal = 220;          // abaixo desta dist avisa com beep-beep e led piscando

function courseToDirectionStr(aCourse:integer):String;  // p.e. 180 --> 'S'
var q:integer;                 //
begin
  q := Round(aCourse/45);    //
  if (q>=0) and (q<=8) then Result:=direcoes[q]
    else Result:=''; //??
end;

// this function uses x,y,z axis for the phone in vertical orientation (portrait mode, z coming out of the screen)
// see https://www.st.com/content/ccc/resource/technical/document/design_tip/group0/56/9a/e4/04/4b/6c/44/ef/DM00269987/files/DM00269987.pdf/jcr:content/translations/en.DM00269987.pdf
function calcTiltCompensatedMagneticHeading(const {acel}aGx,aGy,aGz,{mag} aMx,aMy,aMz:Single; {out}
   var aHeading,aAltitude,aRoll:Single ):boolean;                            //return in degrees
var Phi,Theta,cosPhi,sinPhi,Gz2,By2,Bz2,Bx3:Single;
begin
  Result := false;   //=invalid

  if IsNaN(aGx) or IsNaN(aGy) or IsNaN(aGz) or              //check for NaNs
     IsNaN(aMx) or IsNaN(aMy) or IsNaN(aMz) then exit;

  Phi    := ArcTan2(aGy,aGz);    //calc Roll (Phi)
  cosPhi := Cos(Phi);         //memoise phi trigs
  sinPhi := Sin(Phi);

  Gz2 := aGy*sinPhi+aGz*cosPhi;
  if (Gz2<>0) then
    begin
      Theta := Arctan(-aGx/Gz2);                   // Theta = Pitch
      By2 := aMz * sinPhi - aMy * cosPhi;
      Bz2 := aMy * sinPhi + aMz * cosPhi;
      Bx3 := aMx * Cos(Theta) + Bz2 * Sin(Theta);
      aHeading  := ArcTan2(By2,Bx3)*180/Pi-90;      // convert to degrees and then add   90 for North based heading  (Psi)

      aAltitude := Phi*180/Pi-90;         // Phi=altitude
      aRoll     := Theta*180/Pi;          // theta = phone roll
      Result := true;
    end;
end;

{ TMagnetoAccelerometerFusion }

constructor TMagnetoAccelerometerFusion.Create(aForm:TCommonCustomForm);
begin
  inherited Create;
  fParentForm := aForm;

  fOnAccelerometerChange   :=nil;
  fOnMagnetometerChange    :=nil;
  fOnHeadingAltitudeChange :=nil;

  fMagSensorTime     :=0;
  fCompassEventTime  :=0;

  fMagDeclination    :=0;
  fLocationTime      :=0;
  fLocationLat       :=0;
  fLocationLon       :=0;

  //create sensors

  fAccelSensor := TSensor.Create;
  fAccelSensor.OnValuesChanged := AccelSensorValuesChangedHandler;

  fMagSensor := TSensor.Create;
  fMagSensor.OnValuesChanged  := MagSensorValuesChangedHandler;

  // defer sensor start to FormActivate

  fGx:=0; fGy:=0; fGz:=0;
  fMx:=0; fMy:=0; fMz:=0;

  fTCMagHeading:=0; fTCTrueHeading:=0; fAltitude:=0; fRoll:=0;

  fAccelMS :=0;
  fMagMS   :=0;

  fCompassMinTime := 200;  // min compass event frequency in ms ( default=200ms )

  fLocationSensor := TLocationSensor.Create(nil);
  fLocationSensor.Accuracy := 50.0;
  fLocationSensor.OnLocationChanged := LocationSensorLocationChanged;

  fErrorMessage:='';
end;

destructor TMagnetoAccelerometerFusion.Destroy;
begin
  fAccelSensor.Free;
  fMagSensor.Free;
  // fLocationSensor.Free;   // tava dando algum pau no iOS

  inherited;
end;

{$IFDEF ANDROID}

function switchDWords(n:int64):int64;    // switch hi <--> lo dwords of an int64
var i: Integer;
    nn :int64; nnA:array[0..7]  of byte absolute nn;
    nn1:int64; nn1A:array[0..7] of byte absolute nn1;
begin
  nn  := n;
  nn1 := nn;          // save nn
  for i := 0 to 3 do  // switch bytes  hidword <--> lodword
    begin
      nnA[i]   := nn1A[i+4];
      nnA[i+4] := nn1A[i];
    end;
  Result := nn;
end;


function getGeomagneticDeclination(const aLat,aLon,aAlt:Single):Single;  //for Android only
var GeoField: JGeomagneticField; tw1,tw2:int64; t0,t:TDatetime;   tm:int64;
begin
  // here it should have been UTC time, not Local.. but the dif is little
  tm := System.DateUtils.DateTimeToUnix( Now, {InputAsUTC:} false )*1000;

  // jan20: the line below was required to fix a compiler bug, corrected in Rio, apparently :)
  //   tm := switchDWords(tm);    // <--- hack tm. Correct some endian problem passing int64 to Java API
  //   see https://stackoverflow.com/questions/53342348/wrong-result-calling-android-method-from-delphi/53373965#53373965

  GeoField := TJGeomagneticField.JavaClass.init(aLat,aLon,aAlt,tm );
  Result   := GeoField.getDeclination();
end;
{$ENDIF ANDROID}

// GPS sensor events
procedure TMagnetoAccelerometerFusion.LocationSensorLocationChanged(Sender: TObject; const OldLocation,NewLocation: TLocationCoord2D);
var aMagDec:Single;
begin
  fLocationTime  := Now;   //local tm
  fLocationLat   := NewLocation.Latitude;    //just save loc
  fLocationLon   := NewLocation.Longitude;   //all intl lon signal conv

  // update mag delination
  {$IFDEF Android}    // For Android only. iOS gives True heading directly AFAIK
  fMagDeclination := getGeomagneticDeclination({Lat:}NewLocation.Latitude ,{Lon:}NewLocation.Longitude, {Alt:} 0 ); // TODO: put a real altitude
  {$ENDIF Android}

  {$IFDEF iOS}
  // iOS LocationSensor calculates mag decl
  if not ( IsNaN(fLocationSensor.Sensor.TrueHeading) or IsNaN(fLocationSensor.Sensor.MagneticHeading) )  then
    begin
      aMagDec := fLocationSensor.Sensor.TrueHeading-fLocationSensor.Sensor.MagneticHeading; //obtain mag dec from GPS sensor
      if not IsNaN(aMagDec) then    //have obtained a valid magdecl from gps sensor
        begin
          fMagDeclination := aMagDec;   // mag decl, as received from location sensor
          if      (fMagDeclination<-180) then fMagDeclination:=fMagDeclination+360     //normalize in -180..+180 range
          else if (fMagDeclination>+180) then fMagDeclination:=fMagDeclination-360;
        end;
    end;
  {$ENDIF iOS}

  // fLocationSensor.Active := false;   //get location once and stop sensor, to save battery
end;


procedure TMagnetoAccelerometerFusion.AccelSensorValuesChangedHandler(Sender: TObject;
    const AValues: TSensorValues; const ATimestamp: TDateTime);
var I,n: Integer;  ms:int64; T:TDatetime;
begin
  T  :=Now;
  ms := MilliSecondsBetween(T, fAccelSensorTime);
  if (ms<17) then exit;    // 17ms ~= 1/60s    <======  limit event frequency to 1/60
  fAccelSensorTime := T;
  n := Length(AValues);
  if (n>2) then //min 3 values
    begin
      fGx:=AValues[0];
      fGy:=AValues[1];
      fGz:=AValues[2];
      fMagMS:=ms;

      if Assigned(fOnAccelerometerChange) then fOnAccelerometerChange(Self);

      CalcShowTiltCompensatedHeading;
    end;

  // Limit the updates
  // if (ms<1000) then
  //   begin
  //     SensorMemo.Lines.Add( FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz', ATimestamp) );
  //     for I := 0 to Length(AValues) - 1 do
  //       SensorMemo.Lines.Add(Format('Value %d: %.4f', [I, AValues[I]]));
  //   end;

end;

procedure TMagnetoAccelerometerFusion.MagSensorValuesChangedHandler(
  Sender: TObject; const AValues: TSensorValues; const ATimestamp: TDateTime);
var I,n: Integer;  ms:int64; T:TDatetime;
begin
  T  := Now;
  ms := MilliSecondsBetween(T, fMagSensorTime);
  if (ms<17) then exit;    // 17ms ~= 1/60s    <======  limit frequency
  fMagSensorTime := T;
  n := Length(AValues);

  if (n>2) then //min 4 values ? includes True Heading
    begin
      fMx := AValues[0];
      fMy := AValues[1];
      fMz := AValues[2];
      fAccelMS := ms;
      if Assigned(fOnMagnetometerChange) then fOnMagnetometerChange(Self);

      CalcShowTiltCompensatedHeading;
    end;
end;

//calc tilt compensaged heading, altitude and roll
procedure TMagnetoAccelerometerFusion.CalcShowTiltCompensatedHeading;
var aMagHeading,aAltitude,aRoll:Single; IsLandscapeMode,ok:boolean; T:TDatetime; ms:int64;
begin
  T  := Now;
  ms := MilliSecondsBetween(T, fCompassEventTime);
  if (ms<fCompassMinTime) then exit;    //ignore events too frequent
  fCompassEventTime := T;              //save event tm

  aMagHeading:=0;
  //quick orientation check
  if Assigned(fParentForm) then IsLandscapeMode := (fParentForm.Width>fParentForm.Height)
    else IsLandscapeMode :=true;  //no form ?? assume portrait orientation

  ok:= false;
  if IsLandscapeMode then  //landscape phone orientation   // TODO: this works for two orientations, but not upside-down
    begin
       ok := calcTiltCompensatedMagneticHeading({acel}fGy,-fGx,fGz,{mag} fMy,-fMx,fMz,{out}aMagHeading,aAltitude,aRoll ); //rotated 90 in z axis
    end
    else begin  //portrait orientation
       ok := calcTiltCompensatedMagneticHeading({acel}fGx,fGy,fGz,{mag} fMx,fMy,fMz,{out}aMagHeading,aAltitude,aRoll);  // normal portrait orientation
    end;

  if ok then
    begin
      aMagHeading := -aMagHeading-180;     // invert angle direction and start pos to get North based heading (don't ask me why..)
      while (aMagHeading<0) do aMagHeading:=aMagHeading+360;        // put in 0..360
      //return angles
      fTCMagHeading  := aMagHeading;       // tilt compensated heading (aka course,cap,heading,bearing..)
      if not IsNaN(fMagDeclination) then
        begin
          fTCTrueHeading := aMagHeading+fMagDeclination;
          if      (fTCTrueHeading<0)    then fTCTrueHeading:=fTCTrueHeading+360
          else if (fTCTrueHeading>=360) then fTCTrueHeading:=fTCTrueHeading-360;   // put in 0..360 range
        end
        else fTCTrueHeading  := NaN;  // no mag decl yet, no true heading

      fAltitude  := aAltitude;    // altitude or elevation
      fRoll      := aRoll;

      if Assigned( fOnHeadingAltitudeChange ) then
          fOnHeadingAltitudeChange(Self);
    end;
end;

procedure TMagnetoAccelerometerFusion.StartStopSensors(bStart: boolean);
var T:TDatetime;
begin
  T := Now;
  fErrorMessage:='';

  fAccelSensor.IsActive   := False;  //restart
  fAccelSensor.SensorType := TSensorType.Accelerometer;
  fAccelSensorTime        := T;
  fAccelSensor.IsActive   := bStart;

  fMagSensor.IsActive     := False;
  fMagSensor.SensorType   := TSensorType.MagneticField;
  fMagSensorTime          := T;
  fMagSensor.IsActive     := bStart;

  //may throw  exception, if permission not granted
  try
    fLocationSensor.Active  := bStart;
  except
    // TODO:
    if bStart then fErrorMessage := 'Error starting LocationSensor'
      else fErrorMessage := 'Error stopping LocationSensor';
  end;

  fCompassEventTime   := T;
end;

end.

