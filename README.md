![Banner](AirlinerAttitudeBanner.png)

# FiremonkeySensorFusion

*TMagnetoAccelerometerFusion* object combines phone sensor output from:

* Magnetometer
* Accelerometer
* GPS 
 
to obtain the *phone attitude* vector. This is the direction the phone is pointing and the rotation in relation to vertical. 
The object calculates phone's *rectangular coordinates*. This can be used to power *augmented reality* apps for mobile devices. 
Many names for rectangular coordinates: azimuth/altitude/roll or heading/elevation/roll or pitch/bank/roll. You choose.

        phone attitude - rectangular coordinates
           -Y     Z       altitude X 
            |    /        heading  Y 
            |   /         roll     Z   
        /===+===\\                     ( Y points down, Z points inside the screen )
        |   | / ||
        |   |/  ||
        |   *---|---------- X
        |       ||
        |   O   ||
        \-------//

Cross platform Delphi Object Pascal for Android and iOS. No Windows support at this time.

What the object does:

1. Get GPS position and calculate Magnetic Declination. Android offers a WMM service for that. iOS seems to have it too, but I couldn't find. for iOS I worked the magnetic declination from TrueHeading/MagHeading properties of the GPS device. 
Note that GPS coordinates are used only for the purpose of magnetic declination calculation (once per session). 
2. Get Accelerometer and Magnetometer 3D vectors
3. Calculate tilt compensated coordinates by rotating the magnetometer vector with the accelerometer vector. 
This results in the magnetic vector in relation to the phone.
4. Project the vector to horizontal to obtain Magnetic Heading.
5. Apply magnetic declination to heading to obtain True Heading (a.k.a Azimuth)
6. Phone attitude changes are returned to user code on OnHeadingAltitudeChange event. User app has to implement this. 

# Current code status

* tested w/ Delphi 11.1 on iOS and Android. Fixed sensor permission request for Android (aug/22)
* tested w/ Delphi 10.4.2 on iOS and Android (jun/22)
* Included patch to System.Android.Sensors.pas with DelphiWorlds Mosco by Dave Nottage. This fixes startup crash on Android 11/12. 
* For Android, uses DelphiWorlds sensor code (from KastriFree lib). Files with DW. prefix.
* For iOS, using XCode 13. DelphiWorlds Mosco used to build the IPA.
* This object currently powers apps "*CamSextant*" and "*PlanetFun*", available from AppStore and Google Play. Free.
* Tags: #delphi #firemonkey #sensors #Sensorfusion #pascal

# Implementation notes:
iOS version uses a 100ms timer to get sensor readings. It would be better to use sensor change events, but I don't know how to do that.

Android version uses native sensor code ( from DelphiWorlds ). Delphi TLocationSensor is also used.
Recent changes to both Android and iOS requires explicit permision before starting the GPS sensor.

Note that iOS GPS sensor has a TrueHeading property, which could be used directly, avoiding all this. But it has a problem when the altitude crosses the 45 degree boundary. The GPS TrueHeading jumps several degrees at that point. My guess is that iOS changes the rectangular coordinates axis when the altitude is more than 45 degrees, which I think is wrong. Not sure.

In versions before D10.3.3 used a hack to pass int64 via JNI on Android (Delphi JNI had some endian problem  ).
This was commented when the compiler was corrected. Watch if using previous Delphi versions ( i.e. uncomment the hack )
On D10.4.1 it seems the bug is back, so the hack was reintroduced :|
update: dez20: As of D10.4.1 Sydney, the work around is required for Android 32 bits. Source updated to fix this.

## Usage

* TMagnetoAccelerometerFusion is not a component, o need to install it as a package.  It is instanced at run-time.
* Add unit to uses:  MagnetometerAccelerometerFusion  
* Add form variable:  fMagAccelFusion:TMagnetoAccelerometerFusion;
* On FormCreate:

      fMagAccelFusion := TMagnetoAccelerometerFusion.Create(Self);
      // fMagAccelFusion.OnAccelerometerChange  := FusionSensorAccelChanged;          // optional sensor events
      // fMagAccelFusion.OnMagnetometerChange   := FusionSensorMagChanged;
      fMagAccelFusion.OnHeadingAltitudeChange:= FusionSensorHeadingAltitudeChanged;   // combined sensor change handler
    
* Implement sensor handler:  

      procedure TfrmMain.FusionSensorHeadingAltitudeChanged(Sender:TObject);
      begin
        // in this sample just show rectagular coordinates
        labMagHeading.Text  := Format('m: %5.1f°', [fMagAccelFusion.fTCMagHeading]);     
        labTrueHeading.Text := Format('t: %5.1f°', [fMagAccelFusion.fTCTrueHeading]);
        labAltitude.Text    := Format('%5.1f°',    [fMagAccelFusion.fAltitude] );
        labRoll.Text        := Format('%5.1f°',    [fMagAccelFusion.fRoll] );
        ....
        ...
        
* On FormActivate: Start sensors. For Android, you have to ask permission to use the sensors and start when permissions are granted. On iOS starting sensors from FormActivate didn't work. Instead I started from a timer. Note that the sample application doesn't start the sensors this way. User have to manually start using using the checkbox.
 
      procedure TfrmMain.timerStartSensorsiOSTimer(Sender: TObject);  // iOS deferred start timer
      begin
        fMagAccelFusion.StartStopSensors({bStart:} true );  //start ios sensor feed
        timerStartSensorsiOS.Enabled := false;              //once
      end;
  
      procedure TfrmMain.FormActivate(Sender: TObject);
      begin
        {$IFDEF Android}  // request permissions to start sensor
          const PermissionAccessFineLocation = 'android.permission.ACCESS_FINE_LOCATION';
          PermissionsService.RequestPermissions([PermissionAccessFineLocation],
             procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
             begin
               if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
                 fMagAccelFusion.StartStopSensors( true )     // bStart=true
                 else TDialogService.ShowMessage('Location permission not granted');
          end)
        {$ENDIF Android}
    
        {$IFDEF IOS}
        // for IOS I found u cannot start LocationSensor from FormActivate or the sensor breaks
        // used a Timer to defer sensor start a couple seconds
        timerStartSensorsiOS.Enabled := true;
        {$ENDIF IOS}
        ...
      end; 
  
For iOS on Delphi 10.4.1 you cannot start the location sensor from FormActivate (I don't know why. Nopt sure about D11.1). 
Fixed that by activating the sensors from a 2 seconds TTimer.  
On Android, one must ask for permission to use sensors. 
* Add *System.Permissions* to *uses*

        procedure TfrmMain.timerStartSensorsiOSTimer(Sender: TObject);
        begin
           fMagAccelFusion.StartStopSensors({bStart:} true );  //start ios sensor feed
           timerStartSensorsiOS.Enabled := false;              //once
        end;
        
        procedure TfrmMain.FormActivate(Sender: TObject);
        begin
          {$IFDEF Android}      // request permissions to use sensors
          const PermissionAccessFineLocation = 'android.permission.ACCESS_FINE_LOCATION';
          PermissionsService.RequestPermissions([PermissionAccessFineLocation],
             procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
               begin
                 if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
                   fMagAccelFusion.StartStopSensors({bStart:} true )
                   else TDialogService.ShowMessage('Location permission not granted');
             end)
          {$ENDIF Android}
          
          {$IFDEF IOS}   // for IOS u cannot start LocationSensor from FormActivate (sensor breaks)
          // used a Timer to defer sensor start a couple seconds
          timerStartSensorsiOS.Enabled := true;
          {$ENDIF IOS}
        end; 
        
* It is good practice to disable the sensors when the app goes to background (Home btn) and enable when it comes back.      

## Samples
* SensorFusionDemo1 - Simple usage sample in this repository.
* BoatAttitude - A more elaborate sample. A boat 3d model is targeted by a camera controlled by phone attitude. Can be found at https://github.com/omarreis/BoatAttitude . The app illustrates how to use *quaternions* to set 3d object rotations, instead of manipulating RotationAngle. 
* Also in the same repository: sample *AirlinerAttitude* features an 3d airplane model, for the aviation inclined.
.

## SensorFusionDemo1 screenshot.

![Screenshot](SensorFusionShot.png)

## Apps that use FiremonkeySensorFusion 
For iOS and Android. Search for:

* "CamSextant" - Phone sextant with celestial calculator. Simplest celestial navigation solution.
* "PlanetFun" - 4D Solar System model. Can be attached to the phone sensors. Uses actual planet ephemeris data ( from VSOP 2013 )
* "OPYC" - Sailing game. Steer the boat with the phone.
