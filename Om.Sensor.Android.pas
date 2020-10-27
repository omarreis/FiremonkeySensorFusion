unit Om.Sensor.Android;   // derived from DW.Sensor.Android,
// to bring cross platform functionality to DW.Sensor ( by Dave Nottage )
// code adapted by Omar ago19
// oct20: Changed from DelphiWorlds native Android sensors to custom Delphi sebsors

interface

uses
  System.Sensors, {TCustomMotionSensor,TCustomOrientationSensor}
  FMX.Types,      {TTimer}
  DW.Sensor;

type
  TPlatformSensor = class(TCustomPlatformSensor)    // iOS
  private
  private
    FIsActive: Boolean;
    FSensorStart: TDateTime;
    FTimestamp: Int64;
    // memoise sensors
    fGyroSensor: TCustomMotionSensor;
    fMagSensor:  TCustomOrientationSensor;

    fTimer:TTimer;
    procedure TimerTick(Sender: TObject);  // use timer to get the sensor values. It would be better to receive sensor notifications, but I don't know how ???
  protected
    function  GetIsActive: Boolean; override;
    procedure SetIsActive(const Value: Boolean); override;
    procedure SetSensorType(const Value: TSensorType); override;
  public
    class function IsSensorTypeSupported(const ASensorType: TSensorType): Boolean;
  public
    constructor Create(const ASensor: TSensor); override;
    destructor  Destroy; override;
  end;

implementation

uses
  System.DateUtils, System.SysUtils;

{ TPlatformSensor }

constructor TPlatformSensor.Create(const ASensor: TSensor);
begin
  inherited;
  FIsActive    := false;
  FSensorStart := 0;
  FTimestamp   := 0;

  //FListener := TSensorEventListener.Create(Self);
  fGyroSensor    := nil;
  fMagSensor     := nil;

  fTimer := TTimer.Create(nil);
  fTimer.Interval := 100;
  fTimer.OnTimer := TimerTick;
  fTimer.Enabled := False;
end;

destructor TPlatformSensor.Destroy;
begin
  //FListener := nil;
  fTimer.Free;
  inherited;
end;

function TPlatformSensor.GetIsActive: Boolean;
begin
  Result := FIsActive;
end;

class function TPlatformSensor.IsSensorTypeSupported( const ASensorType: TSensorType): Boolean;
begin
  Result := ( ASensorType=Accelerometer ) or ( ASensorType= MagneticField);   // only these two supported at this time ( the ones I needed )
  //TODO: More sensors
end;

// sensor polled in a 100 ms timer
procedure TPlatformSensor.TimerTick(Sender:TObject);
var  aVx,aVy,aVz:double;
     LValues: TSensorValues;

     procedure _NotifyValues;
     begin
       SetLength(LValues, 3);
       LValues[0] := aVx;
       LValues[1] := aVy;
       LValues[2] := aVz;

       if FTimestamp=0 then FSensorStart := Now;
       ValuesChanged(LValues, Now  );  // call sensor event
     end;

begin
  case FSensorType of
     Accelerometer:
       begin
         if Assigned(fGyroSensor) and (fGyroSensor.Started) then
           begin
             aVx := -fGyroSensor.AccelerationX;   // Invert gyro signal
             aVy := -fGyroSensor.AccelerationY;
             aVz := -fGyroSensor.AccelerationZ;
             _NotifyValues;
           end;
       end;
     MagneticField:
       begin
         if Assigned(fMagSensor)  and (fMagSensor.Started)  then
           begin
             aVx := fMagSensor.HeadingX;    // mag field is the same for iOS and Android, it seems
             aVy := fMagSensor.HeadingY;
             aVz := fMagSensor.HeadingZ;
             _NotifyValues;
           end;
       end;
     //TODO: Other sensors
  end;
end;

procedure TPlatformSensor.SetIsActive(const Value: Boolean);
var Sensor:TCustomSensor; aSensors:TSensorArray; aSensorManager: TSensorManager;
begin
  if Value = FIsActive then   Exit; // <======
  if Value then
    begin // get and activate the sensor manager
      aSensorManager := TSensorManager.Current;
      aSensorManager.Activate;
      // get magnetic sensor
      fMagSensor  := nil;
      aSensors  := TSensorManager.Current.GetSensorsByCategory( TSensorCategory.Orientation ); // get sensor list
      for Sensor in aSensors do
        begin
          if FSensorType=MagneticField then
              begin
                if TCustomOrientationSensor(Sensor).SensorType = TOrientationSensorType.Compass3D then
                   fMagSensor := TCustomOrientationSensor(Sensor);
                if Assigned(fMagSensor)  and (not fMagSensor.Started)  then fMagSensor.Start;
                fTimer.Enabled := true;
              end;
        end;

      // get acceleration sensor
      fGyroSensor := nil;
      aSensors  := TSensorManager.Current.GetSensorsByCategory( TSensorCategory.Motion ); // get sensor list
      for Sensor in aSensors do
        begin
          if FSensorType=Accelerometer then
              begin
                if TCustomMotionSensor(Sensor).SensorType = TMotionSensorType.Accelerometer3D then
                  fGyroSensor := TCustomMotionSensor(Sensor);
                if Assigned(fGyroSensor) and (not fGyroSensor.Started) then fGyroSensor.Start;
                fTimer.Enabled := true;
              end;
        end;
    end
    else begin  //setIsACTIVE(FALSE)
      { stop the sensor if it is not stopped }
      case FSensorType of
        Accelerometer:
          begin
            if Assigned(fGyroSensor) and (not fGyroSensor.Started) then fGyroSensor.Stop;
            fTimer.Enabled := false;
          end;
        MagneticField:
          begin
            if Assigned(fMagSensor)  and (not fMagSensor.Started)  then fMagSensor.Stop;
            fTimer.Enabled := false;
          end;
      end;
    end;

  FIsActive := Value;
end;


procedure TPlatformSensor.SetSensorType(const Value: TSensorType);
var
  LIsActive: Boolean;
begin
  if Value=FSensorType then
    Exit; // <======

  LIsActive := GetIsActive;
  SetIsActive(False);
  FSensorType := Value; //chg sensor type
  FTimestamp := 0;
  SetIsActive(LIsActive);
end;

end.

