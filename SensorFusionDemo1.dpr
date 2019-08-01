program SensorFusionDemo1;

uses
  System.StartUpCopy,
  FMX.Forms,
  frmSensorFusionDemo1 in 'frmSensorFusionDemo1.pas' {frmMain},
  MagnetometerAccelerometerFusion in 'MagnetometerAccelerometerFusion.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
