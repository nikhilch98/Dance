# nachna App - Testing Guide for App Store Review

## Quick Start Testing

### Demo Account Credentials
- **Mobile Number:** `9999999999`
- **Password:** `test123`

This account is specifically created for App Store review and testing purposes.

## Complete Testing Flow

### 1. App Launch and Initial Setup

#### First Launch
1. Open the nachna app
2. You'll see the login/register screen with glassmorphism design
3. The app should load smoothly with gradient backgrounds

#### Registration Testing (Optional)
1. Tap "Register" if you want to test new account creation
2. Enter a unique mobile number (10 digits)
3. Enter a password (minimum 6 characters)
4. Tap "Register"
5. You should receive a success message and be logged in

#### Login Testing (Recommended)
1. Tap "Login" on the main screen
2. Enter mobile number: `9999999999`
3. Enter password: `test123`
4. Tap "Login"
5. You should be successfully logged in

### 2. Profile Setup Flow

#### Initial Profile Setup
1. After login, you'll be taken to the profile setup screen
2. Fill in the following test information:
   - **Name:** Test User
   - **Date of Birth:** 1990-01-01 (or any valid date)
   - **Gender:** Select any option (Male/Female/Other)
3. Tap "Save Profile"
4. You should see a success message

#### Profile Picture Testing
1. On the profile setup screen, tap the camera icon on the profile picture
2. Choose "Camera" or "Gallery" from the dialog
3. Select any image from your device
4. The image should upload and display as your profile picture
5. You can also test "Remove Photo" option

### 3. Main App Navigation

#### Bottom Navigation
The app has 4 main tabs:
1. **Workshops** - Browse all dance workshops
2. **Artists** - Explore dance artists
3. **Studios** - Discover dance studios
4. **Profile** - Manage your account

### 4. Workshop Discovery Testing

#### Browse All Workshops
1. Tap on "Workshops" tab
2. You should see a list of dance workshops with:
   - Artist photos (single or multiple overlapping)
   - Workshop details (song, date, time)
   - Studio information
   - Register buttons
3. Scroll through the list to see various workshops

#### Workshop Details
1. Each workshop card shows:
   - Artist name(s) (may show "Artist 1 X Artist 2" for multiple artists)
   - Song name
   - Date and time
   - Studio name
   - Pricing information
2. Tap "Register" to test payment link redirection (external link)

### 5. Artist Exploration Testing

#### Browse Artists
1. Tap on "Artists" tab
2. You should see a grid/list of dance artists
3. Each artist shows:
   - Profile picture
   - Artist name
   - Instagram link (if available)

#### Artist Workshops
1. Tap on any artist
2. You should see workshops specific to that artist
3. Workshops are sorted by date
4. Test the back navigation

### 6. Studio Discovery Testing

#### Browse Studios
1. Tap on "Studios" tab
2. You should see a list of dance studios
3. Each studio shows:
   - Studio image
   - Studio name
   - Instagram link

#### Studio Schedule
1. Tap on any studio
2. You should see the studio's workshop schedule
3. Schedule is organized by:
   - **This Week:** Daily breakdown (Monday-Sunday)
   - **Future Workshops:** Upcoming workshops beyond this week
4. Test navigation between different days

### 7. Profile Management Testing

#### View Profile
1. Tap on "Profile" tab
2. You should see your profile with:
   - Profile picture (if uploaded)
   - User information
   - Member since date
   - Profile completion status

#### Edit Profile
1. Tap the edit icon (pencil) in the top right
2. You can modify:
   - Name
   - Date of birth
   - Gender
3. Save changes and verify they persist

#### Change Password
1. In profile section, tap "Change Password"
2. Enter current password: `test123`
3. Enter a new password
4. Confirm the change
5. Test login with new password

#### Profile Picture Management
1. Tap the camera icon on your profile picture
2. Test uploading a new image
3. Test removing the current image
4. Verify changes are reflected immediately

### 8. Admin Features Testing (If Admin Access)

#### Admin Dashboard Access
1. If the test account has admin privileges, you'll see admin options
2. Access the admin dashboard through the profile menu

#### Workshop Management
1. View workshops missing artist assignments
2. View workshops missing song information
3. Test assigning artists to workshops
4. Test assigning songs to workshops

### 9. Error Handling Testing

#### Network Connectivity
1. Test app behavior with poor internet connection
2. App should show appropriate loading states
3. Error messages should be user-friendly

#### Invalid Inputs
1. Test login with incorrect credentials
2. Test registration with invalid mobile numbers
3. Test profile updates with invalid data
4. App should show clear error messages

#### Image Upload Errors
1. Test uploading very large images (>5MB)
2. Test uploading non-image files
3. App should show appropriate error messages

### 10. UI/UX Testing

#### Design Consistency
1. Verify glassmorphism design throughout the app
2. Check gradient backgrounds and blur effects
3. Ensure consistent color scheme (cyan to purple gradients)
4. Verify smooth animations and transitions

#### Responsive Design
1. Test on different screen sizes
2. Verify text scaling and layout adaptation
3. Check safe area handling (notch, home indicator)

#### Accessibility
1. Test with VoiceOver enabled
2. Verify proper contrast ratios
3. Check touch target sizes

### 11. Performance Testing

#### App Launch Time
1. Cold start should be under 3 seconds
2. Warm start should be under 1 second

#### Image Loading
1. Profile pictures should load smoothly
2. Artist and studio images should cache properly
3. No memory leaks during image operations

#### Navigation Performance
1. Tab switching should be instant
2. Screen transitions should be smooth
3. List scrolling should be fluid

## Expected Behaviors

### Successful Operations
- Login/logout should work seamlessly
- Profile updates should save and persist
- Image uploads should process and display correctly
- Workshop data should load and display properly
- Navigation should be smooth and responsive

### Error Scenarios
- Invalid login shows "Invalid mobile number or password"
- Network errors show "Please check your internet connection"
- Image upload errors show specific error messages
- Form validation shows clear field-specific errors

## Common Issues and Solutions

### Login Issues
- **Problem:** Can't login with demo account
- **Solution:** Ensure mobile number is exactly `9999999999` and password is `test123`

### Image Upload Issues
- **Problem:** Profile picture won't upload
- **Solution:** Ensure image is under 5MB and is a valid image format (JPG, PNG)

### Network Issues
- **Problem:** App shows loading indefinitely
- **Solution:** Check internet connection and restart app if needed

### Navigation Issues
- **Problem:** Back button not working
- **Solution:** Use system back gesture or navigation bar

## Testing Checklist

### Core Functionality
- [ ] App launches successfully
- [ ] Login with demo account works
- [ ] Profile setup completes
- [ ] Profile picture upload works
- [ ] Workshop browsing works
- [ ] Artist exploration works
- [ ] Studio discovery works
- [ ] Navigation between tabs works
- [ ] Profile management works

### Advanced Features
- [ ] Multiple artist display works
- [ ] Payment link redirection works
- [ ] Instagram link integration works
- [ ] Search and filtering works
- [ ] Admin features work (if applicable)

### Quality Assurance
- [ ] No crashes during normal usage
- [ ] Error messages are clear and helpful
- [ ] UI is consistent and polished
- [ ] Performance is smooth and responsive
- [ ] Memory usage is reasonable

## Support Information

If you encounter any issues during testing:

- **Developer:** Nikhil Chatragadda
- **Email:** Nikhil.ch1430@gmail.com
- **Phone:** +91 8985374940
- **App Website:** https://nachna.com

## Notes for Reviewers

1. **Demo Account:** The provided demo account (9999999999/test123) is specifically created for review purposes and demonstrates all app features.

2. **External Links:** Payment links redirect to external booking systems (this is expected behavior).

3. **Real Data:** The app connects to a live backend with real workshop, artist, and studio data.

4. **Admin Features:** Some features may require admin privileges. The demo account may or may not have admin access.

5. **Image Storage:** Profile pictures are stored securely in MongoDB and served through the app's API.

6. **Performance:** The app is optimized for smooth performance on iOS devices.

---

**Document Version:** 1.0  
**Last Updated:** January 2024  
**Prepared for:** App Store Connect Review Process 