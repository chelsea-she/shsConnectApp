# shsConnect Communication App


**general knowledge**
Developed a messenger iOS app to foster communication between 4K+ students and deans.

**Frontend**
We have 4 Login View Controllers
1) Login View Controller
2) Student Registration View Controller
3) Dean Registration View Controller
4) Status View Controller

We have 3 Announcement View Controllers
1) Announcement View Controller of all grades
2) Announcment View Controller for each grade
3) Announcement View Controller for each announcement
4) New Announcment View Controller for faculty to send a new announcement

We have 3 Messaging View Controllers
1) Conversation View Controller of all past conversations
2) Chat View Controller for each conversation
3) New Conversation View Controller to message new students

We have also have a Profile View Controller and Photo Viewer View Controller

We navigate through the profile, conversation, and announcement view controllers through a tab bar

**APNS, Push Ntifications**
When our app loads, XCode/Swift stores our FCM token in User Defaults. (XCode gets the device token from APNS). This then gets pushed and stored in our Firebase Realtime Database under the user’s unique token in the profiles folder.
When a user sends a message, that message gets stored in that unique conversation id under the conversations folder. This triggers the Firebase Cloud Function which is listening on the conversations folder if a message was created (since we wrote an onCreate function that triggers when new data is added to the database under the conversations)
Once triggered, it sends a payload to APNS. (What was inefficient was when we added a message to store in Firebase Realtime Database, we attached a FCM token to each message so it was easy to retrieve when the Firebase Cloud Function was triggered)
The APNS then sends the notification to our app.
		
**How our realtime database was structured**
XCode stores all this information to Firebase Realtime Database and retrieves it to display it in our UI.
When an account is created, all users are stored under profiles folder (each user has a unique user id)
Each announcement sent stored under announcement_grades
Each conversation made has a unique conversation id called “conversation_sender1 email_other users in the groupchat emails_date”
Under each conversation folder there is a messages folder that stores each message sent
In messages, the date, receiver fcm_tokens, unique id, sender email and name, is read boolean, and type is stored
The archive folder is when a conversation is deleted and messages are stored there
The codes folder is the access code to create accounts (since only deans can create accounts)

**User authentication**
In XCode, we create an account (signUp) /sign in (signIn) an existing account using FirebaseAuth 
FirebaseAuth makes sure the text field inputs are valid, then creates a session id so users can stay logged in even when they exit/close out of the app
We push all user information into profiles in realtime database except for password
Automation account creation: 
We have an web app that can upload csv file information to our Firebase Firstore under a collection called “users”
	•	CSV Data Mapping: Iterates over CSV rows, extracting user IDs and associated data (e.g., name, email, password) for each row.
	•	Data Upload: Uses upload_row.run to process and upload each row’s data into Firestore, handling user creation and data storage.
	•	Upload Completion: Employs Promise.all to ensure all data uploads complete successfully, resolving if all operations succeed or rejecting if any fail.
We then have a Firebase function that gets triggered when documents are created under the users collection so that it uses FirebaseAuth to create those accounts
With the additional information (like grade level) the Firebase function stores it in Firebase Realtime database’s profiles folder 

