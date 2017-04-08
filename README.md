# BMLPVideoArchiver  

### Description  
BMLP Video Archiver is an iOS app that allows you to simultaneously record and upload video recordings to your personal Google Drive account. Your recordings are also saved to your device.  

This project is being developed for the [Black Movement - Law Project](https://bmlp.org/) to empower individuals and communities in the event of police harassment and provide vital legal evidence for individuals that may be victims of or witnesses to civil rights violations.   

### Basic Functionalities 
#### The first time the user opens the app they're prompted to:
 - Sign in to their Google Drive account to get started  
 - Create a 4-digit passcode to use when ending a recording session  
#### Tap twice anywhere on camera view to begin recording  
* Video files (SD) are saved to the user's photo album and uploaded to their Google Drive account every 30 secs   
* Tap the stop button to end the recording session and save/upload the final portion of the recording  
* The user will be asked to enter their passcode when the stop button is tapped  
* The camera will continue recording until the correct passcode is entered  
#### After 3 incorrect passcode attempts:  
 - Video recording is stopped  
 - Camera changes from rear to front, user-facing  
 - Video begins recording and uploading again immediately  
#### If the app is sent to the background while recording video, the video session is ended and audio recording will begin  
* Audio recording will continue while the app is in the background  
* Audio files (.m4a) are saved and uploaded every 30 secs  
* An audio session will only begin if a video recording is active when the app is sent to the background  
* When the app is brought back to the foreground, the audio session is ended and the video session resumes  
#### A "BMLP Video Archiver Files" folder is created the first time the user uploads a file  
* A dated folder is created within the "BMLP Video Archiver Files" folder, to organize the uploaded files by date  

### Use Cases  
#### Document and de-escalate violence  
* Recording police as they harass community members on the streets or during mass demonstrations has served to de-escalate and deter violent police actions and to ensure they are documented when they do occur.  

#### Avoid loss or unwanted deletion
* Any video that is solely saved on the phone itself is at risk of being deleted by police officers in attempt to cover up their misdoings or being lost should the phone be somehow damaged.  
 
#### Control over your own data  
* Your recordings are saved to your personal Google Drive account, rather than funneling your personal data into anyone else's hands or attempting to gain copyright or other license over it.

### Update 04-2017
This project is now in the process of being updated and rebuilt in Swift in a private repo. It will be made public once the foundation has been laid. If you would like to contribute to the project please don't hesitate to be in contact: JustineBethKay@gmail.com
