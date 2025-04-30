# Dance Workshop API

A Go implementation of the Dance Workshop application API using fasthttp.

## Overview

This project provides REST API endpoints for managing dance workshops, artists, and studios. It includes features for workshop discovery, artist profiles, and studio schedules.

## Features

- Workshop management and categorization
- Artist and studio profiles
- Cache system for optimized performance
- Admin panel for content management
- MongoDB integration for data storage

## Requirements

- Go 1.21 or higher
- MongoDB
- Internet connection for external dependencies

## Installation

1. Clone the repository:
```bash
git clone https://github.com/nikhilchatragadda/dance.git
cd dance
```

2. Run the setup script:
```bash
chmod +x setup.sh
./setup.sh
```

3. Start the server:
```bash
# Development mode
./dance_server --dev

# Production mode
./dance_server --prod
```

## API Endpoints

### Public API

- `GET /api/workshops` - Get all workshops
- `GET /api/studios` - Get all studios
- `GET /api/artists` - Get all artists
- `GET /api/workshops_by_artist/{artist_id}` - Get workshops by artist
- `GET /api/workshops_by_studio/{studio_id}` - Get workshops by studio
- `GET /proxy-image/?url={image_url}` - Image proxy service

### Admin API

- `GET /admin/api/studios` - List all studios
- `POST /admin/api/studios` - Create a new studio
- `PUT /admin/api/studios/{studio_id}` - Update a studio
- `DELETE /admin/api/studios/{studio_id}` - Delete a studio

- `GET /admin/api/artists` - List all artists
- `POST /admin/api/artists` - Create a new artist
- `PUT /admin/api/artists/{artist_id}` - Update an artist
- `DELETE /admin/api/artists/{artist_id}` - Delete an artist

- `GET /admin/api/workshops` - List all workshops
- `POST /admin/api/workshops` - Create a new workshop
- `PUT /admin/api/workshops/{uuid}` - Update a workshop
- `DELETE /admin/api/workshops/{uuid}` - Delete a workshop

## Structure

- `config/` - Configuration management
- `database/` - Database operations
- `models/` - Data structures and models
- `utils/` - Utility functions
- `templates/` - HTML templates
- `static/` - Static assets

## License

This project is licensed under the MIT License - see the LICENSE file for details.
