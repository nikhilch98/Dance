"""Web routes for serving static pages."""

from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from app.database.workshops import DatabaseOperations

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
        db_ops = DatabaseOperations()
        studios = await db_ops.get_studios()
        
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


@router.get("/order/status", response_class=HTMLResponse)
async def order_status_redirect(request: Request, order_id: str = None):
    """Handle order status page redirect to app."""
    try:
        if not order_id:
            raise HTTPException(status_code=400, detail="Order ID is required")
        
        print(f"🔗 Order status redirect requested for order: {order_id}")
        
        # Create deep link to open app's Order Status screen
        app_deep_link = f"nachna://order-status/{order_id}"
        
        print(f"📱 Generated deep link: {app_deep_link}")
        
        # Return HTML that immediately redirects to the app
        return HTMLResponse(content=f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Order Status - Redirecting to Nachna</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="apple-mobile-web-app-capable" content="yes">
            <meta name="apple-mobile-web-app-status-bar-style" content="default">
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
                .status-icon {{
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
                .pulse {{
                    animation: pulse 2s infinite;
                }}
                @keyframes pulse {{
                    0% {{ transform: scale(1); }}
                    50% {{ transform: scale(1.05); }}
                    100% {{ transform: scale(1); }}
                }}
                .debug-info {{
                    background: rgba(255, 255, 255, 0.1);
                    padding: 10px;
                    border-radius: 8px;
                    margin: 20px 0;
                    font-size: 12px;
                    font-family: monospace;
                }}
            </style>
            <script>
                console.log('Order status page loaded for order: {order_id}');
                console.log('Attempting to open app with deep link: {app_deep_link}');
                
                // Try to open the app immediately
                window.location.href = "{app_deep_link}";
                
                // Fallback: show the page content if app doesn't open
                setTimeout(function() {{
                    console.log('Showing fallback content after 2 seconds');
                    document.getElementById('content').style.display = 'block';
                }}, 2000);
                
                // Additional fallback: try to detect if app opened
                let appOpened = false;
                try {{
                    // Check if we can detect app opening
                    window.addEventListener('blur', function() {{
                        console.log('Window blurred - app may have opened');
                        appOpened = true;
                    }});
                    
                    // Check if we're still on the page after a delay
                    setTimeout(function() {{
                        if (!appOpened) {{
                            console.log('App may not have opened, showing content');
                            document.getElementById('content').style.display = 'block';
                        }}
                    }}, 1000);
                }} catch (e) {{
                    console.error('Error in app detection:', e);
                }}
            </script>
        </head>
        <body>
            <div id="content" style="display: none;">
                <div class="container">
                    <div class="status-icon pulse">📱</div>
                    <h1>Order Status Ready</h1>
                    <p>Your order is being tracked...</p>
                    <div class="order-id">Order: {order_id}</div>
                    <p>Opening Nachna app to view order status...</p>
                    
                    <a href="{app_deep_link}" class="app-button">
                        View Order Status
                    </a>
                    
                    <div class="fallback">
                        If the app doesn't open automatically, tap the button above or open the Nachna app manually.
                    </div>
                    
                    <div class="debug-info">
                        Debug: Deep link = {app_deep_link}<br>
                        Order ID = {order_id}<br>
                        URL = {request.url}
                    </div>
                </div>
            </div>
        </body>
        </html>
        """)
        
    except Exception as e:
        print(f"Error in order status route: {e}")
        raise HTTPException(status_code=500, detail="Internal server error") 