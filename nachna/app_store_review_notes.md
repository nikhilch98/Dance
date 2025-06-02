# nachna App - App Store Review Notes

## App Overview
**nachna** is a dance workshop discovery and booking platform that connects users with dance artists, studios, and workshops. The app serves the dance community by providing a comprehensive platform to discover, book, and manage dance experiences.

## Demo Account for Testing
**Mobile Number:** 9999999999  
**Password:** test123

This account is specifically created for App Store review purposes and demonstrates all app features including:
- User authentication and profile management
- Workshop discovery and browsing
- Artist and studio exploration
- Profile picture upload/management
- Complete user journey from registration to booking

## Key Features to Test

### 1. User Authentication
- **Registration:** New users can create accounts with mobile number and password
- **Login:** Secure authentication using JWT tokens
- **Profile Setup:** Guided onboarding flow for new users
- **Password Management:** Users can change passwords securely

### 2. Workshop Discovery
- **Browse Workshops:** View all available dance workshops with detailed information
- **Multiple Artists:** Support for workshops with multiple artists (displayed as overlapping avatars)
- **Filtering:** Browse workshops by artist, studio, or date
- **Booking Integration:** Direct links to external booking systems

### 3. Artist Profiles
- **Artist Directory:** Browse all dance artists with profile pictures and information
- **Artist Workshops:** View workshops specific to each artist
- **Social Integration:** Instagram links for artist social media

### 4. Studio Integration
- **Studio Directory:** Discover dance studios with images and information
- **Studio Schedules:** View weekly schedules organized by days
- **Location Information:** Studio details and contact information

### 5. Profile Management
- **Profile Pictures:** Upload, update, and remove profile pictures
- **Personal Information:** Manage name, date of birth, and gender
- **Account Security:** Change passwords and manage account settings
- **Profile Completion:** Track and encourage profile completion

## Technical Implementation

### Backend Architecture
- **Server:** FastAPI Python server hosted at nachna.com
- **Database:** MongoDB for data storage and user management
- **Authentication:** JWT token-based authentication with 30-day expiration
- **Image Storage:** MongoDB GridFS for secure profile picture storage
- **API:** RESTful API with comprehensive endpoints

### Frontend Architecture
- **Framework:** Flutter (Dart) for cross-platform development
- **State Management:** Provider pattern for state management
- **UI Design:** Custom glassmorphism design with gradient backgrounds
- **Image Handling:** Cached network images with fallback support
- **Navigation:** Material Design navigation patterns

### Security Features
- **Password Security:** bcrypt hashing for password storage
- **Token Security:** JWT tokens with expiration and validation
- **Input Validation:** Comprehensive input validation and sanitization
- **Image Security:** File type validation and size limits for uploads
- **HTTPS:** All API communications use HTTPS encryption

## Testing Instructions

### Basic Testing Flow
1. **Launch App:** Open nachna app and verify smooth loading
2. **Login:** Use demo account (9999999999/test123) to login
3. **Profile Setup:** Complete profile information and upload profile picture
4. **Browse Workshops:** Navigate through workshop listings and view details
5. **Explore Artists:** Browse artist profiles and view their workshops
6. **Discover Studios:** Explore studio listings and schedules
7. **Profile Management:** Test profile editing and picture management

### Advanced Testing
1. **Registration:** Test new account creation with unique mobile number
2. **Error Handling:** Test invalid inputs and network error scenarios
3. **Image Upload:** Test various image formats and sizes
4. **External Links:** Test payment and Instagram link redirections
5. **Navigation:** Test all navigation flows and back button behavior

## Expected Behaviors

### Successful Operations
- Smooth app launch and navigation
- Successful login with demo credentials
- Profile picture upload and display
- Workshop data loading and display
- External link redirections working properly

### Error Handling
- Clear error messages for invalid inputs
- Graceful handling of network issues
- Appropriate loading states during operations
- User-friendly error messages

## Data and Privacy

### Data Collection
- User registration information (mobile number, password)
- Profile information (name, date of birth, gender)
- Profile pictures (stored securely in MongoDB)
- Usage analytics for app improvement

### Data Usage
- User authentication and account management
- Personalized workshop recommendations
- Profile display and social features
- Administrative functions for content management

### Data Security
- All passwords are hashed using bcrypt
- JWT tokens for secure authentication
- Profile pictures stored in encrypted MongoDB collections
- HTTPS encryption for all API communications

### Privacy Compliance
- Clear privacy policy available at nachna.com/privacy-policy
- Terms of service available at nachna.com/terms-of-service
- GDPR compliance for data protection
- User control over profile data and pictures

## Content Guidelines

### User-Generated Content
- Profile pictures must be appropriate and non-offensive
- User names and profile information must be accurate
- No spam, harassment, or inappropriate content allowed

### Workshop Content
- All workshop information is curated by administrators
- Artist and studio information is verified and updated regularly
- Payment links are validated for security and functionality
- Content is regularly reviewed and moderated

## External Integrations

### Payment Systems
- Workshop booking redirects to external payment providers
- No payment processing within the app itself
- Secure redirection to verified booking systems

### Social Media
- Instagram integration for artist and studio profiles
- External links open in system browser
- No in-app social media posting or sharing

## Performance Considerations

### App Performance
- Cold start time under 3 seconds
- Smooth navigation and transitions
- Efficient image loading and caching
- Minimal memory usage and no memory leaks

### Network Performance
- Efficient API calls with caching
- Graceful handling of slow connections
- Appropriate loading states and error handling
- Optimized image delivery

## Known Limitations

### Current Limitations
- App requires internet connection for all features
- Payment processing handled by external providers
- Image uploads limited to 5MB
- Admin features require special permissions

### Future Enhancements
- Offline mode for basic browsing
- Push notifications for workshop updates
- Enhanced search and filtering options
- Social features for user interaction

## Support Information

### Developer Contact
- **Name:** Nikhil Chatragadda
- **Email:** Nikhil.ch1430@gmail.com
- **Phone:** +91 8985374940

### App Support
- **Website:** https://nachna.com
- **Privacy Policy:** https://nachna.com/privacy-policy
- **Terms of Service:** https://nachna.com/terms-of-service
- **API Documentation:** Available for technical review

## Compliance and Guidelines

### App Store Guidelines
- App follows all iOS Human Interface Guidelines
- No use of private APIs or undocumented features
- Proper handling of user data and privacy
- Appropriate content rating (4+)
- No in-app purchases or subscriptions

### Legal Compliance
- Privacy policy clearly outlines data usage
- Terms of service define user responsibilities
- GDPR compliance for data protection
- Age-appropriate content and features
- No copyrighted content without permission

## Review Process Notes

### What Reviewers Should Expect
1. **Functional App:** All features work as described
2. **Real Data:** App connects to live backend with real workshop data
3. **External Links:** Payment and social media links redirect externally
4. **Demo Account:** Provided account demonstrates all features
5. **Professional Design:** Polished UI with consistent design language

### Common Review Concerns Addressed
1. **User Data:** Clear privacy policy and secure data handling
2. **External Links:** Legitimate business integrations for booking
3. **Content Moderation:** Administrative controls for content management
4. **Performance:** Optimized for smooth iOS performance
5. **Functionality:** All features work as intended

### Additional Documentation
- Comprehensive API documentation available
- Technical architecture documentation provided
- Testing guides and procedures included
- Privacy and security documentation available

---

**Document Version:** 1.0  
**Last Updated:** January 2024  
**Prepared for:** App Store Connect Review Process  
**Contact:** Nikhil Chatragadda (Nikhil.ch1430@gmail.com) 