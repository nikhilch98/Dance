package utils

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/nikhilchatragadda/dance/config"
	"go.mongodb.org/mongo-driver/event"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

var (
	client            *mongo.Client
	clientOnce        sync.Once
	clientErr         error
	connectionMetrics ConnectionMetrics
	metricsLock       sync.Mutex
)

// ConnectionMetrics tracks MongoDB connection usage
type ConnectionMetrics struct {
	ConnectionsCreated      int
	ConnectionsReused       int
	LastConnectionCreatedAt time.Time
	ConnectTimeAvgMs        float64
	ConnectTimeDataPoints   int
	QueryTimeAvgMs          float64
	QueryTimeDataPoints     int
}

// Cache related variables
var (
	cache              = make(map[string]CacheItem)
	cacheMutex         = &sync.RWMutex{}
	hotReloadQueue     = make(chan bool, 100)
	hotReloadLock      = &sync.Mutex{}
	isHotReloadRunning = false
)

// CacheItem represents a cached response
type CacheItem struct {
	Data       interface{}
	Expiration time.Time
}

// GetMongoClient returns a MongoDB client instance with connection pooling
func GetMongoClient() (*mongo.Client, error) {
	// Record metrics for a connection request
	metricsLock.Lock()
	connectionMetrics.ConnectionsReused++
	metricsLock.Unlock()

	// Use sync.Once to ensure we only create one client
	clientOnce.Do(func() {
		startTime := time.Now()

		metricsLock.Lock()
		connectionMetrics.ConnectionsCreated++
		connectionMetrics.LastConnectionCreatedAt = time.Now()
		metricsLock.Unlock()

		cfg := config.NewConfig(config.DefaultEnv)

		// Use shorter connection timeout (2s instead of 10s)
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()

		// Configure connection options with optimal settings for performance
		clientOptions := options.Client().
			ApplyURI(cfg.MongoDBURI).
			SetConnectTimeout(2 * time.Second).
			SetServerSelectionTimeout(2 * time.Second).
			SetSocketTimeout(5 * time.Second).
			SetMaxConnIdleTime(60 * time.Second).
			SetMaxPoolSize(100).  // Increase pool size for better concurrency
			SetMinPoolSize(10).   // Ensure minimum available connections
			SetMaxConnecting(10). // Limit simultaneous connection creation
			SetRetryWrites(true).
			SetRetryReads(true)

		// Configure connection pool monitoring with string constants
		clientOptions.SetPoolMonitor(&event.PoolMonitor{
			Event: func(evt *event.PoolEvent) {
				log.Printf("[MongoDB] Pool event: %s for connection: %s", evt.Type, evt.ConnectionID)
				switch evt.Type {
				case "ConnectionPoolCreated":
				case event.ConnectionPoolCreated:
					log.Printf("[MongoDB] Pool created with %d max size", *clientOptions.MaxPoolSize)
				case event.ConnectionCreated:
					log.Printf("[MongoDB] New connection created: %s", evt.ConnectionID)
				case event.GetSucceeded:
					log.Printf("[MongoDB] Connection acquired from pool: %s", evt.ConnectionID)
				case event.ConnectionClosed:
					log.Printf("[MongoDB] Connection closed: %s", evt.ConnectionID)
				}
			},
		})

		// Connect to MongoDB with optimized settings
		var err error
		client, err = mongo.Connect(ctx, clientOptions)
		if err != nil {
			clientErr = fmt.Errorf("failed to connect to MongoDB: %v", err)
			log.Printf("Failed to connect to MongoDB: %v", err)
			return
		}

		// Ping with shorter timeout to verify connection
		pingCtx, pingCancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer pingCancel()

		if err = client.Ping(pingCtx, readpref.Primary()); err != nil {
			clientErr = fmt.Errorf("failed to ping MongoDB: %v", err)
			log.Printf("Failed to ping MongoDB: %v", err)
			return
		}

		connectTime := time.Since(startTime)
		log.Printf("Successfully connected to MongoDB with optimized connection pool in %v", connectTime)

		// Update connection metrics
		metricsLock.Lock()
		connectionMetrics.ConnectTimeDataPoints++
		totalTimeMs := connectionMetrics.ConnectTimeAvgMs * float64(connectionMetrics.ConnectTimeDataPoints-1)
		totalTimeMs += float64(connectTime.Milliseconds())
		connectionMetrics.ConnectTimeAvgMs = totalTimeMs / float64(connectionMetrics.ConnectTimeDataPoints)
		metricsLock.Unlock()
	})

	// Return existing client without reconnecting
	return client, clientErr
}

// GetConnectionMetrics returns the current MongoDB connection metrics
func GetConnectionMetrics() ConnectionMetrics {
	metricsLock.Lock()
	defer metricsLock.Unlock()
	return connectionMetrics
}

// TrackQueryTime records a query execution time for metrics
func TrackQueryTime(duration time.Duration) {
	metricsLock.Lock()
	defer metricsLock.Unlock()

	connectionMetrics.QueryTimeDataPoints++
	totalTimeMs := connectionMetrics.QueryTimeAvgMs * float64(connectionMetrics.QueryTimeDataPoints-1)
	totalTimeMs += float64(duration.Milliseconds())
	connectionMetrics.QueryTimeAvgMs = totalTimeMs / float64(connectionMetrics.QueryTimeDataPoints)
}

// ExecuteWithMetrics runs a MongoDB operation and tracks metrics
func ExecuteWithMetrics(operation string, fn func() error) error {
	startTime := time.Now()
	err := fn()
	duration := time.Since(startTime)

	log.Printf("[MongoDB] %s completed in %v", operation, duration)
	TrackQueryTime(duration)

	return err
}

// FormatDate formats the date using the specified time details
func FormatDate(timeDetails map[string]interface{}) string {
	// Extract date components with type safety
	var year, month, day int

	// Convert year value which can be int32 or float64
	switch v := timeDetails["year"].(type) {
	case float64:
		year = int(v)
	case int32:
		year = int(v)
	case int:
		year = v
	default:
		// Default to current year if conversion fails
		year = time.Now().Year()
	}

	// Convert month value which can be int32 or float64
	switch v := timeDetails["month"].(type) {
	case float64:
		month = int(v)
	case int32:
		month = int(v)
	case int:
		month = v
	default:
		// Default to current month if conversion fails
		month = int(time.Now().Month())
	}

	// Convert day value which can be int32 or float64
	switch v := timeDetails["day"].(type) {
	case float64:
		day = int(v)
	case int32:
		day = int(v)
	case int:
		day = v
	default:
		// Default to current day if conversion fails
		day = time.Now().Day()
	}

	date := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.Local)
	suffix := getDaySuffix(day)

	return fmt.Sprintf("%d%s %s", day, suffix, date.Format("Jan (Mon)"))
}

// FormatDateWithoutDay formats the date without day name
func FormatDateWithoutDay(timeDetails map[string]interface{}) string {
	// Extract date components with type safety
	var year, month, day int

	// Convert year value which can be int32 or float64
	switch v := timeDetails["year"].(type) {
	case float64:
		year = int(v)
	case int32:
		year = int(v)
	case int:
		year = v
	default:
		// Default to current year if conversion fails
		year = time.Now().Year()
	}

	// Convert month value which can be int32 or float64
	switch v := timeDetails["month"].(type) {
	case float64:
		month = int(v)
	case int32:
		month = int(v)
	case int:
		month = v
	default:
		// Default to current month if conversion fails
		month = int(time.Now().Month())
	}

	// Convert day value which can be int32 or float64
	switch v := timeDetails["day"].(type) {
	case float64:
		day = int(v)
	case int32:
		day = int(v)
	case int:
		day = v
	default:
		// Default to current day if conversion fails
		day = time.Now().Day()
	}

	date := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.Local)
	suffix := getDaySuffix(day)

	return fmt.Sprintf("%d%s %s", day, suffix, date.Format("Jan"))
}

// FormatDateWithDay formats the date and returns with weekday
func FormatDateWithDay(timeDetails map[string]interface{}) []string {
	// Extract date components with type safety
	var year, month, day int

	// Convert year value which can be int32 or float64
	switch v := timeDetails["year"].(type) {
	case float64:
		year = int(v)
	case int32:
		year = int(v)
	case int:
		year = v
	default:
		// Default to current year if conversion fails
		year = time.Now().Year()
	}

	// Convert month value which can be int32 or float64
	switch v := timeDetails["month"].(type) {
	case float64:
		month = int(v)
	case int32:
		month = int(v)
	case int:
		month = v
	default:
		// Default to current month if conversion fails
		month = int(time.Now().Month())
	}

	// Convert day value which can be int32 or float64
	switch v := timeDetails["day"].(type) {
	case float64:
		day = int(v)
	case int32:
		day = int(v)
	case int:
		day = v
	default:
		// Default to current day if conversion fails
		day = time.Now().Day()
	}

	date := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.Local)
	suffix := getDaySuffix(day)

	return []string{
		fmt.Sprintf("%d%s %s", day, suffix, date.Format("Jan (Mon)")),
		date.Format("Monday"),
	}
}

// FormatTime formats the time range from time details
func FormatTime(timeDetails map[string]interface{}) string {
	startTime, ok := timeDetails["start_time"].(string)
	if !ok || startTime == "" {
		return "TBA"
	}

	endTime, hasEndTime := timeDetails["end_time"].(string)

	// Parse and format start time
	startTimeParts := parseTimeString(startTime)
	if startTimeParts == nil {
		return startTime // Return original if parsing fails
	}

	// Format the output time string
	if !hasEndTime || endTime == "" {
		return fmt.Sprintf("%s %s", startTimeParts["time"], startTimeParts["format"])
	}

	// Parse and format end time
	endTimeParts := parseTimeString(endTime)
	if endTimeParts == nil {
		return fmt.Sprintf("%s %s", startTimeParts["time"], startTimeParts["format"])
	}

	// If formats are the same, combine them
	if startTimeParts["format"] == endTimeParts["format"] {
		return fmt.Sprintf("%s-%s %s", startTimeParts["time"], endTimeParts["time"], startTimeParts["format"])
	}

	// Different formats
	return fmt.Sprintf("%s %s - %s %s",
		startTimeParts["time"], startTimeParts["format"],
		endTimeParts["time"], endTimeParts["format"])
}

// GetTimestampEpoch calculates Unix timestamp from time details
func GetTimestampEpoch(timeDetails map[string]interface{}) int64 {
	// Extract date components and handle different types (int32 or float64)
	var year, month, day int

	// Convert year value which can be int32 or float64
	switch v := timeDetails["year"].(type) {
	case float64:
		year = int(v)
	case int32:
		year = int(v)
	case int:
		year = v
	default:
		// Default to current year if conversion fails
		year = time.Now().Year()
	}

	// Convert month value which can be int32 or float64
	switch v := timeDetails["month"].(type) {
	case float64:
		month = int(v)
	case int32:
		month = int(v)
	case int:
		month = v
	default:
		// Default to current month if conversion fails
		month = int(time.Now().Month())
	}

	// Convert day value which can be int32 or float64
	switch v := timeDetails["day"].(type) {
	case float64:
		day = int(v)
	case int32:
		day = int(v)
	case int:
		day = v
	default:
		// Default to current day if conversion fails
		day = time.Now().Day()
	}

	// Parse start_time or default to midnight
	var hour, minute int
	startTime, ok := timeDetails["start_time"].(string)
	if !ok || startTime == "" {
		hour, minute = 0, 0 // 12:00 AM as default
	} else {
		timeParts := parseTimeString(startTime)
		if timeParts != nil {
			if timeParts["hour"] != "" {
				if h, err := fmt.Sscanf(timeParts["hour"], "%d", &hour); err != nil || h == 0 {
					hour = 0
				}
			}
			if timeParts["minute"] != "" {
				if m, err := fmt.Sscanf(timeParts["minute"], "%d", &minute); err != nil || m == 0 {
					minute = 0
				}
			}
			// Convert 12-hour format to 24-hour
			if timeParts["format"] == "PM" && hour < 12 {
				hour += 12
			} else if timeParts["format"] == "AM" && hour == 12 {
				hour = 0
			}
		}
	}

	// Create time object and convert to timestamp
	dt := time.Date(year, time.Month(month), day, hour, minute, 0, 0, time.Local)
	return dt.Unix()
}

// GetCurrentTimestamp returns the current Unix timestamp
func GetCurrentTimestamp() int64 {
	return time.Now().Unix()
}

// Helper functions

// getDaySuffix returns the appropriate suffix for a day number
func getDaySuffix(day int) string {
	if day >= 11 && day <= 13 {
		return "th"
	}

	switch day % 10 {
	case 1:
		return "st"
	case 2:
		return "nd"
	case 3:
		return "rd"
	default:
		return "th"
	}
}

// parseTimeString parses a time string and returns components
func parseTimeString(timeStr string) map[string]string {
	var timeFormat, hourStr, minuteStr string
	var hour, minute int

	// Try to handle various time formats
	// Format: "HH:MM AM/PM"
	n, err := fmt.Sscanf(timeStr, "%d:%d %s", &hour, &minute, &timeFormat)
	if err == nil && n == 3 {
		hourStr = fmt.Sprintf("%d", hour)
		minuteStr = fmt.Sprintf("%d", minute)

		var timeStr string
		if minute > 0 {
			timeStr = fmt.Sprintf("%s:%s", hourStr, minuteStr)
		} else {
			timeStr = hourStr
		}

		return map[string]string{
			"time":   timeStr,
			"format": timeFormat,
			"hour":   hourStr,
			"minute": minuteStr,
		}
	}

	// Format: "HH AM/PM" (no minutes)
	n, err = fmt.Sscanf(timeStr, "%d %s", &hour, &timeFormat)
	if err == nil && n == 2 {
		hourStr = fmt.Sprintf("%d", hour)
		return map[string]string{
			"time":   hourStr,
			"format": timeFormat,
			"hour":   hourStr,
			"minute": "0",
		}
	}

	// Format: "HH:MM" (24-hour format)
	n, err = fmt.Sscanf(timeStr, "%d:%d", &hour, &minute)
	if err == nil && n == 2 {
		hourStr = fmt.Sprintf("%d", hour)
		minuteStr = fmt.Sprintf("%d", minute)

		if hour < 12 {
			timeFormat = "AM"
		} else {
			timeFormat = "PM"
		}

		if hour > 12 {
			hour -= 12
			hourStr = fmt.Sprintf("%d", hour)
		} else if hour == 0 {
			hour = 12
			hourStr = fmt.Sprintf("%d", hour)
		}

		var timeStr string
		if minute > 0 {
			timeStr = fmt.Sprintf("%s:%s", hourStr, minuteStr)
		} else {
			timeStr = hourStr
		}

		return map[string]string{
			"time":   timeStr,
			"format": timeFormat,
			"hour":   hourStr,
			"minute": minuteStr,
		}
	}

	return nil
}

// CacheResponseMiddleware is a helper function to cache API responses
func CacheResponseMiddleware(key string, data interface{}, expireSeconds int) interface{} {
	cacheMutex.Lock()
	defer cacheMutex.Unlock()

	expiration := time.Now().Add(time.Duration(expireSeconds) * time.Second)
	cache[key] = CacheItem{
		Data:       data,
		Expiration: expiration,
	}

	return data
}

// GetCachedResponse tries to get a cached response
func GetCachedResponse(key string) (interface{}, bool) {
	cacheMutex.RLock()
	defer cacheMutex.RUnlock()

	item, found := cache[key]
	if !found {
		return nil, false
	}

	// Check if the item is expired
	if time.Now().After(item.Expiration) {
		return nil, false
	}

	return item.Data, true
}

// GetAllCacheKeys returns a list of all cache keys with metadata
func GetAllCacheKeys() []map[string]interface{} {
	cacheMutex.RLock()
	defer cacheMutex.RUnlock()

	result := make([]map[string]interface{}, 0, len(cache))
	now := time.Now()

	for key, item := range cache {
		// Skip expired items
		if now.After(item.Expiration) {
			continue
		}

		var size int
		if data, ok := item.Data.([]byte); ok {
			size = len(data)
		} else {
			size = -1 // unknown size for non-byte slice data
		}

		result = append(result, map[string]interface{}{
			"key":                key,
			"expires_at":         item.Expiration.Format(time.RFC3339),
			"expires_in_seconds": int64(item.Expiration.Sub(now).Seconds()),
			"size":               size,
		})
	}

	return result
}

// ClearCache clears the entire cache
func ClearCache() {
	cacheMutex.Lock()
	defer cacheMutex.Unlock()
	cache = make(map[string]CacheItem)
}

// StartCacheInvalidationWatcher starts background goroutines to monitor for DB changes
func StartCacheInvalidationWatcher() {
	go processHotReloadQueue()
	go watchChanges()

	// Initial cache warmup
	hotReloadQueue <- true
}

// processHotReloadQueue processes the hot reload queue
func processHotReloadQueue() {
	for range hotReloadQueue {
		// Clear the queue of any pending items
		for len(hotReloadQueue) > 0 {
			<-hotReloadQueue
		}

		hotReloadLock.Lock()
		isHotReloadRunning = true

		// Clear the cache
		ClearCache()

		// This will be expanded to call API endpoints to repopulate cache
		// The Go HTTP client would be used here to call internal endpoints

		isHotReloadRunning = false
		hotReloadLock.Unlock()
	}
}

// watchChanges watches MongoDB collections for changes
func watchChanges() {
	// This will be implemented using MongoDB change streams
	// For now, we'll just log that it started
	log.Println("Started watching MongoDB collections for changes")
}
