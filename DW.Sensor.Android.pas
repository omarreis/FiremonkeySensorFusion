unit DW.Sensor.Android;

interface

uses
  Androidapi.JNIBridge,
  DW.Androidapi.JNI.SensorManager, DW.Sensor;

type
  TPlatformSensor = class;

  TSensorEventListener = class(TJavaLocal, JSensorEventListener)
  private
    FPlatformSensor: TPlatformSensor;
  public
    { JSensorEventListener }
    procedure onAccuracyChanged(sensor: JSensor; accuracy: Integer); cdecl;
    procedure onSensorChanged(event: JSensorEvent); cdecl;
  public
    constructor Create(const APlatformSensor: TPlatformSensor);
  end;

  TPlatformSensor = class(TCustomPlatformSensor)
  private
    class var FSensorManager: JSensorManager;
    class function GetDefaultSensor(const AType: Integer): JSensor;
    class function GetPlatformSensorType(const ASensorType: TSensorType): Integer;
    class function SensorManager: JSensorManager;
  private
    FIsActive: Boolean;
    FListener: JSensorEventListener;
    FSensorStart: TDateTime;
    FTimestamp: Int64;
  protected
    procedure AccuracyChanged(sensor: JSensor; accuracy: Integer);
    function GetIsActive: Boolean; override;
    procedure SensorChanged(event: JSensorEvent);
    procedure SetIsActive(const Value: Boolean); override;
    procedure SetSensorType(const Value: TSensorType); override;
  public
    class function IsSensorTypeSupported(const ASensorType: TSensorType): Boolean;
  public
    constructor Create(const ASensor: TSensor); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.DateUtils, System.SysUtils,
  Androidapi.JNI.JavaTypes, Androidapi.Helpers, AndroidApi.JNI.GraphicsContentViewText, Androidapi.JNI,
  DW.Androidapi.JNI.System;

{ TSensorEventListener }

constructor TSensorEventListener.Create(const APlatformSensor: TPlatformSensor);
begin
  inherited Create;
  FPlatformSensor := APlatformSensor;
end;

procedure TSensorEventListener.onAccuracyChanged(sensor: JSensor; accuracy: Integer);
begin
  FPlatformSensor.AccuracyChanged(sensor, accuracy);
end;

procedure TSensorEventListener.onSensorChanged(event: JSensorEvent);
begin
  FPlatformSensor.SensorChanged(event);
end;

{ TPlatformSensor }

constructor TPlatformSensor.Create(const ASensor: TSensor);
begin
  inherited;
  FListener := TSensorEventListener.Create(Self);
end;

destructor TPlatformSensor.Destroy;
begin
  FListener := nil;
  inherited;
end;

class function TPlatformSensor.GetDefaultSensor(const AType: Integer): JSensor;
begin
  Result := nil;
  if AType <> -1 then
    Result := SensorManager.getDefaultSensor(AType);
end;

function TPlatformSensor.GetIsActive: Boolean;
begin
  Result := FIsActive;
end;

class function TPlatformSensor.GetPlatformSensorType(const ASensorType: TSensorType): Integer;
begin
  Result := -1;
  case ASensorType of
    TSensorType.Accelerometer:
      Result := TJSensor.JavaClass.TYPE_ACCELEROMETER;
    TSensorType.AmbientTemperature:
      Result := TJSensor.JavaClass.TYPE_AMBIENT_TEMPERATURE;
    TSensorType.GameRotation:
      Result := TJSensor.JavaClass.TYPE_GAME_ROTATION_VECTOR;
    TSensorType.GeomagneticRotation:
      Result := TJSensor.JavaClass.TYPE_GEOMAGNETIC_ROTATION_VECTOR;
    TSensorType.Gravity:
      Result := TJSensor.JavaClass.TYPE_GRAVITY;
    TSensorType.Gyroscope:
      Result := TJSensor.JavaClass.TYPE_GYROSCOPE;
    TSensorType.HeartRate:
      Result := TJSensor.JavaClass.TYPE_HEART_RATE;
    TSensorType.Light:
      Result := TJSensor.JavaClass.TYPE_LIGHT;
    TSensorType.LinearAcceleration:
      Result := TJSensor.JavaClass.TYPE_LINEAR_ACCELERATION;
    TSensorType.MagneticField:
      Result := TJSensor.JavaClass.TYPE_MAGNETIC_FIELD;
    TSensorType.Orientation:
      Result := TJSensor.JavaClass.TYPE_ORIENTATION;
    TSensorType.Pressure:
      Result := TJSensor.JavaClass.TYPE_PRESSURE;
    TSensorType.Proximity:
      Result := TJSensor.JavaClass.TYPE_PROXIMITY;
    TSensorType.RelativeHumidity:
      Result := TJSensor.JavaClass.TYPE_RELATIVE_HUMIDITY;
    TSensorType.Rotation:
      Result := TJSensor.JavaClass.TYPE_ROTATION_VECTOR;
    TSensorType.SignificantMotion:
      Result := TJSensor.JavaClass.TYPE_SIGNIFICANT_MOTION;
    TSensorType.StepCounter:
      Result := TJSensor.JavaClass.TYPE_STEP_COUNTER;
    TSensorType.StepDetector:
      Result := TJSensor.JavaClass.TYPE_STEP_DETECTOR;
    TSensorType.Temperature:
      Result := TJSensor.JavaClass.TYPE_TEMPERATURE;
  end;
end;

class function TPlatformSensor.IsSensorTypeSupported(const ASensorType: TSensorType): Boolean;
begin
  Result := GetDefaultSensor(GetPlatformSensorType(ASensorType)) <> nil;
end;

procedure TPlatformSensor.AccuracyChanged(sensor: JSensor; accuracy: Integer);
begin
  //
end;

procedure TPlatformSensor.SensorChanged(event: JSensorEvent);
var
  LValues: TSensorValues;
  I: Integer;
  LMillis: Int64;
begin
  SetLength(LValues, event.values.Length);
  for I := 0 to event.values.Length - 1 do
    LValues[I] := event.values[I];
  if FTimestamp = 0 then
  begin
    FSensorStart := Now;
    LMillis := 0;
  end
  else
    LMillis := (event.timestamp - FTimestamp) div 1000000;
  ValuesChanged(LValues, IncMilliSecond(FSensorStart, LMillis));
end;

class function TPlatformSensor.SensorManager: JSensorManager;
var
  LService: JObject;
begin
  if FSensorManager = nil then
  begin
    LService := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.SENSOR_SERVICE);
    FSensorManager := TJSensorManager.Wrap((LService as ILocalObject).GetObjectID);
  end;
  Result := FSensorManager;
end;

procedure TPlatformSensor.SetIsActive(const Value: Boolean);
var
  LSensor: JSensor;
begin
  if Value = FIsActive then
    Exit; // <======
  if Value then
  begin
    LSensor := GetDefaultSensor(GetPlatformSensorType(FSensorType));
    if LSensor <> nil then
    begin
      SensorManager.registerListener(FListener, LSensor, TJSensorManager.JavaClass.SENSOR_DELAY_NORMAL); //!!!! (Sampling period)
      FIsActive := True;
    end
    else
      FIsActive := False;
  end
  else
  begin
    SensorManager.unregisterListener(FListener);
    FIsActive := False;
  end;
end;

procedure TPlatformSensor.SetSensorType(const Value: TSensorType);
var
  LIsActive: Boolean;
begin
  if Value = FSensorType then
    Exit; // <======
  LIsActive := GetIsActive;
  SetIsActive(False);
  FSensorType := Value;
  FTimestamp := 0;
  SetIsActive(LIsActive);
end;

end.
