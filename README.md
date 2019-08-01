# FiremonkeySensorFusion
Accelerometer + Magnetormeter + GPS sensor association to calculate rectangular coordinates ( azimuth/altitude/roll ).
This can be used to power augmented reality apps for mobile devices.

Cross platform code ( Android and iOS )

This project uses DelphiWorlds files, by Dave Nottage ( the ones with DW prefix )

Works as follows:
1. Get GPS position, to calculate Magnetic Declination. Android offers a WMM service for that. iOS seems to have it too, but I worked the magnetic declination indirectly from TrueHeading/MagHeading properties of the GPS device. Note that iOS GPS sensor has a TrueHeading property, but it has a problem when the altitude crosses the 45 degree boundary (the TrueHeading changes several degrees at that point)
2. Get Accelerometer and Magnetometer 3D vectors
3. Calculate tilt compensated rectangular coordinates (azimuth/altitude/roll or azimuth/elevation/roll or pitch/bank/roll)
4. Apply magnetic declination to obtain True Heading (azimuth)

For Delphi Firemonkey ( compiled w/ D10.3.1 Rio )
 
![Screenshot](SensorFusionShot.png)
