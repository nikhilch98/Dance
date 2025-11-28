"""Web routes for serving static pages."""

from typing import Optional
from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from app.database.workshops import DatabaseOperations
from app.services.auth import verify_admin_user, verify_token

router = APIRouter()
templates = Jinja2Templates(directory="templates")

# Bundle template data (in production, this would come from database)
BUNDLE_TEMPLATES = {
    "WEEKEND_001": {
        "template_id": "WEEKEND_001",
        "name": "Weekend Dance Package",
        "description": "3 workshops this weekend - Save ₹500!",
        "workshops": [
            {"name": "Bollywood Basics", "date": "Sep 21", "time": "3-5 PM", "instructor": "Amisha"},
            {"name": "Hip Hop Moves", "date": "Sep 21", "time": "5-7 PM", "instructor": "Kiran"},
            {"name": "Contemporary Dance", "date": "Sep 22", "time": "10 AM-12 PM", "instructor": "Priya"}
        ],
        "bundle_price": 2500,
        "individual_prices": [999, 999, 999],
        "savings": 500,
        "currency": "INR",
        "image": "/static/assets/bundles/weekend.jpg",
        "valid_until": "2024-09-20"
    },
    "SERIES_001": {
        "template_id": "SERIES_001",
        "name": "Bollywood Dance Series",
        "description": "4-week intensive Bollywood dance series",
        "workshops": [
            {"name": "Bollywood Week 1", "date": "Sep 23", "time": "6-8 PM", "instructor": "Amisha"},
            {"name": "Bollywood Week 2", "date": "Sep 30", "time": "6-8 PM", "instructor": "Amisha"},
            {"name": "Bollywood Week 3", "date": "Oct 7", "time": "6-8 PM", "instructor": "Amisha"},
            {"name": "Bollywood Week 4", "date": "Oct 14", "time": "6-8 PM", "instructor": "Amisha"}
        ],
        "bundle_price": 4000,
        "individual_prices": [1200, 1200, 1200, 1200],
        "savings": 800,
        "currency": "INR",
        "image": "/static/assets/bundles/series.jpg",
        "valid_until": "2024-09-20"
    }
}

# Constants for Apple App Site Association (Universal Links)
APPLE_TEAM_ID = "TJ9YTH589R"
IOS_BUNDLE_ID = "com.nachna.nachna"


@router.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the home page."""
    return templates.TemplateResponse("website/marketing.html", {"request": request})


@router.get("/marketing", response_class=HTMLResponse)
async def marketing(request: Request):
    """Serve the marketing page."""
    return templates.TemplateResponse("website/marketing.html", {"request": request})


@router.get("/privacy-policy", response_class=HTMLResponse)
async def privacy_policy(request: Request):
    """Serve the privacy policy page."""
    return templates.TemplateResponse("website/privacy_policy.html", {"request": request})


@router.get("/terms-of-service", response_class=HTMLResponse)
async def terms_of_service(request: Request):
    """Serve the terms of service page."""
    return templates.TemplateResponse("website/terms_of_service.html", {"request": request})


@router.get("/support", response_class=HTMLResponse)
async def support(request: Request):
    """Serve the support page."""
    return templates.TemplateResponse("website/support.html", {"request": request})


@router.get("/ai", response_class=HTMLResponse)
async def ai_analyzer_page(request: Request):
    """Serve the AI analyzer page."""
    return templates.TemplateResponse("website/ai_analyzer.html", {"request": request})


# --- Apple App Site Association (AASA) endpoints ---
# These must be served as raw JSON (no redirects, no extensions) for iOS to verify

def _aasa_payload() -> dict:
    return {
        "applinks": {
            # Keep top-level "apps" for legacy compatibility
            "apps": [],
            "details": [
                {
                    # appID is TEAMID.BUNDLEID
                    "appID": f"{APPLE_TEAM_ID}.{IOS_BUNDLE_ID}",
                    # Only link paths we handle in the app
                    "paths": [
                        "/artist/*",
                        "/studio/*",
                    ],
                }
            ],
        }
    }


@router.get("/.well-known/apple-app-site-association", include_in_schema=False)
async def aasa_well_known() -> JSONResponse:
    """Serve AASA from the well-known location."""
    return JSONResponse(content=_aasa_payload(), media_type="application/json")


@router.get("/apple-app-site-association", include_in_schema=False)
async def aasa_root() -> JSONResponse:
    """Serve AASA from the root as an additional location."""
    return JSONResponse(content=_aasa_payload(), media_type="application/json")


@router.get("/web/artist/{artist_id}", response_class=HTMLResponse)
async def artist_web_detail(request: Request, artist_id: str):
    """Serve the artist web detail page."""
    try:
        # Get artist data from database
        artists = DatabaseOperations.get_artists()
        
        # Find the specific artist
        artist = None
        for art in artists:
            if art.get('id') == artist_id:
                artist = art
                break
        
        if not artist:
            raise HTTPException(status_code=404, detail="Artist not found")
        
        # Get artist name with proper title case
        artist_name = artist.get('name', 'Unknown Artist')
        if artist_name:
            artist_name = ' '.join(word.capitalize() for word in artist_name.split())
        
        # Get current URL for social sharing
        current_url = str(request.url)
        
        return templates.TemplateResponse("artist_web_detail.html", {
            "request": request,
            "artist_name": artist_name,
            "artist_id": artist_id,
            "artist": artist,
            "current_url": current_url
        })
        
    except Exception as e:
        print(f"Error in artist web detail route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/artist/{artist_id}", response_class=HTMLResponse)
async def artist_deep_link(request: Request, artist_id: str):
    """Serve the artist deep link page that attempts to open the app or redirects to app store."""
    try:
        # Get artist data from database
        db_ops = DatabaseOperations()
        artists = await db_ops.get_artists()
        
        # Find the specific artist
        artist = None
        for art in artists:
            if art.get('_id') == artist_id:
                artist = art
                break
        
        if not artist:
            raise HTTPException(status_code=404, detail="Artist not found")
        
        # Get artist name with proper title case
        artist_name = artist.get('name', 'Unknown Artist')
        if artist_name:
            artist_name = ' '.join(word.capitalize() for word in artist_name.split())
        
        # Get current URL for social sharing
        current_url = str(request.url)
        
        return templates.TemplateResponse("artist_redirect.html", {
            "request": request,
            "artist_name": artist_name,
            "artist_id": artist_id,
            "current_url": current_url
        })
        
    except Exception as e:
        print(f"Error in artist deep link route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/studio/{studio_id}", response_class=HTMLResponse)
async def studio_deep_link(request: Request, studio_id: str):
    """Serve the studio deep link page that attempts to open the app or redirects to app store."""
    try:
        # Get studio data from database
        studios = DatabaseOperations.get_studios()
        
        # Find the specific studio
        studio = None
        for std in studios:
            if std.get('_id') == studio_id:
                studio = std
                break
        
        if not studio:
            raise HTTPException(status_code=404, detail="Studio not found")
        
        # Get studio name with proper title case
        studio_name = studio.get('name', 'Unknown Studio')
        if studio_name:
            studio_name = ' '.join(word.capitalize() for word in studio_name.split())
        
        # Get current URL for social sharing
        current_url = str(request.url)
        
        return templates.TemplateResponse("studio_redirect.html", {
            "request": request,
            "studio_name": studio_name,
            "studio_id": studio_id,
            "current_url": current_url
        })
        
    except Exception as e:
        print(f"Error in studio deep link route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/payment-success", response_class=HTMLResponse)
async def payment_success(request: Request, order_id: str = None):
    """Handle payment success callback and redirect to app."""
    try:
        if not order_id:
            raise HTTPException(status_code=400, detail="Order ID is required")
        
        # Create deep link to open app's Order Status screen
        app_deep_link = f"nachna://order-status/{order_id}"
        
        # Return HTML that immediately redirects to the app
        return HTMLResponse(content=f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Payment Successful - Redirecting to Nachna</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: linear-gradient(135deg, #0A0A0F, #1A1A2E, #16213E, #0F3460);
                    color: white;
                    text-align: center;
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                }}
                .container {{
                    max-width: 400px;
                    padding: 40px 20px;
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                    border: 1px solid rgba(255, 255, 255, 0.2);
                }}
                .success-icon {{
                    font-size: 48px;
                    margin-bottom: 20px;
                }}
                h1 {{
                    margin: 0 0 10px 0;
                    font-size: 24px;
                    color: #00D4FF;
                }}
                p {{
                    margin: 10px 0;
                    opacity: 0.9;
                }}
                .order-id {{
                    font-family: monospace;
                    background: rgba(0, 212, 255, 0.2);
                    padding: 8px 12px;
                    border-radius: 8px;
                    margin: 20px 0;
                    font-weight: bold;
                }}
                .app-button {{
                    display: inline-block;
                    margin-top: 20px;
                    padding: 12px 24px;
                    background: linear-gradient(45deg, #00D4FF, #9C27B0);
                    color: white;
                    text-decoration: none;
                    border-radius: 12px;
                    font-weight: 600;
                }}
                .fallback {{
                    margin-top: 20px;
                    font-size: 14px;
                    opacity: 0.7;
                }}
            </style>
            <script>
                // Try to open the app immediately
                window.location.href = "{app_deep_link}";
                
                // Fallback: show the page content if app doesn't open
                setTimeout(function() {{
                    document.getElementById('content').style.display = 'block';
                }}, 2000);
            </script>
        </head>
        <body>
            <div id="content" style="display: none;">
                <div class="container">
                    <div class="success-icon">✅</div>
                    <h1>Payment Successful!</h1>
                    <p>Your workshop registration is complete.</p>
                    <div class="order-id">Order: {order_id}</div>
                    <p>Opening Nachna app to track your order...</p>
                    
                    <a href="{app_deep_link}" class="app-button">
                        Open Nachna App
                    </a>
                    
                    <div class="fallback">
                        If the app doesn't open automatically, tap the button above or open the Nachna app manually.
                    </div>
                </div>
            </div>
        </body>
        </html>
        """)
        
    except Exception as e:
        print(f"Error in payment success route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/web/{studio_id}", response_class=HTMLResponse)
async def studio_web_booking(request: Request, studio_id: str, artist_id: Optional[str] = None):
    """Serve the studio web booking page.
    
    Args:
        studio_id: The studio ID
        artist_id: Optional query parameter to filter workshops by artist
    """
    try:
        # Get studio data from database
        studios = DatabaseOperations.get_studios()
        
        # Find the specific studio
        studio = None
        for std in studios:
            if std.get('id') == studio_id:
                studio = std
                break
        
        if not studio:
            raise HTTPException(status_code=404, detail="Studio not found")
        
        # Get studio name with proper title case
        studio_name = studio.get('name', 'Unknown Studio')
        if studio_name:
            studio_name = ' '.join(word.capitalize() for word in studio_name.split())
        
        # Get current URL for social sharing
        current_url = str(request.url)
        
        return templates.TemplateResponse("studio_web_booking.html", {
            "request": request,
            "studio_name": studio_name,
            "studio_id": studio_id,
            "studio": studio,
            "current_url": current_url,
            "artist_id": artist_id  # Pass artist_id to template for filtering
        })
        
    except Exception as e:
        print(f"Error in studio web booking route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/bundles", response_class=HTMLResponse)
async def bundles_page(request: Request):
    """Serve the bundles listing page."""
    try:
        bundles_list = list(BUNDLE_TEMPLATES.values())
        return templates.TemplateResponse("bundles.html", {
            "request": request,
            "bundles": bundles_list
        })
    except Exception as e:
        print(f"Error in bundles page: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/bundles/{template_id}", response_class=HTMLResponse)
async def bundle_detail_page(request: Request, template_id: str):
    """Serve the bundle detail page."""
    try:
        if template_id not in BUNDLE_TEMPLATES:
            raise HTTPException(status_code=404, detail="Bundle not found")

        bundle = BUNDLE_TEMPLATES[template_id]
        return templates.TemplateResponse("bundle_detail.html", {
            "request": request,
            "bundle": bundle
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in bundle detail page: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/order/status", response_class=HTMLResponse)
async def order_status_page(request: Request, order_id: str = None):
    """Serve the complete order status page."""
    try:
        # Get order_id from query parameters
        if not order_id:
            query_params = request.query_params
            order_id = query_params.get('order_id')

        if not order_id:
            raise HTTPException(status_code=400, detail="Order ID is required")

        # Return the order status template
        return templates.TemplateResponse("order_status.html", {
            "request": request,
            "order_id": order_id
        })

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in order status route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/web/admin/workshop_details", response_class=HTMLResponse)
async def admin_workshop_details(request: Request):
    """Serve the admin workshop details page."""
    try:
        return templates.TemplateResponse("admin_workshop_details.html", {"request": request})
    except Exception as e:
        print(f"Error in admin workshop details route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/admin/login", response_class=HTMLResponse)
async def admin_login_page(request: Request):
    """Serve the admin login page."""
    try:
        # Simple admin login page that uses the existing OTP system
        login_html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login - Nachna</title>
    <style>
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #121824 0%, #1a2436 50%, #121830 100%);
            color: #f0f4f8;
            margin: 0;
            padding: 24px;
            line-height: 1.6;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .login-container {
            background: rgba(20, 30, 48, 0.7);
            backdrop-filter: blur(10px);
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.3);
            padding: 40px;
            width: 100%;
            max-width: 400px;
            text-align: center;
        }

        .logo {
            width: 80px;
            height: 80px;
            background: linear-gradient(45deg, #FF006E, #8338EC);
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            box-shadow: 0 8px 32px rgba(255, 0, 110, 0.3);
        }

        .logo svg {
            width: 40px;
            height: 40px;
            fill: white;
        }

        h1 {
            color: #4d9eff;
            margin-bottom: 8px;
            font-size: 1.8rem;
        }

        .subtitle {
            color: rgba(255,255,255,0.7);
            margin-bottom: 32px;
            font-size: 0.9rem;
        }

        .form-group {
            margin-bottom: 20px;
            text-align: left;
        }

        label {
            display: block;
            margin-bottom: 8px;
            color: #f0f4f8;
            font-weight: 500;
        }

        input {
            width: 100%;
            padding: 12px;
            border-radius: 8px;
            border: 1px solid rgba(255,255,255,0.2);
            background: rgba(40,50,70,0.8);
            color: #f0f4f8;
            font-size: 1rem;
            box-sizing: border-box;
        }

        input:focus {
            outline: 2px solid #4d9eff;
        }

        .btn {
            width: 100%;
            padding: 12px;
            border-radius: 8px;
            border: none;
            background: linear-gradient(45deg, #4d9eff, #357abd);
            color: white;
            font-weight: 600;
            cursor: pointer;
            margin-top: 20px;
            transition: all 0.3s ease;
        }

        .btn:hover {
            background: linear-gradient(45deg, #357abd, #2a5f99);
            transform: translateY(-2px);
        }

        .btn:disabled {
            background: rgba(255,255,255,0.2);
            cursor: not-allowed;
            transform: none;
        }

        .message {
            margin-top: 16px;
            padding: 12px;
            border-radius: 8px;
            text-align: left;
        }

        .message.success {
            background: rgba(25, 135, 84, 0.2);
            border: 1px solid #198754;
            color: #d1e7dd;
        }

        .message.error {
            background: rgba(220, 53, 69, 0.2);
            border: 1px solid #dc3545;
            color: #f5c6cb;
        }

        .back-link {
            margin-top: 20px;
            display: inline-block;
            color: #4d9eff;
            text-decoration: none;
        }

        .back-link:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <svg viewBox="0 0 24 24">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
            </svg>
        </div>

        <h1>Admin Login</h1>
        <div class="subtitle">Enter your mobile number to receive OTP</div>

        <div id="phone-section">
            <div class="form-group">
                <label for="mobile">Mobile Number</label>
                <input type="tel" id="mobile" placeholder="Enter mobile number" maxlength="10">
            </div>
            <button id="send-otp-btn" class="btn">Send OTP</button>
        </div>

        <div id="otp-section" style="display: none;">
            <div class="form-group">
                <label for="otp">Enter OTP</label>
                <input type="text" id="otp" placeholder="Enter 6-digit OTP" maxlength="6">
            </div>
            <button id="verify-otp-btn" class="btn">Verify & Login</button>
            <button id="back-btn" class="btn" style="background: rgba(255,255,255,0.1); margin-top: 10px;">Back</button>
        </div>

        <div id="message"></div>

        <a href="/web/admin/workshop_details" class="back-link">← Back to Admin Panel</a>
    </div>

    <script>
        const phoneSection = document.getElementById('phone-section');
        const otpSection = document.getElementById('otp-section');
        const sendOtpBtn = document.getElementById('send-otp-btn');
        const verifyOtpBtn = document.getElementById('verify-otp-btn');
        const backBtn = document.getElementById('back-btn');
        const mobileInput = document.getElementById('mobile');
        const otpInput = document.getElementById('otp');
        const messageDiv = document.getElementById('message');

        let currentMobile = '';

        function showMessage(message, type = 'error') {
            messageDiv.innerHTML = `<div class="message ${type}">${message}</div>`;
            setTimeout(() => messageDiv.innerHTML = '', 5000);
        }

        sendOtpBtn.addEventListener('click', async () => {
            const mobile = mobileInput.value.trim();
            if (!mobile || mobile.length !== 10 || !/^[0-9]+$/.test(mobile)) {
                showMessage('Please enter a valid 10-digit mobile number');
                return;
            }

            sendOtpBtn.disabled = true;
            sendOtpBtn.textContent = 'Sending...';

            try {
                const response = await fetch('/api/auth/send-otp', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ mobile_number: mobile })
                });

                const data = await response.json();

                if (data.success) {
                    currentMobile = mobile;
                    phoneSection.style.display = 'none';
                    otpSection.style.display = 'block';
                    otpInput.focus();
                    showMessage('OTP sent successfully! Please check your phone.', 'success');
                } else {
                    showMessage(data.message || 'Failed to send OTP');
                }
            } catch (error) {
                showMessage('Network error. Please try again.');
            } finally {
                sendOtpBtn.disabled = false;
                sendOtpBtn.textContent = 'Send OTP';
            }
        });

        verifyOtpBtn.addEventListener('click', async () => {
            const otp = otpInput.value.trim();
            if (!otp || otp.length !== 6) {
                showMessage('Please enter a valid 6-digit OTP');
                return;
            }

            verifyOtpBtn.disabled = true;
            verifyOtpBtn.textContent = 'Verifying...';

            try {
                const response = await fetch('/api/auth/verify-otp', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        mobile_number: currentMobile,
                        otp: otp
                    })
                });

                const data = await response.json();

                if (data.user && data.user.is_admin) {
                    // Store token and redirect
                    localStorage.setItem('admin_token', data.access_token);
                    showMessage('Login successful! Redirecting...', 'success');

                    setTimeout(() => {
                        window.location.href = '/web/admin/workshop_details';
                    }, 1000);
                } else if (data.user && !data.user.is_admin) {
                    showMessage('Access denied. Admin privileges required.');
                } else {
                    showMessage('Login failed. Please try again.');
                }
            } catch (error) {
                showMessage('Network error. Please try again.');
            } finally {
                verifyOtpBtn.disabled = false;
                verifyOtpBtn.textContent = 'Verify & Login';
            }
        });

        backBtn.addEventListener('click', () => {
            otpSection.style.display = 'none';
            phoneSection.style.display = 'block';
            otpInput.value = '';
            messageDiv.innerHTML = '';
        });

        // Allow Enter key to trigger buttons
        mobileInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendOtpBtn.click();
        });

        otpInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') verifyOtpBtn.click();
        });
    </script>
</body>
</html>
        """
        return HTMLResponse(content=login_html)
    except Exception as e:
        print(f"Error in admin login route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
