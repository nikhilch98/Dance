"""Web routes for serving static pages."""

from typing import Optional
from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from app.database.workshops import DatabaseOperations
from app.services.auth import verify_token

router = APIRouter()
templates = Jinja2Templates(directory="templates")

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
async def studio_web_booking(request: Request, studio_id: str):
    """Serve the studio web booking page."""
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
            "current_url": current_url
        })
        
    except Exception as e:
        print(f"Error in studio web booking route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/order/status", response_class=HTMLResponse)
async def order_status_redirect(request: Request, order_id: str = None, user_id: Optional[str] = Depends(verify_token)):
    """Handle order status page with web-based order details."""
    try:
        # Get order_id from query parameters
        query_params = request.query_params
        order_id = query_params.get('order_id')

        if not order_id:
            raise HTTPException(status_code=400, detail="Order ID is required")

        # Create deep link to open app's Order Status screen
        app_deep_link = f"nachna://order-status/{order_id}"
        universal_link = f"https://nachna.com/order/status?order_id={order_id}"

        # Check if user is authenticated and get order details
        order_details = None
        user_authenticated = user_id is not None

        if user_authenticated:
            try:
                from app.database.orders import OrderOperations
                from app.database.workshops import DatabaseOperations as WorkshopOperations
                from utils.utils import get_mongo_client

                # Get order details
                order = OrderOperations.get_order_by_id(order_id)
                if order and order.get('user_id') == user_id:
                    # Get workshop details
                    client = get_mongo_client()
                    workshop = client["discovery"]["workshops_v2"].find_one({"uuid": order.get("workshop_uuid")})

                    # Get QR code status
                    qr_code_data = order.get('qr_code_data')
                    qr_status = 'available' if qr_code_data else ('generating' if order.get('status') == 'paid' else 'not_available')

                    order_details = {
                        'order_id': order_id,
                        'status': order.get('status', 'unknown'),
                        'amount': order.get('amount', 0) / 100,  # Convert from paise
                        'workshop_name': workshop.get('song', 'Unknown Workshop') if workshop else 'Unknown Workshop',
                        'artist_name': workshop.get('by', 'Unknown Artist') if workshop else 'Unknown Artist',
                        'date': workshop.get('date', 'TBA') if workshop else 'TBA',
                        'time': workshop.get('time', 'TBA') if workshop else 'TBA',
                        'qr_code_data': qr_code_data,
                        'qr_status': qr_status
                    }
            except Exception as e:
                print(f"Error fetching order details: {e}")
                user_authenticated = False

        # Return enhanced HTML with order details
        return HTMLResponse(content=f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Order Status - Redirecting to Nachna</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="apple-mobile-web-app-capable" content="yes">
            <meta name="apple-mobile-web-app-status-bar-style" content="default">
            <meta name="robots" content="noindex, nofollow">
            <style>
                * {{
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }}

                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 0;
                    background: linear-gradient(135deg, #0A0A0F 0%, #1A1A2E 25%, #16213E 50%, #0F3460 100%);
                    color: white;
                    text-align: center;
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    overflow-x: hidden;
                }}

                .container {{
                    max-width: 400px;
                    padding: 40px 20px;
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
                }}

                .logo {{
                    width: 80px;
                    height: 80px;
                    background: linear-gradient(45deg, #FF006E, #8338EC);
                    border-radius: 20px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 1.5rem;
                    box-shadow: 0 8px 32px rgba(255, 0, 110, 0.3);
                }}

                .logo svg {{
                    width: 40px;
                    height: 40px;
                    fill: white;
                }}

                .status-icon {{
                    font-size: 48px;
                    margin-bottom: 20px;
                }}

                h1 {{
                    margin: 0 0 10px 0;
                    font-size: 24px;
                    color: #00D4FF;
                    background: linear-gradient(45deg, #FF006E, #00D4FF);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                    background-clip: text;
                }}

                p {{
                    margin: 10px 0;
                    opacity: 0.9;
                    line-height: 1.5;
                }}

                .order-id {{
                    font-family: monospace;
                    background: rgba(0, 212, 255, 0.2);
                    padding: 8px 12px;
                    border-radius: 8px;
                    margin: 20px 0;
                    font-weight: bold;
                    border: 1px solid rgba(0, 212, 255, 0.3);
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
                    transition: all 0.3s ease;
                    box-shadow: 0 4px 15px rgba(0, 212, 255, 0.3);
                }}

                .app-button:hover {{
                    transform: translateY(-2px);
                    box-shadow: 0 6px 20px rgba(0, 212, 255, 0.4);
                }}

                .fallback {{
                    margin-top: 20px;
                    font-size: 14px;
                    opacity: 0.7;
                }}

                .pulse {{
                    animation: pulse 2s infinite;
                }}

                @keyframes pulse {{
                    0% {{ transform: scale(1); }}
                    50% {{ transform: scale(1.05); }}
                    100% {{ transform: scale(1); }}
                }}


                .loading {{
                    display: inline-block;
                    width: 20px;
                    height: 20px;
                    border: 2px solid rgba(255, 255, 255, 0.3);
                    border-radius: 50%;
                    border-top-color: #00D4FF;
                    animation: spin 1s ease-in-out infinite;
                    margin-right: 10px;
                }}

                @keyframes spin {{
                    to {{ transform: rotate(360deg); }}
                }}

                .attempting {{
                    font-size: 16px;
                    color: #00D4FF;
                    margin-bottom: 20px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }}

                /* Order Details Styles */
                .order-details-section {{
                    margin: 30px 0;
                }}

                .order-details-card {{
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 16px;
                    padding: 20px;
                    margin-bottom: 24px;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                }}

                .order-details-card h3 {{
                    margin: 0 0 16px 0;
                    color: #00D4FF;
                    font-size: 18px;
                    font-weight: 600;
                }}

                .detail-row {{
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 8px 0;
                    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
                }}

                .detail-row:last-child {{
                    border-bottom: none;
                }}

                .detail-row .label {{
                    font-weight: 500;
                    color: rgba(255, 255, 255, 0.9);
                }}

                .detail-row .value {{
                    font-weight: 600;
                    color: white;
                    text-align: right;
                }}

                .status-badge {{
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 12px;
                    font-weight: 600;
                    text-transform: uppercase;
                }}

                .status-badge.paid {{
                    background: rgba(16, 185, 129, 0.2);
                    color: #10B981;
                    border: 1px solid rgba(16, 185, 129, 0.3);
                }}

                .status-badge.processing {{
                    background: rgba(255, 136, 0, 0.2);
                    color: #FF8800;
                    border: 1px solid rgba(255, 136, 0, 0.3);
                }}

                /* QR Code Section */
                .qr-section {{
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 16px;
                    padding: 20px;
                    margin-bottom: 24px;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    text-align: center;
                }}

                .qr-section h3 {{
                    margin: 0 0 20px 0;
                    color: #00D4FF;
                    font-size: 18px;
                    font-weight: 600;
                }}

                .qr-code-container {{
                    margin: 20px 0;
                }}

                .qr-code-image {{
                    width: 200px;
                    height: 200px;
                    border-radius: 12px;
                    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
                    border: 2px solid rgba(255, 255, 255, 0.2);
                }}

                .qr-instruction {{
                    margin-top: 16px;
                    font-size: 14px;
                    color: rgba(255, 255, 255, 0.8);
                    font-weight: 500;
                }}

                .qr-loading {{
                    padding: 40px 20px;
                }}

                .loading-spinner {{
                    width: 50px;
                    height: 50px;
                    border: 3px solid rgba(255, 255, 255, 0.3);
                    border-radius: 50%;
                    border-top-color: #00D4FF;
                    animation: spin 1s linear infinite;
                    margin: 0 auto 20px;
                }}

                .loading-note {{
                    margin-top: 8px;
                    font-size: 12px;
                    color: rgba(255, 255, 255, 0.6);
                }}

                .qr-placeholder {{
                    padding: 40px 20px;
                }}

                .qr-placeholder-icon {{
                    font-size: 48px;
                    margin-bottom: 16px;
                    opacity: 0.7;
                }}

                /* App Section */
                .app-section {{
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 16px;
                    padding: 20px;
                    margin-bottom: 24px;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                }}

                .app-section h3 {{
                    margin: 0 0 12px 0;
                    color: #00D4FF;
                    font-size: 18px;
                    font-weight: 600;
                }}

                .app-description {{
                    margin: 0 0 20px 0;
                    color: rgba(255, 255, 255, 0.9);
                    line-height: 1.5;
                    font-size: 14px;
                }}

                .app-actions {{
                    display: flex;
                    flex-direction: column;
                    gap: 16px;
                }}

                .app-button.primary {{
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    gap: 8px;
                    background: linear-gradient(45deg, #00D4FF, #9C27B0);
                    color: white;
                    text-decoration: none;
                    border-radius: 12px;
                    font-weight: 600;
                    transition: all 0.3s ease;
                    box-shadow: 0 4px 15px rgba(0, 212, 255, 0.3);
                    margin-bottom: 16px;
                }}

                .app-button.primary:hover {{
                    transform: translateY(-2px);
                    box-shadow: 0 6px 20px rgba(0, 212, 255, 0.4);
                }}

                .button-icon {{
                    font-size: 16px;
                }}

                .app-links {{
                    display: flex;
                    gap: 12px;
                    justify-content: center;
                }}

                .store-link {{
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    padding: 8px 16px;
                    background: rgba(255, 255, 255, 0.1);
                    color: white;
                    text-decoration: none;
                    border-radius: 8px;
                    font-size: 12px;
                    font-weight: 500;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    transition: all 0.2s ease;
                }}

                .store-link:hover {{
                    background: rgba(255, 255, 255, 0.2);
                    transform: translateY(-1px);
                }}

                .store-icon {{
                    font-size: 14px;
                }}

                /* Login Section */
                .login-section {{
                    background: rgba(255, 255, 255, 0.1);
                    border-radius: 16px;
                    padding: 20px;
                    margin-bottom: 24px;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    text-align: center;
                }}

                .login-section h3 {{
                    margin: 0 0 12px 0;
                    color: #00D4FF;
                    font-size: 18px;
                    font-weight: 600;
                }}

                .login-description {{
                    margin: 0 0 20px 0;
                    color: rgba(255, 255, 255, 0.9);
                    line-height: 1.5;
                    font-size: 14px;
                }}

                .login-actions {{
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 16px;
                }}

                .login-button.primary {{
                    display: inline-flex;
                    align-items: center;
                    gap: 8px;
                    background: linear-gradient(45deg, #00D4FF, #9C27B0);
                    color: white;
                    text-decoration: none;
                    border-radius: 12px;
                    padding: 12px 24px;
                    font-weight: 600;
                    font-size: 14px;
                    transition: all 0.3s ease;
                    box-shadow: 0 4px 15px rgba(0, 212, 255, 0.3);
                    border: none;
                    cursor: pointer;
                }}

                .login-button.primary:hover {{
                    transform: translateY(-2px);
                    box-shadow: 0 6px 20px rgba(0, 212, 255, 0.4);
                }}

                .login-note {{
                    margin: 0;
                    font-size: 12px;
                    color: rgba(255, 255, 255, 0.7);
                    text-align: center;
                }}

                .login-note a {{
                    color: #00D4FF;
                    text-decoration: none;
                }}

                .login-note a:hover {{
                    text-decoration: underline;
                }}

                @media (max-width: 480px) {{
                    .container {{
                        padding: 30px 15px;
                        margin: 20px;
                    }}

                    h1 {{
                        font-size: 20px;
                    }}

                    .app-button {{
                        padding: 10px 20px;
                        font-size: 14px;
                    }}

                    .qr-code-image {{
                        width: 150px;
                        height: 150px;
                    }}

                    .app-links {{
                        flex-direction: column;
                        align-items: center;
                    }}

                    .detail-row {{
                        flex-direction: column;
                        align-items: flex-start;
                        gap: 4px;
                    }}

                    .detail-row .value {{
                        text-align: left;
                    }}

                    .login-section {{
                        padding: 16px;
                    }}

                    .login-button.primary {{
                        padding: 10px 20px;
                        font-size: 13px;
                    }}

                    .login-description {{
                        font-size: 13px;
                    }}
                }}
            </style>
            <script>
                console.log('Opening Nachna app...');

                // Show attempting message immediately
                setTimeout(function() {{
                    const attemptingDiv = document.getElementById('attempting');
                    if (attemptingDiv) {{
                        attemptingDiv.style.display = 'flex';
                    }}
                }}, 100);

                let appOpened = false;
                let attemptsMade = 0;
                const maxAttempts = 3;
                let isAttempting = false; // Prevent multiple simultaneous attempts
                let fallbackShown = false; // Track if fallback has been shown

                // Function to try opening app
                function tryOpenApp(url, attemptNumber) {{
                    // For mobile browsers, try multiple methods
                    if (navigator.userAgent.match(/Android/i)) {{
                        // Android - try intent URL first
                        if (url.startsWith('nachna://')) {{
                            const intentUrl = `intent:${{url}}#Intent;scheme=nachna;package=com.nachna.nachna;end`;
                            window.location.href = intentUrl;
                        }} else {{
                            window.location.href = url;
                        }}
                    }} else if (navigator.userAgent.match(/iPhone|iPad|iPod/i)) {{
                        // iOS - use window.location.href
                        window.location.href = url;
                    }} else {{
                        // Desktop/other - use window.location.href
                        window.location.href = url;
                    }}
                }}

                // Sequential attempt function
                function performAttempt(attemptNumber) {{
                    if (appOpened || attemptsMade >= maxAttempts) {{
                        return;
                    }}

                    attemptsMade = attemptNumber;

                    if (attemptNumber === 1) {{
                        // First attempt: Try custom scheme
                        tryOpenApp("{app_deep_link}", 1);
                    }} else if (attemptNumber === 2) {{
                        // Second attempt: Try universal link
                        tryOpenApp("{universal_link}", 2);
                    }} else if (attemptNumber === 3) {{
                        // Third attempt: Try custom scheme with delay
                        setTimeout(function() {{
                            tryOpenApp("{app_deep_link}", 3);
                        }}, 500);
                    }}
                }}

                // Start sequential attempts
                function startAppOpenAttempts() {{
                    if (isAttempting) {{
                        return;
                    }}
                    isAttempting = true;

                    // Attempt 1: Immediate custom scheme
                    setTimeout(function() {{ performAttempt(1); }}, 200);

                    // Attempt 2: Universal link after 1 second
                    setTimeout(function() {{ performAttempt(2); }}, 1200);

                    // Attempt 3: Delayed custom scheme after 2.5 seconds
                    setTimeout(function() {{ performAttempt(3); }}, 2500);
                }}

                // Start the attempts
                startAppOpenAttempts();

                // Function to show fallback content
                function showFallbackContent() {{
                    if (fallbackShown) return; // Prevent multiple calls
                    fallbackShown = true;
                    
                    console.log('Showing fallback content');
                    const contentDiv = document.getElementById('content');
                    const attemptingDiv = document.getElementById('attempting');
                    
                    if (contentDiv) {{
                        contentDiv.style.display = 'block';
                    }}
                    if (attemptingDiv) {{
                        attemptingDiv.style.display = 'none';
                    }}
                }}

                // Fallback: show the page content if app doesn't open
                setTimeout(showFallbackContent, 3000);
                
                // Additional safety - show content after 5 seconds no matter what
                setTimeout(showFallbackContent, 5000);

                // Detection methods
                try {{
                    // Check if page becomes hidden (app opened)
                    document.addEventListener('visibilitychange', function() {{
                        if (document.hidden) {{
                            appOpened = true;
                        }}
                    }});

                    // Check if we can detect app opening via page blur
                    window.addEventListener('blur', function() {{
                        appOpened = true;
                    }});

                    // Check if page becomes inactive
                    window.addEventListener('pagehide', function() {{
                        appOpened = true;
                    }});

                }} catch (e) {{
                    // Silent error handling
                }}

                // Handle button click
                function handleButtonClick() {{
                    // Reset state for manual attempt
                    appOpened = false;
                    attemptsMade = 0;
                    isAttempting = false;

                    // Start fresh attempts
                    startAppOpenAttempts();

                    // Show content after manual attempt
                    setTimeout(showFallbackContent, 1000);
                }}
                
                // Prevent page refreshing or navigation away
                window.addEventListener('beforeunload', function(e) {{
                    // Don't prevent if app was successfully opened
                    if (appOpened) return;
                    
                    // Show fallback immediately if user tries to navigate away
                    showFallbackContent();
                }});
                
                // Handle page load to ensure content is shown
                window.addEventListener('load', function() {{
                    // Show fallback after 6 seconds as final safety net
                    setTimeout(showFallbackContent, 6000);
                }});
            </script>
        </head>
        <body>
            <div class="logo">
                <svg viewBox="0 0 24 24">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                </svg>
            </div>

            <div id="attempting" class="attempting" style="display: none;">
                <span class="loading"></span>
                Opening Nachna app...
                <div style="margin-top: 15px;">
                    <a href="javascript:void(0)" onclick="showFallbackContent()" style="color: rgba(255,255,255,0.7); font-size: 12px; text-decoration: underline;">
                        Having trouble? Click here
                    </a>
                </div>
            </div>

            <div id="content" style="display: none;">
                <div class="container">
                    <div class="status-icon pulse">📱</div>
                    <h1>Payment Successful!</h1>
                    <p>Your workshop registration is complete.</p>
                    <div class="order-id">Order: {order_id}</div>

                    {f'''
                    <div class="login-section">
                        <h3>🔐 Login Required</h3>
                        <p class="login-description">
                            Please log in to view your complete order details, QR code, and workshop information.
                        </p>
                        <div class="login-actions">
                            <a href="/studio" class="login-button primary">
                                <span class="button-icon">🔑</span>
                                Login to View Details
                            </a>
                            <p class="login-note">
                                <small>Don't have an account? <a href="/studio" style="color: #00D4FF;">Sign up</a> to access all features.</small>
                            </p>
                        </div>
                    </div>
                    ''' if not user_authenticated else f'''
                    <div class="order-details-section">
                    <div class="order-details-card">
                        <h3>🎵 Workshop Details</h3>
                        <div class="detail-row">
                            <span class="label">Workshop:</span>
                            <span class="value">{order_details["workshop_name"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Artist:</span>
                            <span class="value">{order_details["artist_name"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Date & Time:</span>
                            <span class="value">{order_details["date"] if order_details else ""} at {order_details["time"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Amount Paid:</span>
                            <span class="value">₹{order_details["amount"] if order_details else 0:.2f}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Status:</span>
                            <span class="status-badge {"paid" if order_details and order_details["status"] == "paid" else "processing"}">
                                {order_details["status"].title() if order_details else "Processing"}
                            </span>
                        </div>
                    </div>

                    <div class="qr-section">
                        <h3>🎫 Your QR Code</h3>
                    ''' if order_details and order_details["qr_status"] == "available" else f'''
                    <div class="order-details-section">
                    <div class="order-details-card">
                        <h3>🎵 Workshop Details</h3>
                        <div class="detail-row">
                            <span class="label">Workshop:</span>
                            <span class="value">{order_details["workshop_name"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Artist:</span>
                            <span class="value">{order_details["artist_name"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Date & Time:</span>
                            <span class="value">{order_details["date"] if order_details else ""} at {order_details["time"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Amount Paid:</span>
                            <span class="value">₹{order_details["amount"] if order_details else 0:.2f}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Status:</span>
                            <span class="status-badge {"paid" if order_details and order_details["status"] == "paid" else "processing"}">
                                {order_details["status"].title() if order_details else "Processing"}
                            </span>
                        </div>
                    </div>

                    <div class="qr-section">
                        <h3>🎫 QR Code Generation</h3>
                    ''' if order_details and order_details["qr_status"] == "generating" else f'''
                    <div class="order-details-section">
                    <div class="order-details-card">
                        <h3>🎵 Workshop Details</h3>
                        <div class="detail-row">
                            <span class="label">Workshop:</span>
                            <span class="value">{order_details["workshop_name"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Artist:</span>
                            <span class="value">{order_details["artist_name"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Date & Time:</span>
                            <span class="value">{order_details["date"] if order_details else ""} at {order_details["time"] if order_details else ""}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Amount Paid:</span>
                            <span class="value">₹{order_details["amount"] if order_details else 0:.2f}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">Status:</span>
                            <span class="status-badge {"paid" if order_details and order_details["status"] == "paid" else "processing"}">
                                {order_details["status"].title() if order_details else "Processing"}
                            </span>
                        </div>
                    </div>

                    <div class="qr-section">
                        <h3>🎫 QR Code</h3>
                    '''}

                    {f'''
                        <div class="qr-code-container">
                            <img src="data:image/png;base64,{order_details["qr_code_data"] if order_details else ""}" alt="QR Code" class="qr-code-image">
                            <p class="qr-instruction">Show this QR code at the workshop venue</p>
                        </div>
                    </div>
                    </div>
                    ''' if order_details and order_details["qr_status"] == "available" else f'''
                        <div class="qr-loading">
                            <div class="loading-spinner"></div>
                            <p>Generating your QR code...</p>
                            <p class="loading-note">This usually takes 1-2 minutes</p>
                        </div>
                    </div>
                    </div>
                    ''' if order_details and order_details["qr_status"] == "generating" else f'''
                        <div class="qr-placeholder">
                            <div class="qr-placeholder-icon">🎫</div>
                            <p>QR code will be available once payment is confirmed</p>
                        </div>
                    </div>
                    </div>
                    ''' if user_authenticated and order_details else ""}

                    <div class="app-section">
                        <h3>📱 Have Nachna Installed?</h3>
                        <p class="app-description">
                            Get the full experience with our mobile app! View detailed order history, get notifications, and manage your bookings on the go.
                        </p>

                        <div class="app-actions">
                            <a href="javascript:void(0)" class="app-button primary" onclick="handleButtonClick()">
                                <span class="button-icon">📱</span>
                                Open Nachna App
                            </a>
                            <div class="app-links">
                                <a href="https://play.google.com/store/apps/details?id=com.nachna.nachna" class="store-link" target="_blank">
                                    <span class="store-icon">🤖</span>
                                    Get on Google Play
                                </a>
                                <a href="https://apps.apple.com/app/nachna/id[YOUR_APP_ID]" class="store-link" target="_blank">
                                    <span class="store-icon">🍎</span>
                                    Download on App Store
                                </a>
                            </div>
                        </div>
                    </div>

                    <div class="fallback">
                        If the app doesn't open automatically, tap the button above or open the Nachna app manually to view your order.
                    </div>

                </div>
            </div>
        </body>
        </html>
        """)

    except Exception as e:
        print(f"Error in order status route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error") 