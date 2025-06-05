"""Logging middleware for response time tracking."""

import time
from fastapi import Request
from colorama import Fore, Style, init

# Initialize colorama for cross-platform colored output
init(autoreset=True)


async def log_response_time_middleware(request: Request, call_next):
    """Middleware to log response times for each request."""
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    
    # Format time - convert to ms if less than 1 second
    if process_time < 1.0:
        time_str = f"{process_time * 1000:.1f}ms"
    else:
        time_str = f"{process_time:.3f}s"
    
    # Color codes based on status code
    if 200 <= response.status_code < 300:
        status_color = Fore.GREEN
    elif 300 <= response.status_code < 400:
        status_color = Fore.YELLOW
    elif 400 <= response.status_code < 500:
        status_color = Fore.RED
    else:
        status_color = Fore.MAGENTA
    
    # Format the log message with colors
    log_message = (
        f"{Fore.CYAN}INFO{Style.RESET_ALL}:server:"
        f"{request.client.host}:{request.client.port} - "
        f'"{request.method} {request.url.path}{"?" + str(request.url.query) if request.url.query else ""} '
        f'HTTP/{request.scope.get("http_version", "1.1")}" '
        f"{status_color}{response.status_code}{Style.RESET_ALL} - "
        f"| {Fore.BLUE}{time_str}{Style.RESET_ALL}"
    )
    
    print(log_message)
    
    return response