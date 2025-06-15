# nachna App - App Store Review Documentation

## App Overview
**App Name:** nachna  
**Version:** 1.0.0  
**Category:** Health & Fitness  
**Platform:** iOS  
**Developer:** Nikhil Chatragadda  

## App Description
nachna is a dance workshop discovery and booking platform that connects users with dance artists, studios, and workshops. The app provides a comprehensive platform for the dance community to discover, book, and manage dance experiences.

## Key Features

### 1. Workshop Discovery
- Browse dance workshops by date, artist, or studio
- View detailed workshop information including songs, pricing, and schedules
- Filter workshops by various criteria
- Real-time workshop availability

### 2. Artist Profiles
- Explore profiles of dance artists
- View artist portfolios and upcoming workshops
- Follow favorite artists
- Instagram integration for artist social media

### 3. Studio Integration
- Discover dance studios with detailed information
- View studio schedules organized by week
- Direct booking through integrated payment systems
- Location and contact information

### 4. User Profile Management
- Secure user registration and authentication
- Profile setup with personal information
- Profile picture upload and management
- Password management and security

### 5. Admin Dashboard
- Workshop management for administrators
- Artist assignment to workshops
- Missing data management
- Content moderation tools

## Technical Architecture

### Backend
- **Server:** FastAPI Python server
- **Database:** MongoDB for data storage
- **Authentication:** JWT token-based authentication
- **Image Storage:** MongoDB GridFS for profile pictures
- **API:** RESTful API with comprehensive endpoints

### Frontend
- **Framework:** Flutter (Dart)
- **State Management:** Provider pattern
- **UI Design:** Custom glassmorphism design system
- **Navigation:** Material Design navigation patterns
- **Image Handling:** Cached network images with fallbacks

### Security Features
- Secure password hashing using bcrypt
- JWT token authentication with 30-day expiration
- Input validation and sanitization
- Secure image upload with file type validation
- HTTPS-only API communication

## User Authentication Flow

### Registration Process
1. User enters mobile number and password
2. Server validates input and creates account
3. Password is securely hashed using bcrypt
4. JWT token is generated and returned
5. User is redirected to profile setup

### Login Process
1. User enters mobile number and password
2. Server validates credentials
3. JWT token is generated and returned
4. User gains access to app features

### Profile Setup
1. User completes profile information (name, date of birth, gender)
2. Optional profile picture upload
3. Profile completion status is tracked
4. Users can update profile information anytime

## Demo Account Information
**Mobile Number:** 9999999999  
**Password:** test123  
**User ID:** 683cdbb39caf05c68764cde4  
**Profile Status:** Incomplete (for testing profile setup flow)

This test account demonstrates:
- Login/logout functionality
- Profile setup and completion flow
- Profile picture upload/removal
- Workshop browsing and discovery
- Artist and studio exploration

## API Endpoints

### Authentication Endpoints
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/auth/profile` - Get user profile
- `PUT /api/auth/profile` - Update user profile
- `PUT /api/auth/password` - Change password
- `POST /api/auth/profile-picture` - Upload profile picture
- `DELETE /api/auth/profile-picture` - Remove profile picture

### Workshop Endpoints
- `GET /api/workshops` - Get all workshops
- `GET /api/workshops_by_artist/{artist_id}` - Get workshops by artist
- `GET /api/workshops_by_studio/{studio_id}` - Get workshops by studio

### Artist & Studio Endpoints
- `GET /api/artists` - Get all artists
- `GET /api/studios` - Get all studios

### Admin Endpoints
- `GET /admin/api/missing_artist_sessions` - Get workshops missing artists
- `PUT /admin/api/workshops/{uuid}/assign_artist` - Assign artists to workshops
- `GET /admin/api/missing_song_sessions` - Get workshops missing songs
- `PUT /admin/api/workshops/{uuid}/assign_song` - Assign songs to workshops

## Data Models

### User Profile
```json
{
  "user_id": "string",
  "mobile_number": "string",
  "name": "string (optional)",
  "date_of_birth": "string (optional)",
  "gender": "string (optional)",
  "profile_picture_url": "string (optional)",
  "profile_complete": "boolean",
  "is_admin": "boolean",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### Workshop
```json
{
  "uuid": "string",
  "payment_link": "string", 
   "payment_link_type": "string",
  "studio_id": "string",
  "studio_name": "string",
  "artist_id_list": ["string"],
  "artist_image_urls": ["string"],
  "song": "string",
  "pricing_info": "string",
  "date": "string",
  "time": "string",
  "event_type": "string"
}
```

## Privacy and Data Protection

### Data Collection
- User registration information (mobile number, password)
- Profile information (name, date of birth, gender)
- Profile pictures (stored securely in MongoDB)
- Workshop booking preferences and history

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
- Input validation and sanitization

### Data Retention
- User accounts remain active until deletion is requested
- Profile pictures can be removed by users at any time
- Workshop data is maintained for historical purposes
- Logs are rotated and cleaned regularly

## Content Guidelines

### User-Generated Content
- Profile pictures must be appropriate and non-offensive
- User names and profile information must be accurate
- No spam, harassment, or inappropriate content allowed

### Workshop Content
- All workshop information is curated by administrators
- Artist and studio information is verified
- Payment links are validated for security
- Content is regularly reviewed and updated

## Testing Instructions

### Basic App Flow Testing
1. **Registration/Login:**
   - Use demo account: 9999999999 / test123
   - Test registration with new mobile number
   - Verify JWT token authentication

2. **Profile Management:**
   - Complete profile setup flow
   - Upload/remove profile picture
   - Update profile information
   - Change password

3. **Workshop Discovery:**
   - Browse all workshops
   - Filter by artist or studio
   - View workshop details
   - Test payment link redirection

4. **Artist/Studio Exploration:**
   - Browse artist profiles
   - View artist workshops
   - Explore studio schedules
   - Test Instagram link integration

### Admin Features Testing
1. **Admin Access:**
   - Login with admin account
   - Access admin dashboard
   - View missing data reports

2. **Content Management:**
   - Assign artists to workshops
   - Assign songs to workshops
   - Search and filter functionality

## Known Issues and Limitations

### Current Limitations
- App requires internet connection for all features
- Payment processing is handled by external providers
- Image uploads are limited to 5MB
- Admin features require special permissions

### Planned Improvements
- Offline mode for basic browsing
- Push notifications for workshop updates
- Enhanced search and filtering options
- Social features for user interaction

## Support and Contact Information

### Developer Contact
- **Name:** Nikhil Chatragadda
- **Email:** Nikhil.ch1430@gmail.com
- **Phone:** +91 8985374940

### App Support
- **Website:** https://nachna.com
- **Privacy Policy:** https://nachna.com/privacy-policy
- **Terms of Service:** https://nachna.com/terms-of-service

### Technical Support
- **API Base URL:** https://nachna.com/api
- **Server Status:** Monitored 24/7
- **Database:** MongoDB Atlas (cloud-hosted)
- **CDN:** Integrated for image delivery

## Compliance and Legal

### App Store Guidelines Compliance
- App follows all iOS Human Interface Guidelines
- No use of private APIs or undocumented features
- Proper handling of user data and privacy
- Appropriate content rating (4+)

### Legal Compliance
- Privacy policy clearly outlines data usage
- Terms of service define user responsibilities
- GDPR compliance for data protection
- Age-appropriate content and features

## Version History

### Version 1.0.0 (Current)
- Initial release
- Core workshop discovery features
- User authentication and profiles
- Artist and studio integration
- Admin dashboard
- Profile picture management

### Planned Updates
- Version 1.1.0: Push notifications
- Version 1.2.0: Social features
- Version 1.3.0: Offline mode
- Version 2.0.0: Enhanced UI/UX

---

**Document Version:** 1.0  
**Last Updated:** January 2024  
**Prepared for:** App Store Connect Review Process 