unit frmSensorFusionDemo1;   // Test Android sensor fusion: Accelerometer+Magnetometer

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation,
  FMX.StdCtrls, FMX.ListBox, FMX.ScrollBox, FMX.Memo, FMX.Objects,

  DW.Sensor,
  MagnetometerAccelerometerFusion;

type
  TfrmMain = class(TForm)
    rectAccel: TRectangle;
    labAccelX: TLabel;
    labAccelY: TLabel;
    labAccelZ: TLabel;
    labAccelDatetime: TLabel;
    labAccelMS: TLabel;
    Label2: TLabel;
    rectMagnetometer: TRectangle;
    labMagX: TLabel;
    labMagY: TLabel;
    labMagZ: TLabel;
    labMagDatetime: TLabel;
    Label7: TLabel;
    labMagMS: TLabel;
    rectCompass: TRectangle;
    labMagHeading: TLabel;
    Label8: TLabel;
    Label3: TLabel;
    labAltitude: TLabel;
    Label4: TLabel;
    labRoll: TLabel;
    labCardinal: TLabel;
    rectLocation: TRectangle;
    Label5: TLabel;
    labLocLat: TLabel;
    labLocLon: TLabel;
    labLocMagDecl: TLabel;
    labTrueHeading: TLabel;
    labiOSTrueHeading: TLabel;
    labLocationStatus: TLabel;
    procedure FormActivate(Sender: TObject);
  private
    //fussion sensor events
    procedure FusionSensorAccelChanged(Sender:TObject);            //acceleration event
    procedure FusionSensorMagChanged(Sender:TObject);              //magnetic event
    procedure FusionSensorHeadingAltitudeChanged(Sender:TObject);
    procedure updateLocationLabels;
    procedure DoStartSensors;  //combined
  public
    fMagAccelFusion:TMagnetoAccelerometerFusion;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.Permissions,  // permission request for Android
  FMX.DialogService,

  System.DateUtils;


{ TfrmMain }

constructor TfrmMain.Create(AOwner: TComponent);
var
  LSensorType: TSensorType;
begin
  inherited;
  //create sensors

  fMagAccelFusion := TMagnetoAccelerometerFusion.Create(Self);
  fMagAccelFusion.OnAccelerometerChange  := FusionSensorAccelChanged;
  fMagAccelFusion.OnMagnetometerChange   := FusionSensorMagChanged;
  fMagAccelFusion.OnHeadingAltitudeChange:= FusionSensorHeadingAltitudeChanged;
end;

destructor TfrmMain.Destroy;
begin
  fMagAccelFusion.Free;
  inherited;
end;

procedure TfrmMain.DoStartSensors;
{$IFDEF ANDROID} const PermissionAccessFineLocation = 'android.permission.ACCESS_FINE_LOCATION'; {$ENDIF}
begin
{$IFDEF ANDROID}
  PermissionsService.RequestPermissions([PermissionAccessFineLocation],
    procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
    begin
      if (Length(AGrantResults)=1) and (AGrantResults[0]=TPermissionStatus.Granted) then
        fMagAccelFusion.StartStopSensors({bStart:} true )
      else TDialogService.ShowMessage('Location permission not granted');
    end
  );
{$ELSE}  //iOS
   fMagAccelFusion.StartStopSensors({bStart:} true );
{$ENDIF}
end;

procedure TfrmMain.FormActivate(Sender: TObject);
begin
  DoStartSensors;  //activate on start
end;

procedure TfrmMain.FusionSensorAccelChanged(Sender:TObject);
begin
   labAccelDatetime.Text  := FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz',Now);
   labAccelX.Text := Format('x: %.4f', [fMagAccelFusion.fGx]);
   labAccelY.Text := Format('y: %.4f', [fMagAccelFusion.fGy]);
   labAccelZ.Text := Format('z: %.4f', [fMagAccelFusion.fGz]);
   labAccelMS.Text := IntToStr(fMagAccelFusion.fAccelMS)+ ' ms';

  // Limit the updates
  // if (ms<1000) then
  //   begin
  //     SensorMemo.Lines.Add( FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz', ATimestamp) );
  //     for I := 0 to Length(AValues) - 1 do
  //       SensorMemo.Lines.Add(Format('Value %d: %.4f', [I, AValues[I]]));
  //   end;
end;

procedure TfrmMain.FusionSensorMagChanged(Sender:TObject);
begin
   labMagDatetime.Text  := FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz',Now);
   labMagX.Text  := Format('x: %.4f', [fMagAccelFusion.fMx]);
   labMagY.Text  := Format('y: %.4f', [fMagAccelFusion.fMy]);
   labMagZ.Text  := Format('z: %.4f', [fMagAccelFusion.fMz]);
   labMagMS.Text := IntToStr(fMagAccelFusion.fMagMS)+ ' ms';
end;

function courseToDirectionStr(const aCourse:integer):String;  // p.e. 180 --> 'S'
const                            //  0   1    2   3    4   5    6    7   8
  direcoes:array[0..8] of String = ('N','NE','E','SE','S','SW','W','NW','N');
var q:integer;                 //
begin
  q := Round(aCourse/45);    //
  if (q>=0) and (q<=8) then Result:=direcoes[q]
    else Result:=''; //??
end;

procedure TfrmMain.FusionSensorHeadingAltitudeChanged(Sender:TObject);
begin
  labMagHeading.Text  := Format('m: %5.1f°', [fMagAccelFusion.fTCMagHeading]);
  labTrueHeading.Text := Format('t: %5.1f°', [fMagAccelFusion.fTCTrueHeading]);

  labAltitude.Text  := Format('%5.1f°', [fMagAccelFusion.fAltitude] );
  labRoll.Text      := Format('%5.1f°', [fMagAccelFusion.fRoll] );
  if not IsNaN(fMagAccelFusion.fTCTrueHeading) then
    labCardinal.Text  := courseToDirectionStr( Trunc(fMagAccelFusion.fTCTrueHeading) )
    else labCardinal.Text  := '?';

  {$IFDEF IOS}   // on iOS there is this LocationSensor.Sensor.TrueHeading ( that sucks )
  labiOSTrueHeading.Text := 'iOS TH: '+Format('%5.1f°',[fMagAccelFusion.LocationSensor.Sensor.TrueHeading] );
  {$ENDIF IOS}

  updateLocationLabels;
end;

procedure TfrmMain.updateLocationLabels;
begin
  labLocLat.Text     := Format('lat: %6.2f°', [fMagAccelFusion.fLocationLat] );
  labLocLon.Text     := Format('lon: %6.2f°', [fMagAccelFusion.fLocationLon] );
  labLocMagDecl.Text := Format('mag decl: %5.1f°', [fMagAccelFusion.fMagDeclination] );
end;

end.
