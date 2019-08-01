# FiremonkeySensorFusion
Accelerometer + Magnetormeter + GPS sensor association to calculate rectangular coordinates ( azimuth/altitude/roll ).
This can be used to power augmented reality apps for mobile devices.

Cross platform code ( Android and iOS )

Uses DelphiWorlds files, by Dave Nottage ( the ones with DW prefix )

Works as follows:
1. Get GPS position, to calculate Magnetic Declination
2. Get Accelerometer and Magnetometer 3D vectors
3. Calculate tilt compensated rectangular coordinates ( azimuth/altitude/roll or azimuth/elevation/roll or pitch/bank/roll )
4. Apply magnetic declination to obtain True Heading (azimuth)

For Delphi Firemonkey ( compiled w/ D10.3.1 Rio )
 
![Screenshot](SensorFusionShot.png)
