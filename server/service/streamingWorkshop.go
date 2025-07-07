package service

import (
	"context"
	"fmt"
	"nachna/models/request"
	"nachna/models/response"
	"nachna/service/admin"
	"nachna/service/admin/studio"
	"time"
)

// StreamingWorkshopService handles streaming workshop operations
type StreamingWorkshopService struct {
	adminService admin.AdminService
}

// NewStreamingWorkshopService creates a new streaming workshop service
func NewStreamingWorkshopService() *StreamingWorkshopService {
	danceInnStudio := studio.DanceInnStudioImpl{}.GetInstance("", "", "", 0, 0)
	adminStudioService := studio.AdminStudioServiceImpl{}.GetInstance(danceInnStudio)
	adminService := admin.AdminServiceImpl{}.GetInstance(adminStudioService)

	return &StreamingWorkshopService{
		adminService: adminService,
	}
}

// GetStreamingWorkshopService returns the singleton instance
func GetStreamingWorkshopService() *StreamingWorkshopService {
	danceInnStudio := studio.DanceInnStudioImpl{}.GetInstance("", "", "", 0, 0)
	adminStudioService := studio.AdminStudioServiceImpl{}.GetInstance(danceInnStudio)
	adminService := admin.AdminServiceImpl{}.GetInstance(adminStudioService)

	return &StreamingWorkshopService{
		adminService: adminService,
	}
}

// RefreshWorkshopsStreaming processes workshops and sends real-time updates
func (s *StreamingWorkshopService) RefreshWorkshopsStreaming(ctx context.Context, req *request.AdminWorkshopRequest, updateChan chan<- *response.StreamingResponse) error {
	defer close(updateChan)

	// Send initial log
	updateChan <- response.NewLogResponse("Starting workshop refresh process...", "info")

	// Simulate processing multiple links (replace with actual logic)
	totalLinks := 10
	for i := 0; i < totalLinks; i++ {
		select {
		case <-ctx.Done():
			updateChan <- response.NewLogResponse("Process cancelled by user", "warning")
			return ctx.Err()
		default:
			// Simulate processing time
			time.Sleep(500 * time.Millisecond)

			// Calculate progress
			current := i + 1
			percentage := float64(current) / float64(totalLinks) * 100

			// Send progress update
			updateChan <- response.NewProgressResponse(percentage, current, totalLinks, fmt.Sprintf("Processing link %d of %d", current, totalLinks))

			// Send log update for each processed link
			updateChan <- response.NewLogResponse(fmt.Sprintf("Processed link %d successfully", current), "info")

			// Simulate occasional warnings or errors
			if i == 3 {
				updateChan <- response.NewLogResponse("Warning: Link 4 had some issues but was processed", "warning")
			}
			if i == 7 {
				updateChan <- response.NewLogResponse("Error: Link 8 failed to process, skipping", "error")
			}
		}
	}

	// Send completion message
	updateChan <- response.NewLogResponse("Workshop refresh completed successfully!", "success")
	updateChan <- response.NewProgressResponse(100.0, totalLinks, totalLinks, "All links processed")

	return nil
}

// ProcessStudioWithStreaming processes a specific studio with streaming updates
func (s *StreamingWorkshopService) ProcessStudioWithStreaming(ctx context.Context, studioID string, updateChan chan<- *response.StreamingResponse) error {
	defer close(updateChan)

	updateChan <- response.NewLogResponse(fmt.Sprintf("Starting processing for studio: %s", studioID), "info")

	// Get studio configuration (you'll need to implement this based on your existing logic)
	// studio := getStudioConfig(studioID)

	// Simulate studio processing
	updateChan <- response.NewLogResponse("Fetching studio configuration...", "info")
	time.Sleep(1 * time.Second)

	updateChan <- response.NewLogResponse("Connecting to studio website...", "info")
	time.Sleep(2 * time.Second)

	// Simulate link discovery
	totalLinks := 15
	updateChan <- response.NewLogResponse(fmt.Sprintf("Found %d links to process", totalLinks), "info")

	for i := 0; i < totalLinks; i++ {
		select {
		case <-ctx.Done():
			updateChan <- response.NewLogResponse("Studio processing cancelled", "warning")
			return ctx.Err()
		default:
			current := i + 1
			percentage := float64(current) / float64(totalLinks) * 100

			// Simulate link processing
			time.Sleep(300 * time.Millisecond)

			updateChan <- response.NewProgressResponse(percentage, current, totalLinks, fmt.Sprintf("Processing link %d/%d", current, totalLinks))
			updateChan <- response.NewLogResponse(fmt.Sprintf("Analyzed link %d with AI", current), "info")

			// Simulate database operations
			if i%3 == 0 {
				updateChan <- response.NewLogResponse(fmt.Sprintf("Saving workshop data for link %d", current), "info")
				time.Sleep(200 * time.Millisecond)
			}
		}
	}

	updateChan <- response.NewLogResponse(fmt.Sprintf("Studio %s processing completed", studioID), "success")
	updateChan <- response.NewProgressResponse(100.0, totalLinks, totalLinks, "Studio processing complete")

	return nil
}
