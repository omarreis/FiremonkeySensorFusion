# FiremonkeySensorFusion
Accelerometer + Magnetometer + GPS sensor association to calculate rectangular coordinates ( aka azimuth/altitude/roll ).
This can be used to power augmented reality apps for mobile devices. 

Cross platform code ( Android and iOS )

This project uses DelphiWorlds sensor files, by Dave Nottage ( the ones with DW. prefix )

Works as follows:
1. Get GPS position, to calculate Magnetic Declination. Android offers a WMM service for that. iOS seems to have it too, but I worked the magnetic declination from TrueHeading/MagHeading properties of the GPS device. 
2. Get Accelerometer and Magnetometer 3D vectors
3. Calculate tilt compensated rectangular coordinates* by rotating the magnetometer vector with the acceletrometer vector.
4. Apply magnetic declination to obtain True Heading (azimuth)

* (azimuth/altitude/roll or azimuth/elevation/roll or pitch/bank/roll)

For Delphi Firemonkey ( compiled w/ D10.3.1 Rio )

iOS version uses a 100ms timer to get sensor readings. It would be better to use sensor change events, but I don't know how to do that.

Note that iOS GPS sensor has a TrueHeading property, which could be used directly, avoiding all this. But it has a problem when the altitude crosses the 45 degree boundary. The GPS TrueHeading jumps several degrees at that point. My guess is that iOS changes the rectangular coordinates axis when the altitude is more than 45 degrees, which I think is wrong. Not sure.
 
SensorFusionDemo screenshot.

![Screenshot](SensorFusionShot.png)
