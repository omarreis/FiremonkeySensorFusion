unit DW.Sensor;

interface

type
  TSensor = class;

  TSensorType = (
    None, Accelerometer, AmbientTemperature, GameRotation, GeomagneticRotation, Gravity, Gyroscope, HeartRate, Light, LinearAcceleration,
    MagneticField, Orientation, Pressure, Proximity, RelativeHumidity, Rotation, SignificantMotion, StepCounter, StepDetector, Temperature
  );

  TSensorValues = TArray<Single>;

  TCustomPlatformSensor = class(TObject)
  private
    FSensor: TSensor;
  protected
    FSensorType: TSensorType;
    function GetIsActive: Boolean; virtual; abstract;
    procedure SetIsActive(const Value: Boolean); virtual; abstract;
    procedure SetSensorType(const Value: TSensorType); virtual; abstract;
    procedure ValuesChanged(const AValues: TSensorValues; const ATimestamp: TDateTime);
    property Sensor: TSensor read FSensor;
  public
    constructor Create(const ASensor: TSensor); virtual;
  end;

  TValuesChangedEvent = procedure(Sender: TObject; const Values: TSensorValues; const Timestamp: TDateTime) of object;

  TSensor = class(TObject)
  private
    class function GetSensorName(const ASensorType: TSensorType): string; static;
    class function GetSensorNameType(const ASensorName: string): TSensorType; static;
  private
    const cSensorNames: array[TSensorType] of string = (
      'None', 'Accelerometer', 'Ambient Temperature', 'Game Rotation', 'Geomagnetic Rotation', 'Gravity', 'Gyroscope', 'Heartrate', 'Light',
      'Linear Acceleration', 'Magnetic Field', 'Orientation', 'Pressure', 'Proximity', 'Relative Humidity', 'Rotation', 'Significant Motion',
      'Step Counter', 'Step Detector', 'Temperature'
    );
  private
    FPlatformSensor: TCustomPlatformSensor;
    FOnValuesChanged: TValuesChangedEvent;
    function  GetIsActive: Boolean;
    function  GetSensorType: TSensorType;
    procedure SetIsActive(const Value: Boolean);
    procedure SetSensorType(const Value: TSensorType);
  protected
    procedure ValuesChanged(const AValues: TSensorValues; const ATimestamp: TDateTime);
  public
    class function IsSensorTypeSupported(const ASensorType: TSensorType): Boolean;
    class property SensorNames[const ASensorType: TSensorType]: string read GetSensorName;
    class property SensorNameTypes[const ASensorName: string]: TSensorType read GetSensorNameType;
  public
    constructor Create;
    destructor Destroy; override;
    property IsActive: Boolean read GetIsActive write SetIsActive;
    property SensorType: TSensorType read GetSensorType write SetSensorType;
    property OnValuesChanged: TValuesChangedEvent read FOnValuesChanged write FOnValuesChanged;
  end;

implementation

uses
  System.SysUtils,
  {$IFDEF Android}
  DW.Sensor.Android;
  {$ENDIF Android}
  {$IFDEF iOS}
  Om.Sensor.iOS;
  {$ENDIF iOS}

{ TCustomPlatformSensor }

constructor TCustomPlatformSensor.Create(const ASensor: TSensor);
begin
  inherited Create;
  FSensor := ASensor;
end;

procedure TCustomPlatformSensor.ValuesChanged(const AValues: TSensorValues; const ATimestamp: TDateTime);
begin
  FSensor.ValuesChanged(AValues, ATimestamp);
end;

{ TSensor }

constructor TSensor.Create;
begin
  inherited Create;
  FPlatformSensor := TPlatformSensor.Create(Self);
end;

destructor TSensor.Destroy;
begin
  FPlatformSensor.Free;
  inherited;
end;

function TSensor.GetIsActive: Boolean;
begin
  Result := FPlatformSensor.GetIsActive;
end;

class function TSensor.GetSensorName(const ASensorType: TSensorType): string;
begin
  Result := cSensorNames[ASensorType];
end;

class function TSensor.GetSensorNameType(const ASensorName: string): TSensorType;
var
  LType: TSensorType;
begin
  Result := TSensorType.None;
  for LType := Low(TSensorType) to High(TSensorType) do
  begin
    if ASensorName.ToLower.Equals(cSensorNames[LType].ToLower) then
      Exit(LType);
  end;
end;

function TSensor.GetSensorType: TSensorType;
begin
  Result := FPlatformSensor.FSensorType;
end;

class function TSensor.IsSensorTypeSupported(const ASensorType: TSensorType): Boolean;
begin
  Result := TPlatformSensor.IsSensorTypeSupported(ASensorType);
end;

procedure TSensor.SetIsActive(const Value: Boolean);
begin
  FPlatformSensor.SetIsActive(Value);
end;

procedure TSensor.SetSensorType(const Value: TSensorType);
begin
  FPlatformSensor.SetSensorType(Value);
end;

procedure TSensor.ValuesChanged(const AValues: TSensorValues; const ATimestamp: TDateTime);
begin
  if Assigned(FOnValuesChanged) then
    FOnValuesChanged(Self, AValues, ATimestamp);
end;

end.
