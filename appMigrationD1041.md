# updating apps for stores (D10.3.3 to D10.4.1)
tips after updating 4 apps ( nov/20 )

* LocationSensor not working for iOS if activated from FormActivate.
  workaround:Used a timer to defer sensor start
* Sensors (gyro,mag) events for Android leak memory. wa: call Free for sensor vector during the event  
 (thanks Dave Nottage)
* WebBrowser component crashes on start on iOS.  Must preload WebKit (thanks Yaroslav)  
* TCameraComponent doesn't work for Android ( permissions related )
* dark theme for iOS messes with edits (changes bg color so that it is black text over black bg).
  workaround: added key UIUserInterfaceStyle=Light to iOS version info
* update old projects for iOS: file info.plist.TemplateiOS.xml.
  Add <%StoryboardInfoPListKey%> after <%ExtraInfoPListKeys%> 
* update old projects for Android: AndroidManifest.template.xml - made a diff with a new project.
* iOS: Add splash screens PNG for dark and light modes ( 2x and 3x )
* Deployment iOS: Click "Revert to default" to modernize deployment list ( [x] Keep added files )
* Deployment iOS: Add a xxx1024.png icon to folder .\   ( needed for app store )
* Android: project options. Update compiler options. Generate bundle .aab file ( 32b and 64b combination )
* iOS: Deploy for App Store and use Mosco to fix storyboard assets (thanks Dave Nottage)
