# Dance API

A Go-based API for managing dance workshops, studios, and artists.

## Setup

1. Install Go (version 1.21 or higher)
2. Clone the repository
3. Install dependencies:
   ```bash
   go mod tidy
   ```
4. Set up environment variables:
   - Copy `.env.example` to `.env`
   - Update the values as needed

### Environment Variables

The following environment variables are required:

- `PORT`: Server port (default: 8002)
- `MONGODB_URI`: MongoDB connection string (default: mongodb://localhost:27017)
- `DB_NAME`: MongoDB database name (default: discovery)
- `STATIC_DIR`: Directory for static files (default: static)
- `ENV`: Environment (development/production)

## Running the Server

```bash
go run main.go
```

The server will start on the configured port (default: 8002).

## API Endpoints

### Public Endpoints

- `GET /api/workshops` - List all workshops
- `GET /api/workshops_by_artist/{artistId}` - List workshops by artist
- `GET /api/workshops_by_studio/{studioId}` - List workshops by studio
- `GET /api/studios` - List all studios
- `GET /api/artists` - List all artists

### Admin Endpoints

- `GET /admin/api/studios` - List all studios (admin view)
- `POST /admin/api/studios` - Create a new studio
- `PUT /admin/api/studios/{studioId}` - Update a studio
- `DELETE /admin/api/studios/{studioId}` - Delete a studio

- `GET /admin/api/artists` - List all artists (admin view)
- `POST /admin/api/artists` - Create a new artist
- `PUT /admin/api/artists/{artistId}` - Update an artist
- `DELETE /admin/api/artists/{artistId}` - Delete an artist

- `GET /admin/api/workshops` - List all workshops (admin view)
- `POST /admin/api/workshops` - Create a new workshop
- `PUT /admin/api/workshops/{uuid}` - Update a workshop
- `DELETE /admin/api/workshops/{uuid}` - Delete a workshop 