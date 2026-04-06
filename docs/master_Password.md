Hello AI, I want to implement a **master password protection** feature for my Flutter app "Raseed" (Offline accounting app for small merchants). 

Requirements:

1️⃣ The app must require a **single master password** to open. 
   - Only the owner knows this password.
   - If the app is installed on another device, it cannot be used without this password.

2️⃣ Behavior:
   - On first launch, show a **Master Password Entry Screen**.
   - If the entered password is correct, allow access to Dashboard.
   - If incorrect, deny access and optionally show a warning.
   - The password is numeric or alphanumeric, fixed for the app.

3️⃣ Technical Details:
   - Store the master password **securely and encrypted** inside the app.
   - Use `flutter_secure_storage` or encryption package.
   - App is fully Offline.
   - Ensure the password is checked **before any screen is shown**.
   - Clean code, ready to integrate with existing Flutter app.

4️⃣ Deliverables:
   - Flutter code for Master Password Entry Screen.
   - Validation logic against the stored encrypted password.
   - Comments explaining where to integrate with the Dashboard.
   - Prevent usage if the password is incorrect.